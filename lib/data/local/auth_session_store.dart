import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/constants.dart';

/// The locally persisted authenticated session — the *only* thing startup
/// routing consults (CLAUDE.md §3 / §6: the session decision must be answerable
/// from local state alone, never a `FirebaseAuth` stream that can hang offline).
class AuthSession {
  const AuthSession({required this.uid, this.email, this.displayName});

  final String uid;
  final String? email;

  /// The name shown in the home greeting (Firebase display name), if any.
  final String? displayName;

  @override
  bool operator ==(Object other) =>
      other is AuthSession &&
      other.uid == uid &&
      other.email == email &&
      other.displayName == displayName;

  @override
  int get hashCode => Object.hash(uid, email, displayName);

  @override
  String toString() => 'AuthSession($uid, ${email ?? "<no email>"})';
}

/// Reads / writes [AuthSession] to hardware-backed secure storage. No plaintext
/// credentials — the UID is an opaque identifier and the password is never
/// stored (CLAUDE.md §6 Security / OWASP MASVS).
abstract interface class AuthSessionStore {
  Future<AuthSession?> read();
  Future<void> write(AuthSession session);
  Future<void> clear();
}

class SecureStorageAuthSessionStore implements AuthSessionStore {
  SecureStorageAuthSessionStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<AuthSession?> read() async {
    final uid = await _storage.read(key: kAuthUidKeyName);
    if (uid == null || uid.isEmpty) return null;
    final email = await _storage.read(key: kAuthEmailKeyName);
    final name = await _storage.read(key: kAuthNameKeyName);
    return AuthSession(uid: uid, email: email, displayName: name);
  }

  @override
  Future<void> write(AuthSession session) async {
    await _storage.write(key: kAuthUidKeyName, value: session.uid);
    if (session.email != null) {
      await _storage.write(key: kAuthEmailKeyName, value: session.email);
    } else {
      await _storage.delete(key: kAuthEmailKeyName);
    }
    final name = session.displayName;
    if (name != null && name.isNotEmpty) {
      await _storage.write(key: kAuthNameKeyName, value: name);
    } else {
      await _storage.delete(key: kAuthNameKeyName);
    }
  }

  @override
  Future<void> clear() async {
    await _storage.delete(key: kAuthUidKeyName);
    await _storage.delete(key: kAuthEmailKeyName);
    await _storage.delete(key: kAuthNameKeyName);
  }
}
