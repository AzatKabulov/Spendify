import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/insets.dart';
import '../../data/local/receipt_image_processor.dart';
import '../providers/receipt_scan_providers.dart';
import '../widgets/form_header.dart';
import '../widgets/tactile_press.dart';
import 'transaction_form_screen.dart';

/// Entry point for the receipt scanner (Phase 7). Pick a source, wait for
/// Gemini, then hand off to the pre-filled confirmation form. Any failure
/// drops cleanly to blank manual entry — never a dead end (CLAUDE.md §7).
///
/// The camera itself is the device's own native camera app via `image_picker`
/// (CLAUDE.md's fixed stack, decided Phase 7) — this screen is the source
/// picker shown before it, not a custom live-preview camera UI, since a
/// from-scratch camera overlay would mean adopting a different capture
/// package than the report commits to. There is also no persisted receipt
/// thumbnail anywhere in this flow: images are never retained after
/// processing (CLAUDE.md §7.5).
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
      body: SafeArea(
        child: Column(
          children: <Widget>[
            const FormHeader(
              title: 'Scan Receipt',
              subtitle: 'Powered by Google Gemini',
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(Insets.md),
                child: switch (state) {
                  ReceiptScanBusy(:final label) => _Busy(label: label),
                  ReceiptScanFailed(:final message) => _Failed(
                    message: message,
                    onRetry: () => ref
                        .read(receiptScanControllerProvider.notifier)
                        .reset(),
                    onManual: _openManualForm,
                  ),
                  _ => _SourcePicker(
                    onPick: (source) => ref
                        .read(receiptScanControllerProvider.notifier)
                        .scan(source),
                    onManual: _openManualForm,
                  ),
                },
              ),
            ),
          ],
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Center(
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.document_scanner_outlined,
              size: 56,
              color: scheme.onPrimaryContainer,
            ),
          ),
        ),
        const SizedBox(height: Insets.lg),
        Text(
          'Photograph a receipt',
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: Insets.xs),
        Text(
          'Gemini will read the amount, date and merchant for you to check '
          'and confirm — nothing saves automatically.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: Insets.xl),
        TactilePress(
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton.icon(
              onPressed: () => onPick(ReceiptImageSource.camera),
              icon: const Icon(Icons.photo_camera_outlined),
              label: const Text('Take a photo'),
            ),
          ),
        ),
        const SizedBox(height: Insets.sm),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: OutlinedButton.icon(
            onPressed: () => onPick(ReceiptImageSource.gallery),
            icon: const Icon(Icons.photo_library_outlined),
            label: const Text('Choose from gallery'),
          ),
        ),
        const SizedBox(height: Insets.md),
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
          const SizedBox(height: Insets.md),
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
    final scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Icon(Icons.error_outline, size: 56, color: scheme.error),
        const SizedBox(height: Insets.md),
        Text(message, textAlign: TextAlign.center),
        const SizedBox(height: Insets.xl),
        TactilePress(
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: onManual,
              child: const Text('Enter manually'),
            ),
          ),
        ),
        const SizedBox(height: Insets.sm),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: OutlinedButton(
            onPressed: onRetry,
            child: const Text('Try another photo'),
          ),
        ),
      ],
    );
  }
}
