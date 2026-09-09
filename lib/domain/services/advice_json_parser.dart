/// Defensive parser for Gemini's advice JSON. Pure — no I/O, no SDK. Mirrors
/// `receipt_json_parser.dart`: assume the response is hostile (```json fences,
/// prose, wrong types, a truncated tail), extract what we can, accept a partial
/// list. The ONLY failure that throws is "nothing usable at all".
///
/// Expected shape: `{ "advice": [ { "title": string, "body": string } ] }`.
library;

import 'dart:convert';

import '../entities/advice_item.dart';
import 'json_extraction.dart';

/// Thrown when [raw] yields no usable advice item.
class AdviceUnparseableException implements Exception {
  const AdviceUnparseableException(this.rawSnippet);
  final String rawSnippet;
  @override
  String toString() => 'AdviceUnparseableException($rawSnippet)';
}

/// At most this many items are kept (the prompt asks for 2–4).
const int kMaxAdviceItems = 4;

List<AdviceItem> parseAdviceJson(String raw) {
  final list = _extractList(raw);
  final items = <AdviceItem>[];
  for (final entry in list) {
    final item = _coerceItem(entry);
    if (item != null) items.add(item);
    if (items.length == kMaxAdviceItems) break;
  }
  if (items.isEmpty) {
    throw AdviceUnparseableException(
      raw.length > 200 ? '${raw.substring(0, 200)}…' : raw,
    );
  }
  return List<AdviceItem>.unmodifiable(items);
}

/// Pulls the advice array out of the response, trying progressively looser
/// interpretations.
List<Object?> _extractList(String raw) {
  for (final decoded in _decodeCandidates(raw)) {
    if (decoded is List) return decoded;
    if (decoded is Map) {
      final advice = decoded['advice'] ?? decoded['items'] ?? decoded['tips'];
      if (advice is List) return advice;
      // A single {title,body} object with no wrapper.
      if (decoded['title'] != null || decoded['body'] != null) {
        return <Object?>[decoded];
      }
    }
  }
  // Last resort: a truncated array — recover whichever `{ … }` objects are
  // complete (the prompt asks us to "accept partial results").
  return _salvageObjects(raw);
}

/// Every complete brace-balanced object after the first `[`, decoded
/// individually. Handles a response that was cut off mid-item.
List<Object?> _salvageObjects(String raw) {
  final arrayStart = raw.indexOf('[');
  if (arrayStart < 0) return const <Object?>[];
  final out = <Object?>[];
  var cursor = raw.indexOf('{', arrayStart);
  while (cursor >= 0) {
    final obj = firstBalanced(raw.substring(cursor));
    if (obj == null) break; // the rest is truncated
    try {
      out.add(jsonDecode(obj));
    } catch (_) {
      // skip an unparseable fragment
    }
    cursor = raw.indexOf('{', cursor + obj.length);
  }
  return out;
}

Iterable<Object?> _decodeCandidates(String raw) sync* {
  final tries = <String>[
    raw.trim(),
    stripCodeFences(raw),
    firstBalanced(raw) ?? '', // first { … }
    firstBalanced(raw, open: '[') ?? '', // first [ … ]
  ];
  for (final t in tries) {
    if (t.isEmpty) continue;
    try {
      yield jsonDecode(t);
    } catch (_) {
      // next
    }
  }
}

AdviceItem? _coerceItem(Object? entry) {
  if (entry is String) {
    final body = entry.trim();
    return body.isEmpty ? null : AdviceItem(title: '', body: body);
  }
  if (entry is! Map) return null;

  final title = _cleanString(entry['title'] ?? entry['heading']);
  final body = _cleanString(
    entry['body'] ?? entry['text'] ?? entry['detail'] ?? entry['description'],
  );

  if (body == null && title == null) return null;
  if (body == null) return AdviceItem(title: '', body: title!);
  return AdviceItem(title: title ?? '', body: body);
}

String? _cleanString(Object? v) {
  if (v is! String) return null;
  final t = v.trim();
  if (t.isEmpty || t.toLowerCase() == 'null') return null;
  return t;
}
