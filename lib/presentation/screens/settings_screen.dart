import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/repository_providers.dart';

/// Minimal settings. Phase 10 fills this in (consent, AI toggles, wipe data);
/// for now it hosts the report-data rebuild action (Phase 4 Part B).
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _rebuilding = false;

  Future<void> _rebuildAggregates() async {
    setState(() => _rebuilding = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final txns = await ref.read(transactionRepositoryProvider).getAll();
      await ref.read(aggregationMaintenanceProvider).rebuildAll(txns);
      messenger.showSnackBar(
        const SnackBar(content: Text('Report data rebuilt')),
      );
    } finally {
      if (mounted) setState(() => _rebuilding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: <Widget>[
          ListTile(
            leading: const Icon(Icons.refresh),
            title: const Text('Rebuild report data'),
            subtitle: const Text(
              'Recomputes every cached total from your transactions. Use this '
              'if a report or budget figure looks wrong.',
            ),
            trailing: _rebuilding
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : null,
            onTap: _rebuilding ? null : _rebuildAggregates,
          ),
        ],
      ),
    );
  }
}
