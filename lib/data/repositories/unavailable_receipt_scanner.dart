import 'dart:typed_data';

import '../../domain/entities/receipt_extraction.dart';
import '../../domain/repositories/receipt_scanner_repository.dart';

/// Stand-in used when AI features are off (no key, or consent not granted —
/// Phase 10). Every call fails fast with no network I/O; the real
/// `GeminiReceiptClient` is never constructed.
class UnavailableReceiptScanner implements ReceiptScannerRepository {
  const UnavailableReceiptScanner();

  @override
  Future<ReceiptExtraction> extract(Uint8List jpegBytes) async =>
      throw const ReceiptScannerUnavailableException();
}
