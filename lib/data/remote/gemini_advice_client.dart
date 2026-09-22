import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../domain/entities/advice_item.dart';
import '../../domain/repositories/advice_generator_repository.dart';
import '../../domain/services/advice_json_parser.dart';
import '../../domain/services/advice_summary_builder.dart';

/// Talks to the Gemini API for text advice (Phase 9). Sibling of
/// `GeminiReceiptClient` — it shares the **single** key path (same
/// `geminiApiKeyProvider`, same `kGeminiModel`, same endpoint shape; CLAUDE.md
/// §9), not the class. The request/response envelope handling is duplicated
/// rather than refactoring the tested Phase 7 client.
///
/// Ethics (CLAUDE.md §7): the request body carries **only** the aggregated
/// [AdviceSummary] JSON and a fixed prompt — no transactions, no merchants, no
/// notes, no user id.
class GeminiAdviceClient implements AdviceGeneratorRepository {
  GeminiAdviceClient({
    required String apiKey,
    http.Client? httpClient,
    String model = 'gemini-3.6-flash',
    Duration timeout = const Duration(seconds: 30),
    Uri Function(String model)? endpoint,
  }) : _key = apiKey,
       _http = httpClient ?? http.Client(),
       _modelId = model,
       _requestTimeout = timeout,
       _endpoint = endpoint ?? _defaultEndpoint;

  final String _key;
  final http.Client _http;
  final String _modelId;
  final Duration _requestTimeout;
  final Uri Function(String model) _endpoint;

  // Security review (Phase 12): the key travels in the `x-goog-api-key`
  // header (below), never in the URL — see the matching note in
  // `gemini_client.dart`, this client's sibling.
  static Uri _defaultEndpoint(String model) => Uri.parse(
    'https://generativelanguage.googleapis.com/v1beta/models/'
    '$model:generateContent',
  );

  static const String _prompt = '''
You are a friendly, non-judgemental budgeting assistant for a student or young
adult in Malaysia. All amounts are in Malaysian Ringgit (RM). Below is an
AGGREGATED summary of the user's spending for one period — category totals,
trends and budget adherence only, no individual purchases.

Give 2 to 4 specific, actionable suggestions grounded in these exact numbers.

Rules:
- Refer to the user's real category names and real amounts from the summary
  (e.g. "your RM 240 on Food").
- Be specific and practical. Do NOT give generic advice like "make a budget" or
  "spend less" — say what to change and roughly by how much.
- Do NOT recommend any financial product, investment, loan, credit card, bank,
  insurance or provider.
- Never use shaming or judgemental language about how they spend. Be
  encouraging and matter-of-fact. If they are doing well, say so and suggest how
  to keep it up.
- Keep each suggestion short.
- Classify each suggestion's "type" as exactly one of "spending" (a pattern in
  what they spend on), "saving" (an opportunity or a win worth banking), or
  "budgeting" (tied to a limit in the summary). If truly none fits, omit "type".

Return ONLY a strict JSON object, no markdown, no code fences, no commentary:
{ "advice": [ { "title": string, "body": string, "type": string } ] }
"title": a short phrase, at most 6 words.
"body": 1 to 3 sentences.
"type": one of "spending" | "saving" | "budgeting".

SUMMARY:
''';

  static const String _chatPrompt = '''
You are Spendify AI, a friendly, non-judgemental budgeting assistant for a
student or young adult in Malaysia, speaking inside a chat window in the
Spendify app. All amounts are in Malaysian Ringgit (RM).

Below is an AGGREGATED summary of the user's spending for the current
period — category totals, trends and budget adherence only, never individual
purchases — followed by the recent conversation and the user's new question.

Rules:
- Ground every specific figure you mention in the summary below. Do not invent
  numbers that are not in it.
- Do NOT recommend any financial product, investment, loan, credit card, bank,
  insurance or provider.
- Never use shaming or judgemental language about how they spend.
- You cannot see individual transactions, and you cannot create, edit or
  delete anything in their account — you can only talk. If asked to do
  something the app would need to act on (like creating a budget), describe
  what to do in the app rather than claiming you did it.
- Keep your reply conversational and short — a few sentences, plus a short
  list only if it genuinely helps.
- Reply in plain text. No markdown headers, no code fences.

SUMMARY:
''';

