import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive/hive.dart';

import '../../core/constants.dart';
import '../../core/errors.dart';

/// Supplies the 256-bit AES key that every Hive box is opened with.
///
/// The key itself lives in `flutter_secure_storage`, which on Android wraps it
/// with a key held in the hardware-backed Keystore (CLAUDE.md §3.2.2 "encrypted
/// at rest", no plaintext credentials on device).
abstract interface class EncryptionKeyStore {
  /// Returns the stored key, generating and persisting one on first call.
  Future<Uint8List> getOrCreateKey();

  /// Removes the key. The next [getOrCreateKey] mints a fresh one — which
  /// makes every existing encrypted box unreadable, so this is only for a
  /// full "delete all local data" wipe (Phase 10).
  Future<void> deleteKey();
}

class SecureStorageEncryptionKeyStore implements EncryptionKeyStore {
  SecureStorageEncryptionKeyStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<Uint8List> getOrCreateKey() async {
    try {
      final existing = await _storage.read(key: kHiveEncryptionKeyName);
      if (existing != null) {
        final bytes = base64Decode(existing);
        if (bytes.length != 32) {
          throw EncryptionKeyException(
            'Stored Hive key is ${bytes.length} bytes, expected 32',
          );
        }
        return Uint8List.fromList(bytes);
      }

      final fresh = Uint8List.fromList(Hive.generateSecureKey());
      await _storage.write(
        key: kHiveEncryptionKeyName,
        value: base64Encode(fresh),
      );
      return fresh;
    } on EncryptionKeyException {
      rethrow;
    } catch (e) {
      throw EncryptionKeyException(
        'Could not read or create the Hive encryption key',
        cause: e,
      );
    }
  }

  @override
  Future<void> deleteKey() async {
    try {
      await _storage.delete(key: kHiveEncryptionKeyName);
    } catch (e) {
      throw EncryptionKeyException('Could not delete the Hive key', cause: e);
    }
  }
}
