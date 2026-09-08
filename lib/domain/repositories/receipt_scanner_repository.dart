/// The receipt-extraction boundary (Phase 7). The Gemini transport is imported
/// by exactly one implementation (`data/remote/gemini_client.dart`) so the AI
/// layer is replaceable (CLAUDE.md §6).
///
/// Ethics (CLAUDE.md §7): the implementation sends **only the image** — never
/// the user's transactions, category list, or any other personal data.
library;

import 'dart:typed_data';

import '../entities/receipt_extraction.dart';

abstract interface class ReceiptScannerRepository {
  /// Extract fields from a compressed JPEG. Returns a possibly-partial
  /// [ReceiptExtraction]; throws [ReceiptScanException] on a transport/API
  /// failure. Never throws for a merely low-quality result.
  Future<ReceiptExtraction> extract(Uint8List jpegBytes);
}

/// Why a scan failed. Each maps to a short, non-alarming message; the UI always
/// falls back to the blank manual form, never a dead end.
sealed class ReceiptScanException implements Exception {
  const ReceiptScanException(this.message, {this.cause});
  final String message;
  final Object? cause;

  @override
  String toString() => '$runtimeType($message)';
}

/// No connectivity, DNS failure, socket closed.
final class ReceiptNetworkException extends ReceiptScanException {
  const ReceiptNetworkException({Object? cause})
    : super(
        "Couldn't reach the scanner. Check your connection and try again, or "
        'enter it manually.',
        cause: cause,
      );
}

/// The request took too long (explicit ~30s timeout).
final class ReceiptTimeoutException extends ReceiptScanException {
  const ReceiptTimeoutException({Object? cause})
    : super(
        'The scan took too long. Try again or enter it manually.',
        cause: cause,
      );
}

/// HTTP 429 / quota.
final class ReceiptRateLimitedException extends ReceiptScanException {
  const ReceiptRateLimitedException({Object? cause})
    : super(
        'The scanner is busy right now. Wait a moment or enter it manually.',
        cause: cause,
      );
}

/// Gemini refused the image (safety filters) or returned an empty candidate.
final class ReceiptBlockedException extends ReceiptScanException {
  const ReceiptBlockedException({Object? cause})
    : super(
        "The scanner couldn't read that image. Try a clearer photo or enter it "
        'manually.',
        cause: cause,
      );
}

/// A non-2xx API response, or a body we could not make any JSON out of.
final class ReceiptApiException extends ReceiptScanException {
  const ReceiptApiException(super.message, {super.cause});
}

/// The API key was never configured on this build (the A/B key-placement
/// decision — see CLAUDE.md §9 — is still pending).
final class ReceiptScannerUnavailableException extends ReceiptScanException {
  const ReceiptScannerUnavailableException()
    : super('Receipt scanning is not set up in this build yet.');
}
