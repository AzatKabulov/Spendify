import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/gemini_config.dart';
import '../../data/local/receipt_image_processor.dart';
import '../../data/remote/gemini_client.dart';
import '../../domain/entities/receipt_extraction.dart';
import '../../domain/repositories/connectivity_monitor.dart';
import '../../domain/repositories/receipt_scanner_repository.dart';
import '../../domain/services/category_matcher.dart';
import 'category_providers.dart';
import 'sync_providers.dart';

/// The Gemini API key (overridable in tests). Empty = scanner not configured.
final geminiApiKeyProvider = Provider<String>((ref) => kGeminiApiKey);

/// `true` when receipt scanning is set up on this build (a key is present).
/// Connectivity is checked at scan time, not here.
final receiptScanConfiguredProvider = Provider<bool>(
  (ref) => ref.watch(geminiApiKeyProvider).isNotEmpty,
);

final receiptScannerRepositoryProvider = Provider<ReceiptScannerRepository>((
  ref,
) {
  return GeminiReceiptClient(
    apiKey: ref.watch(geminiApiKeyProvider),
    model: kGeminiModel,
  );
});

final receiptImageProcessorProvider = Provider<ReceiptImageProcessor>(
  (ref) => DeviceReceiptImageProcessor(),
);

/// Which pre-filled fields on the confirmation form came from the AI.
enum ReceiptField { amount, date, category, note }

/// Extraction result mapped onto transaction-form inputs, ready to pre-fill the
/// Phase 2 form. Never saved without an explicit user tap (CLAUDE.md §7).
class ReceiptDraft {
  const ReceiptDraft({
    this.amountMinor,
    this.date,
    this.categoryId,
    this.note,
    this.confidence = 0.0,
    this.aiFilled = const <ReceiptField>{},
    this.suggestedCategoryUnmatched,
  });

  final int? amountMinor;
  final DateTime? date;
  final String? categoryId;
  final String? note;
  final double confidence;

  /// Fields that were populated from the scan (shown with an "from receipt"
  /// marker; everything else is blank for the user to fill).
  final Set<ReceiptField> aiFilled;

  /// Gemini's category label when it did NOT match any existing category — the
  /// form shows it as a hint but leaves the picker empty.
  final String? suggestedCategoryUnmatched;

  bool get isLowConfidence => confidence < 0.5;
}

/// State machine for the scan flow.
sealed class ReceiptScanState {
  const ReceiptScanState();
}

class ReceiptScanIdle extends ReceiptScanState {
  const ReceiptScanIdle();
}

class ReceiptScanBusy extends ReceiptScanState {
  const ReceiptScanBusy(this.label);
  final String label;
}

class ReceiptScanReady extends ReceiptScanState {
  const ReceiptScanReady(this.draft);
  final ReceiptDraft draft;
}

/// A recoverable failure — the UI shows [message] and offers manual entry.
class ReceiptScanFailed extends ReceiptScanState {
  const ReceiptScanFailed(this.message, {this.offline = false});
  final String message;
  final bool offline;
}

final receiptScanControllerProvider =
    NotifierProvider<ReceiptScanController, ReceiptScanState>(
      ReceiptScanController.new,
    );

class ReceiptScanController extends Notifier<ReceiptScanState> {
  @override
  ReceiptScanState build() => const ReceiptScanIdle();

  void reset() => state = const ReceiptScanIdle();

  Future<void> scan(ReceiptImageSource source) async {
    if (state is ReceiptScanBusy) return;

    final ConnectivityMonitor connectivity = ref.read(
      connectivityMonitorProvider,
    );
    if (!await connectivity.isOnline) {
      state = const ReceiptScanFailed(
        'Receipt scanning needs an internet connection. You can still add the '
        'transaction manually.',
        offline: true,
      );
      return;
    }

    ReceiptCapture capture;
    try {
      state = const ReceiptScanBusy('Preparing the photo…');
      capture = await ref.read(receiptImageProcessorProvider).capture(source);
    } on ReceiptCaptureCancelled {
      state = const ReceiptScanIdle();
      return;
    } on ReceiptPermissionDenied catch (e) {
      state = ReceiptScanFailed(
        e.source == ReceiptImageSource.camera
            ? 'Camera access is off. Turn it on in Settings, or add the '
                  'transaction manually.'
            : 'Photo access is off. Turn it on in Settings, or add the '
                  'transaction manually.',
      );
      return;
    } on ReceiptImageUnreadable {
      state = const ReceiptScanFailed(
        "That image couldn't be read. Try another photo or add it manually.",
      );
      return;
    }

    ReceiptExtraction extraction;
    try {
      state = const ReceiptScanBusy('Reading the receipt…');
      extraction = await ref
          .read(receiptScannerRepositoryProvider)
          .extract(capture.jpegBytes);
    } on ReceiptScanException catch (e) {
      if (!kReleaseMode) debugPrint('RECEIPT scan failed: $e');
      state = ReceiptScanFailed(e.message);
      return;
    }

    state = ReceiptScanReady(_toDraft(extraction));
  }

  ReceiptDraft _toDraft(ReceiptExtraction e) {
    final categories = ref.read(categoriesProvider).value ?? const [];
    final matchedId = matchCategoryId(e.suggestedCategory, categories);

    final aiFilled = <ReceiptField>{
      if (e.totalAmountMinor != null) ReceiptField.amount,
      if (e.date != null) ReceiptField.date,
      if (matchedId != null) ReceiptField.category,
      if (e.merchant != null) ReceiptField.note,
    };

    return ReceiptDraft(
      amountMinor: e.totalAmountMinor,
      date: e.date,
      categoryId: matchedId,
      note: e.merchant,
      confidence: e.confidence,
      aiFilled: aiFilled,
      suggestedCategoryUnmatched: matchedId == null
          ? e.suggestedCategory
          : null,
    );
  }
}
