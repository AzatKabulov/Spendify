/// Shared helpers for pulling a JSON value out of a hostile LLM response —
/// markdown ```json fences, leading/trailing prose, a `}` inside a string
/// value. Pure, no I/O. Used by both `receipt_json_parser.dart` (Phase 7) and
/// `advice_json_parser.dart` (Phase 9).
library;

/// Strips a leading/trailing ``` or ```json fence.
String stripCodeFences(String raw) {
  final fence = RegExp(r'^```(?:json)?\s*|\s*```$', multiLine: true);
  return raw.trim().replaceAll(fence, '').trim();
}

/// The substring from the first [open] to its matching close, brace-balanced
/// and string-aware so a bracket inside a quoted value doesn't end it early.
/// [open] is `{` (object) or `[` (array). Returns `null` if unbalanced or
/// absent.
String? firstBalanced(String raw, {String open = '{'}) {
  final close = open == '{' ? '}' : ']';
  final start = raw.indexOf(open);
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
    } else if (ch == open) {
      depth++;
    } else if (ch == close) {
      depth--;
      if (depth == 0) return raw.substring(start, i + 1);
    }
  }
  return null;
}
