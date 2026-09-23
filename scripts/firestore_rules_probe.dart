// ignore_for_file: avoid_print
// (this is a stdout CLI script, not app code — printing is the entire point)

// Security review (Phase 12) — live verification of `firestore.rules`.
//
// A rules file that is *written* correctly and rules that are *confirmed*
// correct once deployed are different claims (docs/SECURITY_AUDIT.md §"what
// still needs you"). This script closes that gap by actually attempting the
// cross-user access the rules are supposed to reject, against the real
// deployed project — not a simulator, not a unit test with a fake gateway.
//
// What it does, against the REAL Firebase project (spendify-2e8f9):
//   1. Creates two throwaway test accounts (random @example.com addresses).
//   2. As user A, writes one test document under A's own Firestore subtree.
//   3. As user B, attempts to READ and WRITE into A's subtree — every one
//      of those attempts MUST be rejected (403 / PERMISSION_DENIED) for this
//      script to report PASS.
//   4. Soft-deletes the test document (the rules deny hard deletes, same as
//      the app's own tombstone model) and deletes both test accounts.
//
// This is a standalone, on-demand verification tool — NOT part of `flutter
// test` (it needs live network + creates real, if temporary, cloud
// resources, which has no place running automatically or in CI). Run it by
// hand, occasionally, with:
//
//   dart run scripts/firestore_rules_probe.dart
//
// The API key this script needs is Firebase's public client-config
// `apiKey` (identical to the one in lib/firebase_options.dart) — not a
// secret; see docs/SECURITY_AUDIT.md's note on why this specific value is
// safe to embed in a client at all. It is read from
// android/app/google-services.json at runtime rather than hardcoded here,
// for two reasons that have nothing to do with the key being sensitive:
// this repo's own policy (CLAUDE.md §8) is that no key lives in tracked
// source, full stop, regardless of the key's sensitivity, and reading it
// from the same config file the app itself uses means this script can
// never drift onto a stale value if the Firebase project is ever
// reconfigured. Zero dependency on the Flutter package graph is kept —
// this only needs dart:io to read a JSON file, so it still runs on a bare
// `dart` SDK, no `flutter pub get` required.

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

const _projectId = 'spendify-2e8f9';
const _authBase = 'https://identitytoolkit.googleapis.com/v1';
const _firestoreBase =
    'https://firestore.googleapis.com/v1/projects/$_projectId/databases/(default)/documents';

final _http = http.Client();
final _results = <String, bool>{};

/// Read once, on first use (top-level `final` is already lazy) — every
/// `_signUp` / `_deleteAccount` call below references this exactly as it
/// referenced the old hardcoded constant.
final String _apiKey = _readApiKey();

String _readApiKey() {
  const path = 'android/app/google-services.json';
  final file = File(path);
  if (!file.existsSync()) {
    stderr.writeln(
      'Could not find $path — this script reads the Firebase project\'s '
      'public client key from it (same file the app itself uses via '
      '`flutterfire configure`). Run from the repo root with that file '
      'present.',
    );
    exit(2);
  }
  final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  final client = (json['client'] as List).first as Map<String, dynamic>;
  final apiKeys = client['api_key'] as List;
  return (apiKeys.first as Map<String, dynamic>)['current_key'] as String;
}

