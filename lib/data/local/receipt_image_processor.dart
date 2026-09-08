import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';

/// Where a receipt photo comes from.
enum ReceiptImageSource { camera, gallery }

/// A compressed receipt image, ready to hand to Gemini. The bytes live only in
/// memory — no file is kept (CLAUDE.md §7: receipt images are not retained
/// locally after processing).
class ReceiptCapture {
  const ReceiptCapture({
    required this.jpegBytes,
    required this.originalBytes,
    required this.compressedBytes,
  });

  final Uint8List jpegBytes;
  final int originalBytes;
  final int compressedBytes;

  double get compressionRatio =>
      originalBytes == 0 ? 1 : compressedBytes / originalBytes;
}

/// The user backed out of the picker/camera.
class ReceiptCaptureCancelled implements Exception {
  const ReceiptCaptureCancelled();
}

/// Camera or photo-library permission was denied.
class ReceiptPermissionDenied implements Exception {
  const ReceiptPermissionDenied(this.source);
  final ReceiptImageSource source;
}

/// The chosen file could not be decoded as an image.
class ReceiptImageUnreadable implements Exception {
  const ReceiptImageUnreadable();
}

abstract interface class ReceiptImageProcessor {
  /// Capture (or pick) a photo and return it compressed. Any temp file the
  /// platform created is deleted before this returns — including on error.
  Future<ReceiptCapture> capture(ReceiptImageSource source);
}

class DeviceReceiptImageProcessor implements ReceiptImageProcessor {
  DeviceReceiptImageProcessor({ImagePicker? picker})
    : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  /// Report §3.5.1 commits to client-side compression. Receipts are text-dense
  /// and usually portrait, so we keep ~1600px on the **short** edge (more on
  /// the long edge helps line-item legibility) at JPEG q80. A 12 MP phone photo
  /// (~3-5 MB) lands around 200-500 KB.
  static const int _minEdge = 1600;
  static const int _quality = 80;

  @override
  Future<ReceiptCapture> capture(ReceiptImageSource source) async {
    final XFile? picked;
    try {
      picked = await _picker.pickImage(
        source: source == ReceiptImageSource.camera
            ? ImageSource.camera
            : ImageSource.gallery,
        maxWidth: 4000,
        imageQuality: 100, // compress ourselves, below
      );
    } on PlatformException catch (e) {
      if (e.code == 'camera_access_denied' ||
          e.code == 'photo_access_denied' ||
          e.code == 'permission') {
        throw ReceiptPermissionDenied(source);
      }
      rethrow;
    }
    if (picked == null) throw const ReceiptCaptureCancelled();

    final path = picked.path;
    var originalBytes = 0;
    try {
      originalBytes = await File(path).length();
      final Uint8List? compressed = await FlutterImageCompress.compressWithFile(
        path,
        minWidth: _minEdge,
        minHeight: _minEdge,
        quality: _quality,
        format: CompressFormat.jpeg,
        keepExif: false,
      );
      if (compressed == null || compressed.isEmpty) {
        throw const ReceiptImageUnreadable();
      }
      if (!kReleaseMode) {
        debugPrint(
          'RECEIPT: compressed ${_kb(originalBytes)} -> '
          '${_kb(compressed.length)} '
          '(${(compressed.length / (originalBytes == 0 ? 1 : originalBytes) * 100).round()}%)',
        );
      }
      return ReceiptCapture(
        jpegBytes: compressed,
        originalBytes: originalBytes,
        compressedBytes: compressed.length,
      );
    } finally {
      // ETHICS (CLAUDE.md §7): never leave the receipt image on disk.
      await _deleteQuietly(path);
    }
  }

  static Future<void> _deleteQuietly(String path) async {
    try {
      final f = File(path);
      if (f.existsSync()) await f.delete();
    } catch (_) {
      // best effort — a temp file the OS will clear anyway
    }
  }

  static String _kb(int bytes) => '${(bytes / 1024).round()} KB';
}
