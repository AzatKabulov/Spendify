import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../domain/entities/receipt_extraction.dart';
import '../../domain/repositories/receipt_scanner_repository.dart';
import '../../domain/services/receipt_json_parser.dart';

/// The **only** file that talks to the Gemini API (CLAUDE.md §6). Implements
/// [ReceiptScannerRepository] over `generativelanguage.googleapis.com`.
///
/// Ethics (CLAUDE.md §7): the request body carries **only the image** and a
/// fixed prompt — no transactions, no category list, no user data.
///
/// Key placement (CLAUDE.md §9) is still an open A/B decision. This client
/// takes the key as a constructor arg; the provider wires it from a
/// `--dart-define` / gitignored file. Switching to a Cloud Function proxy
/// (option A) means swapping [_endpoint] and dropping the key — nothing else
/// above this file changes.
class GeminiReceiptClient implements ReceiptScannerRepository {
  GeminiReceiptClient({
    required String apiKey,
    http.Client? httpClient,
    String model = 'gemini-2.0-flash',
    Duration timeout = const Duration(seconds: 30),
    Uri Function(String model, String apiKey)? endpoint,
  }) : _key = apiKey,
       _http = httpClient ?? http.Client(),
       _modelId = model,
       _requestTimeout = timeout,
       _endpoint = endpoint ?? _defaultEndpoint;

  final String _key;
  final http.Client _http;
  final String _modelId;
  final Duration _requestTimeout;
  final Uri Function(String model, String apiKey) _endpoint;

  static Uri _defaultEndpoint(String model, String apiKey) => Uri.parse(
    'https://generativelanguage.googleapis.com/v1beta/models/'
    '$model:generateContent?key=$apiKey',
  );

  static const String _prompt = '''
You are extracting fields from a photo of a shopping receipt.
Return ONLY a JSON object — no markdown, no code fences, no commentary — with
exactly this shape:
{
  "merchant": string|null,
  "totalAmountMinor": integer|null,
  "currency": string|null,
  "date": string|null,
  "suggestedCategory": string|null,
  "confidence": number
}
Rules:
- "totalAmountMinor": the FINAL total the customer paid, as an integer in the
  smallest currency unit (sen for MYR). RM 12.50 becomes 1250.
- "currency": the ISO 4217 code, e.g. "MYR".
- "date": the purchase date formatted "YYYY-MM-DD".
- "suggestedCategory": one short spending-category label such as "Groceries",
  "Food", "Transport", "Bills", "Health", "Shopping".
- "confidence": your overall confidence in the extraction, 0.0 to 1.0.
- If you cannot read a field with reasonable confidence, use null. Do NOT guess.
Output the JSON object and nothing else.''';

  @override
  Future<ReceiptExtraction> extract(Uint8List jpegBytes) async {
    if (_key.isEmpty) {
      throw const ReceiptScannerUnavailableException();
    }

    final requestBody = jsonEncode(<String, Object?>{
      'contents': <Object?>[
        <String, Object?>{
          'parts': <Object?>[
            <String, Object?>{'text': _prompt},
            <String, Object?>{
              'inline_data': <String, Object?>{
                'mime_type': 'image/jpeg',
                'data': base64Encode(jpegBytes),
              },
            },
          ],
        },
      ],
      'generationConfig': <String, Object?>{
        'temperature': 0,
        'responseMimeType': 'application/json',
      },
    });

    late http.Response response;
    try {
      response = await _http
          .post(
            _endpoint(_modelId, _key),
            headers: const <String, String>{'Content-Type': 'application/json'},
            body: requestBody,
          )
          .timeout(_requestTimeout);
    } on TimeoutException catch (e) {
      throw ReceiptTimeoutException(cause: e);
    } catch (e) {
      throw ReceiptNetworkException(cause: e);
    }

    _checkStatus(response);

    final Map<String, dynamic> decoded;
    try {
      final body = jsonDecode(response.body);
      if (body is! Map<String, dynamic>) {
        throw const FormatException('response is not a JSON object');
      }
      decoded = body;
    } catch (e) {
      throw ReceiptApiException(
        'The scanner returned something unexpected.',
        cause: e,
      );
    }

    _checkBlocked(decoded);

    final text = _candidateText(decoded);
    if (text == null || text.trim().isEmpty) {
      throw const ReceiptBlockedException();
    }

    try {
      return parseReceiptJson(text);
    } on ReceiptUnparseableException catch (e) {
      throw ReceiptApiException(
        'Could not read the scanner response.',
        cause: e,
      );
    }
  }

  void _checkStatus(http.Response r) {
    if (r.statusCode == 200) return;
    if (r.statusCode == 429) throw const ReceiptRateLimitedException();
    if (r.statusCode == 401 || r.statusCode == 403) {
      throw ReceiptApiException(
        'The scanner rejected the request (auth). Check the API key.',
        cause: 'HTTP ${r.statusCode}',
      );
    }
    if (r.statusCode >= 500) {
      throw ReceiptApiException(
        'The scanner had a problem (HTTP ${r.statusCode}). Try again.',
        cause: r.body,
      );
    }
    throw ReceiptApiException(
      'The scanner rejected the request (HTTP ${r.statusCode}).',
      cause: r.body,
    );
  }

  void _checkBlocked(Map<String, dynamic> decoded) {
    final feedback = decoded['promptFeedback'];
    if (feedback is Map && feedback['blockReason'] != null) {
      throw const ReceiptBlockedException();
    }
    final candidates = decoded['candidates'];
    if (candidates is! List || candidates.isEmpty) {
      throw const ReceiptBlockedException();
    }
    final first = candidates.first;
    if (first is Map) {
      final reason = first['finishReason'];
      if (reason == 'SAFETY' ||
          reason == 'RECITATION' ||
          reason == 'BLOCKLIST') {
        throw const ReceiptBlockedException();
      }
    }
  }

  String? _candidateText(Map<String, dynamic> decoded) {
    try {
      final candidates = decoded['candidates'] as List;
      final content = (candidates.first as Map)['content'] as Map;
      final parts = content['parts'] as List;
      final buffer = StringBuffer();
      for (final p in parts) {
        if (p is Map && p['text'] is String) buffer.write(p['text'] as String);
      }
      return buffer.toString();
    } catch (_) {
      return null;
    }
  }
}