  @override
  Future<List<AdviceItem>> generate(AdviceSummary summary) async {
    final promptText =
        '$_prompt${const JsonEncoder.withIndent('  ').convert(summary.toJson())}';
    final text = await _generateText(promptText, asJson: true);

    try {
      return parseAdviceJson(text);
    } on AdviceUnparseableException catch (e) {
      throw AdviceApiException('Could not read the advice response.', cause: e);
    }
  }

  @override
  Future<String> ask({
    required AdviceSummary summary,
    required String question,
    List<AdviceChatTurn> history = const <AdviceChatTurn>[],
  }) async {
    final buffer = StringBuffer(_chatPrompt)
      ..write(const JsonEncoder.withIndent('  ').convert(summary.toJson()));

    // Only the last few turns — enough for context, small enough to bound
    // the prompt (this is a chat, not a transcript archive).
    final recent = history.length > 6
        ? history.sublist(history.length - 6)
        : history;
    if (recent.isNotEmpty) {
      buffer.write('\n\nCONVERSATION SO FAR:\n');
      for (final turn in recent) {
        buffer.write('${turn.isUser ? 'User' : 'Spendify AI'}: ${turn.text}\n');
      }
    }
    buffer.write('\nUser: $question\nSpendify AI:');

    final text = await _generateText(buffer.toString(), asJson: false);
    return text.trim();
  }

  /// The POST + status/safety checks + candidate-text extraction shared by
  /// [generate] and [ask]. [asJson] only changes the response format Gemini
  /// is asked for — the transport and error handling are identical.
  Future<String> _generateText(
    String promptText, {
    required bool asJson,
  }) async {
    if (_key.isEmpty) {
      throw const AdviceUnavailableException();
    }

    final requestBody = jsonEncode(<String, Object?>{
      'contents': <Object?>[
        <String, Object?>{
          'parts': <Object?>[
            <String, Object?>{'text': promptText},
          ],
        },
      ],
      'generationConfig': <String, Object?>{
        'temperature': 0.4,
        if (asJson) 'responseMimeType': 'application/json',
      },
    });

    late http.Response response;
    try {
      response = await _http
          .post(
            _endpoint(_modelId),
            headers: <String, String>{
              'Content-Type': 'application/json',
              'x-goog-api-key': _key,
            },
            body: requestBody,
          )
          .timeout(_requestTimeout);
    } on TimeoutException catch (e) {
      throw AdviceTimeoutException(cause: e);
    } catch (e) {
      throw AdviceNetworkException(cause: e);
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
      throw AdviceApiException(
        'The advice service returned something unexpected.',
        cause: e,
      );
    }

    _checkBlocked(decoded);

    final text = _candidateText(decoded);
    if (text == null || text.trim().isEmpty) {
      throw const AdviceBlockedException();
    }
    return text;
  }

  void _checkStatus(http.Response r) {
    if (r.statusCode == 200) return;
    if (r.statusCode == 429) throw const AdviceRateLimitedException();
    if (r.statusCode == 401 || r.statusCode == 403) {
      throw AdviceApiException(
        'The advice service rejected the request (auth). Check the API key.',
        cause: 'HTTP ${r.statusCode}',
      );
    }
    if (r.statusCode >= 500) {
      throw AdviceApiException(
        'The advice service had a problem (HTTP ${r.statusCode}). Try again.',
        cause: r.body,
      );
    }
    throw AdviceApiException(
      'The advice service rejected the request (HTTP ${r.statusCode}).',
      cause: r.body,
    );
  }

  void _checkBlocked(Map<String, dynamic> decoded) {
    final feedback = decoded['promptFeedback'];
    if (feedback is Map && feedback['blockReason'] != null) {
      throw const AdviceBlockedException();
    }
    final candidates = decoded['candidates'];
    if (candidates is! List || candidates.isEmpty) {
      throw const AdviceBlockedException();
    }
    final first = candidates.first;
    if (first is Map) {
      final reason = first['finishReason'];
      if (reason == 'SAFETY' ||
          reason == 'RECITATION' ||
          reason == 'BLOCKLIST') {
        throw const AdviceBlockedException();
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
