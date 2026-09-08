/// Defensive parser for Gemini's receipt-extraction JSON. Pure — no I/O, no
/// SDK. Heavily unit-tested (CLAUDE.md §8 calls out "Gemini response parsing").
///
/// **Assume the response is hostile:** markdown ```json fences, leading /
/// trailing prose, wrong types, missing keys, a truncated object. Strip what
/// we can, parse leniently, validate each field independently, accept a
/// partial result. The ONLY failure that throws is "there is no JSON object at
/// all" — everything else degrades to `null` fields.
library;

import 'dart:convert';

import '../entities/receipt_extraction.dart';

/// Thrown only when [raw] contains no `{ … }` object we can even attempt to
/// decode. The caller falls back to the blank manual form.
class ReceiptUnparseableException implements Exception {
  const ReceiptUnparseableException(this.rawSnippet);
  final String rawSnippet;
  @override
  String toString() => 'ReceiptUnparseableException($rawSnippet)';
}

ReceiptExtraction parseReceiptJson(String raw) {
  final json = _decodeLenient(raw);
  return ReceiptExtraction(
    merchant: _string(json['merchant']),
    totalAmountMinor: _amountMinor(json['totalAmountMinor']),
    currency: _string(json['currency'])?.toUpperCase(),
    date: _date(json['date']),
    suggestedCategory: _string(json['suggestedCategory']),
    confidence: _confidence(json['confidence']),
  );
}

// --- decode ---------------------------------------------------------

Map<String, dynamic> _decodeLenient(String raw) {
  final candidates = <String>[
    raw.trim(),
    _stripFences(raw),
    _firstBraceObject(raw) ?? '',
  ];
  for (final c in candidates) {
    if (c.isEmpty) continue;
    try {
      final decoded = jsonDecode(c);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return decoded.cast<String, dynamic>();
    } catch (_) {
      // try the next candidate
    }
  }
  throw ReceiptUnparseableException(
    raw.length > 200 ? '${raw.substring(0, 200)}…' : raw,
  );
}

String _stripFences(String raw) {
  var s = raw.trim();
  // ```json … ```  or  ``` … ```
  final fence = RegExp(r'^```(?:json)?\s*|\s*```$', multiLine: true);
  s = s.replaceAll(fence, '').trim();
  return s;
}

/// The substring from the first `{` to its matching `}` (brace-balanced, aware
/// of strings so a `}` inside a value doesn't end it early).
String? _firstBraceObject(String raw) {
  final start = raw.indexOf('{');
  if (start < 0) return null;
  var depth = 0;
  var inString = false;
  var escaped = false;
  for (var i = start; i < raw.length; i++) {
    final ch = raw[i];
    if (inString) {
      if (escaped) {
        escaped = false;
      } else if (ch == r'\') {
        escaped = true;
      } else if (ch == '"') {
        inString = false;
      }
      continue;
    }
    if (ch == '"') {
      inString = true;
    } else if (ch == '{') {
      depth++;
    } else if (ch == '}') {
      depth--;
      if (depth == 0) return raw.substring(start, i + 1);
    }
  }
  return null; // unbalanced / truncated
}

// --- per-field coercion (each independent) --------------------------

String? _string(Object? v) {
  if (v is! String) return null;
  final t = v.trim();
  if (t.isEmpty) return null;
  // Gemini sometimes literally writes the word "null" as a string.
  if (t.toLowerCase() == 'null' || t.toLowerCase() == 'n/a') return null;
  return t;
}

/// Accepts an int, a num, or a numeric string. Rejects <= 0 and non-finite.
/// A float like `1250.0` -> 1250; `12.5` (looks like RM, not sen) is still
/// taken at face value as sen per the prompt contract, rounded.
int? _amountMinor(Object? v) {
  num? n;
  if (v is int) {
    n = v;
  } else if (v is num) {
    n = v;
  } else if (v is String) {
    n = num.tryParse(v.replaceAll(RegExp(r'[^0-9.\-]'), ''));
  }
  if (n == null || !n.isFinite) return null;
  final rounded = n.round();
  return rounded > 0 ? rounded : null;
}

DateTime? _date(Object? v) {
  final s = _string(v);
  if (s == null) return null;
  // ISO first (what we ask for).
  final iso = DateTime.tryParse(s);
  if (iso != null) return DateTime(iso.year, iso.month, iso.day);
  // A few common receipt formats as a fallback.
  for (final re in <RegExp>[
    RegExp(r'^(\d{1,2})[/\-.](\d{1,2})[/\-.](\d{4})$'), // dd/MM/yyyy
    RegExp(r'^(\d{4})[/\-.](\d{1,2})[/\-.](\d{1,2})$'), // yyyy/MM/dd
  ]) {
    final m = re.firstMatch(s);
    if (m == null) continue;
    final a = int.parse(m.group(1)!);
    final b = int.parse(m.group(2)!);
    final c = int.parse(m.group(3)!);
    final (y, mo, d) = a > 31 ? (a, b, c) : (c, b, a);
    if (mo >= 1 && mo <= 12 && d >= 1 && d <= 31) {
      return DateTime(y, mo, d);
    }
  }
  return null;
}

double _confidence(Object? v) {
  num? n;
  if (v is num) {
    n = v;
  } else if (v is String) {
    n = num.tryParse(v);
  }
  if (n == null || !n.isFinite) return 0.0;
  return n.clamp(0.0, 1.0).toDouble();
}
