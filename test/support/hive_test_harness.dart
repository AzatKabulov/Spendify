import 'dart:io';
import 'dart:typed_data';

import 'package:hive/hive.dart';
import 'package:spendify/data/local/hive_initializer.dart';
import 'package:spendify/data/local/hive_registrar.dart';

/// Spins up a real, AES-encrypted Hive stack in a throwaway temp directory so
/// repository tests exercise the same code path as the app (adapters, cipher,
/// box wiring) without Flutter plugins.
class HiveTestHarness {
  HiveTestHarness._(this._dir, this.store);

  final Directory _dir;
  final HiveStore store;

  /// Fixed 32-byte key — deterministic so the "not plaintext on disk" test can
  /// reopen the box and read the value back.
  static final Uint8List testKey = Uint8List.fromList(
    List<int>.generate(32, (i) => (i * 7 + 3) % 256),
  );

  static Future<HiveTestHarness> start() async {
    final dir = await Directory.systemTemp.createTemp('spendify_hive_test_');
    Hive.init(dir.path);
    registerSpendifyHiveAdapters();
    final store = await openEncryptedBoxes(HiveAesCipher(testKey));
    return HiveTestHarness._(dir, store);
  }

  /// Path to a box's `.hive` file on disk (for raw-bytes inspection).
  String hiveFilePath(String boxName) => '${_dir.path}/$boxName.hive';

  Future<void> dispose() async {
    await Hive.close();
    if (_dir.existsSync()) {
      await _dir.delete(recursive: true);
    }
  }
}
