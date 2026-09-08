import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/receipt_image_processor.dart';
import '../providers/receipt_scan_providers.dart';
import 'transaction_form_screen.dart';

/// Entry point for the receipt scanner (Phase 7). Pick a source, wait for
/// Gemini, then hand off to the pre-filled confirmation form. Any failure
/// drops cleanly to blank manual entry — never a dead end (CLAUDE.md §7).
class ReceiptScanScreen extends ConsumerStatefulWidget {
  const ReceiptScanScreen({super.key});

  @override
  ConsumerState<ReceiptScanScreen> createState() => _ReceiptScanScreenState();
}

class _ReceiptScanScreenState extends ConsumerState<ReceiptScanScreen> {
  @override
  void initState() {
    super.initState();
    // Fresh flow each time this screen opens.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => ref.read(receiptScanControllerProvider.notifier).reset(),
    );
  }

  void _openManualForm() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const TransactionFormScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<ReceiptScanState>(receiptScanControllerProvider, (_, next) {
      if (next is ReceiptScanReady) {
        ref.read(receiptScanControllerProvider.notifier).reset();
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => TransactionFormScreen(prefill: next.draft),
          ),
        );
      }
    });

    final state = ref.watch(receiptScanControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Scan receipt')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: switch (state) {
            ReceiptScanBusy(:final label) => _Busy(label: label),
            ReceiptScanFailed(:final message) => _Failed(
              message: message,
              onRetry: () =>
                  ref.read(receiptScanControllerProvider.notifier).reset(),
              onManual: _openManualForm,
            ),
            _ => _SourcePicker(
              onPick: (source) =>
                  ref.read(receiptScanControllerProvider.notifier).scan(source),
              onManual: _openManualForm,
            ),
          },
        ),
      ),
    );
  }
}

class _SourcePicker extends StatelessWidget {
  const _SourcePicker({required this.onPick, required this.onManual});

  final void Function(ReceiptImageSource) onPick;
  final VoidCallback onManual;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Icon(
          Icons.receipt_long_outlined,
          size: 64,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 16),
        Text(
          'Photograph a receipt and we\'ll fill in the amount, date and '
          'merchant for you to check.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 32),
        FilledButton.icon(
          onPressed: () => onPick(ReceiptImageSource.camera),
          icon: const Icon(Icons.photo_camera_outlined),
          label: const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('Take a photo'),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => onPick(ReceiptImageSource.gallery),
          icon: const Icon(Icons.photo_library_outlined),
          label: const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('Choose from gallery'),
          ),
        ),
        const SizedBox(height: 24),
        TextButton(
          onPressed: onManual,
          child: const Text('Enter manually instead'),
        ),
      ],
    );
  }
}

class _Busy extends StatelessWidget {
  const _Busy({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(label),
        ],
      ),
    );
  }
}

class _Failed extends StatelessWidget {
  const _Failed({
    required this.message,
    required this.onRetry,
    required this.onManual,
  });

  final String message;
  final VoidCallback onRetry;
  final VoidCallback onManual;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Icon(
          Icons.error_outline,
          size: 56,
          color: Theme.of(context).colorScheme.error,
        ),
        const SizedBox(height: 16),
        Text(message, textAlign: TextAlign.center),
        const SizedBox(height: 32),
        FilledButton(
          onPressed: onManual,
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('Enter manually'),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: onRetry,
          child: const Text('Try another photo'),
        ),
      ],
    );
  }
}