Future<void> main() async {
  final stamp = DateTime.now().millisecondsSinceEpoch;
  final emailA = 'spendify-audit-a-$stamp@example.com';
  final emailB = 'spendify-audit-b-$stamp@example.com';
  const password = 'AuditProbe!2026xyz';
  final probeDocId = 'audit-probe-$stamp';

  print('=' * 74);
  print('LIVE FIRESTORE RULES PROBE — project $_projectId');
  print('=' * 74);

  String? uidA, uidB;
  String? tokenA, tokenB;

  try {
    print('\n[1] Creating two temporary test accounts...');
    final a = await _signUp(emailA, password);
    uidA = a.uid;
    tokenA = a.idToken;
    final b = await _signUp(emailB, password);
    uidB = b.uid;
    tokenB = b.idToken;
    print('    account A: ${_shortUid(uidA)}');
    print('    account B: ${_shortUid(uidB)}');

    print('\n[2] As A: writing a test document under A\'s own subtree...');
    final createStatus = await _writeDoc(
      token: tokenA,
      uid: uidA,
      docId: probeDocId,
      fields: <String, Object?>{
        'userId': uidA,
        'note': 'security audit probe — safe to delete',
        'isDeleted': false,
      },
    );
    _check(
      'A can write her own document',
      createStatus == 200,
      'expected 200, got $createStatus',
    );

    print('\n[3] As A: reading it back (sanity / positive control)...');
    final selfReadStatus = await _readDoc(
      token: tokenA,
      uid: uidA,
      docId: probeDocId,
    );
    _check(
      'A can read her own document',
      selfReadStatus == 200,
      'expected 200, got $selfReadStatus',
    );

    print('\n[4] As B: attempting to READ A\'s document...');
    final crossReadStatus = await _readDoc(
      token: tokenB,
      uid: uidA,
      docId: probeDocId,
    );
    _check(
      'B is REJECTED reading A\'s document',
      crossReadStatus == 403,
      'expected 403 (PERMISSION_DENIED), got $crossReadStatus — '
          'this would be a real cross-user data leak',
    );

    print('\n[5] As B: attempting to OVERWRITE A\'s document...');
    final crossWriteStatus = await _writeDoc(
      token: tokenB,
      uid: uidA,
      docId: probeDocId,
      fields: <String, Object?>{'userId': uidA, 'note': 'overwritten by B'},
    );
    _check(
      'B is REJECTED overwriting A\'s document',
      crossWriteStatus == 403,
      'expected 403 (PERMISSION_DENIED), got $crossWriteStatus — '
          'this would let one user corrupt another\'s data',
    );

    print(
      '\n[6] As B: attempting to write into A\'s path claiming a payload '
      'userId of A\'s own uid (tests ownsPayload(), not just the path check)...',
    );
    final spoofedStatus = await _writeDoc(
      token: tokenB,
      uid: uidB,
      docId: '$probeDocId-spoof',
      fields: <String, Object?>{'userId': uidA, 'note': 'spoof attempt'},
    );
    _check(
      'B is REJECTED claiming a payload owned by A, even under B\'s own path',
      spoofedStatus == 403,
      'expected 403 (PERMISSION_DENIED), got $spoofedStatus',
    );

    print('\n[7] Cleanup: soft-deleting the test document (as A)...');
    final softDeleteStatus = await _writeDoc(
      token: tokenA,
      uid: uidA,
      docId: probeDocId,
      fields: <String, Object?>{
        'userId': uidA,
        'note': 'security audit probe — completed, soft-deleted',
        'isDeleted': true,
      },
    );
    print(
      '    soft-delete: HTTP $softDeleteStatus '
      '${softDeleteStatus == 200 ? "(ok)" : "(non-fatal if not 200)"}',
    );
  } finally {
    print('\n[8] Cleanup: deleting both test accounts...');
    if (tokenA != null) await _deleteAccount(tokenA);
    if (tokenB != null) await _deleteAccount(tokenB);
    print('    done.');
    _http.close();
  }

  print('\n${'=' * 74}');
  print('RESULTS');
  print('=' * 74);
  var allPass = true;
  _results.forEach((name, passed) {
    print('${passed ? "PASS" : "FAIL"}  $name');
    if (!passed) allPass = false;
  });
  print('=' * 74);
  if (!allPass) {
    print(
      'At least one check FAILED — the deployed Firestore rules do not '
      'currently reject cross-user access as written. Do not treat the '
      'rules file as verified until this is fixed and re-run clean.',
    );
    exit(1);
  }
  print('All checks passed — the deployed rules reject cross-user access.');
}

void _check(String name, bool passed, String failureDetail) {
  _results[name] = passed;
  print('    -> ${passed ? "PASS" : "FAIL: $failureDetail"}');
}

String _shortUid(String uid) =>
    uid.length > 8 ? '${uid.substring(0, 8)}…' : uid;

class _AuthResult {
  _AuthResult(this.uid, this.idToken);
  final String uid;
  final String idToken;
}

Future<_AuthResult> _signUp(String email, String password) async {
  final res = await _http.post(
    Uri.parse('$_authBase/accounts:signUp?key=$_apiKey'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      'email': email,
      'password': password,
      'returnSecureToken': true,
    }),
  );
  if (res.statusCode != 200) {
    throw Exception('sign-up failed (${res.statusCode}): ${res.body}');
  }
  final body = jsonDecode(res.body) as Map<String, dynamic>;
  return _AuthResult(body['localId'] as String, body['idToken'] as String);
}

Future<void> _deleteAccount(String idToken) async {
  final res = await _http.post(
    Uri.parse('$_authBase/accounts:delete?key=$_apiKey'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'idToken': idToken}),
  );
  print(
    '    delete: HTTP ${res.statusCode} '
    '${res.statusCode == 200 ? "(confirmed removed)" : "(check manually: ${res.body})"}',
  );
}

Future<int> _readDoc({
  required String token,
  required String uid,
  required String docId,
}) async {
  final res = await _http.get(
    Uri.parse('$_firestoreBase/users/$uid/transactions/$docId'),
    headers: {'Authorization': 'Bearer $token'},
  );
  return res.statusCode;
}

Future<int> _writeDoc({
  required String token,
  required String uid,
  required String docId,
  required Map<String, Object?> fields,
}) async {
  final res = await _http.patch(
    Uri.parse('$_firestoreBase/users/$uid/transactions/$docId'),
    headers: {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    },
    body: jsonEncode({'fields': fields.map((k, v) => MapEntry(k, _value(v)))}),
  );
  return res.statusCode;
}

Map<String, Object?> _value(Object? v) {
  if (v is String) return {'stringValue': v};
  if (v is bool) return {'booleanValue': v};
  if (v is int) return {'integerValue': v.toString()};
  throw UnsupportedError('unhandled Firestore value type: ${v.runtimeType}');
}
