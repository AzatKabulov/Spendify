import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/theme/insets.dart';
import '../../domain/entities/sync_snapshot.dart';
import '../providers/auth_providers.dart';
import '../providers/privacy_providers.dart';
import '../providers/repository_providers.dart';
import '../providers/sync_providers.dart';
import '../widgets/form_header.dart';
import '../widgets/settings/settings_widgets.dart';

/// Data & Storage (mockup: "Backup, restore, export") — sync status, export,
/// rebuilding the report cache, and deleting local data. Ported from the old
/// flat Settings list.
///
/// **"Restore" is described, not offered as a separate button.** There is no
/// manual restore action distinct from what already happens automatically:
/// signing in on a fresh install pulls the Firestore backup before Home ever
/// shows (`SessionNotifier.enter` → `syncBootstrapProvider.restore()`). A
/// second button that duplicated that would either do nothing new or repeat
/// it, so this just states the real behaviour honestly instead.
class DataStorageScreen extends ConsumerStatefulWidget {
  const DataStorageScreen({super.key});

  @override
  ConsumerState<DataStorageScreen> createState() => _DataStorageScreenState();
}

class _DataStorageScreenState extends ConsumerState<DataStorageScreen> {
  bool _rebuilding = false;
  bool _syncing = false;
  bool _exporting = false;
  bool _wiping = false;

  Future<void> _syncNow() async {
    setState(() => _syncing = true);
    try {
      await ref.read(syncNowProvider)();
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

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

  Future<void> _exportData() async {
    setState(() => _exporting = true);
    final messenger = ScaffoldMessenger.of(context);
    final String json;
    try {
      json = await ref
          .read(dataExporterProvider)
          .buildJsonString(
            generatedAt: DateTime.now(),
            account: ref.read(currentUserEmailProvider),
          );
    } catch (_) {
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Could not build the export.')),
        );
      }
      return;
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Data exported'),
        content: const Text(
          'A complete JSON copy of your data is ready. Save it to a file, or '
          'copy it to the clipboard.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: json));
              Navigator.of(dialogContext).pop();
              messenger.showSnackBar(
                const SnackBar(content: Text('Export copied to clipboard')),
              );
            },
            child: const Text('Copy JSON'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _saveExportToFile(json);
            },
            child: const Text('Save file'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveExportToFile(String json) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final stamp = DateFormat('yyyyMMdd-HHmmss').format(DateTime.now());
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/spendify-export-$stamp.json');
      await file.writeAsString(json);
      messenger.showSnackBar(SnackBar(content: Text('Saved to ${file.path}')));
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Could not save a file — copy the JSON instead.'),
        ),
      );
    }
  }

  Future<void> _deleteAllData() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete all local data?'),
        content: const Text(
          'This permanently erases every transaction, budget, category and '
          'reward on this device, and signs you out.\n\n'
          'Your cloud backup is NOT deleted — sign in again to restore it, or '
          'create a new account to start fresh.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete everything'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _wiping = true);
    try {
      await ref.read(localDataWiperProvider).wipe();
    } finally {
      if (mounted) setState(() => _wiping = false);
    }
    // Drop the session -> AuthGate rebuilds to the sign-in screen underneath.
    ref.read(sessionProvider.notifier).leave();
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final syncAvailable = ref.watch(syncAvailableProvider);
    final syncSnap =
        ref.watch(syncSnapshotProvider).value ?? const SyncSnapshot();

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: <Widget>[
            const FormHeader(
              title: 'Data & Storage',
              subtitle: 'Backup, restore and export',
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  Insets.md,
                  0,
                  Insets.md,
                  Insets.lg,
                ),
                children: <Widget>[
                  if (!syncAvailable)
                    const SettingsGroup(
                      label: 'Backup & sync',
                      rows: <Widget>[
                        SettingsRow(
                          icon: Icons.cloud_off_outlined,
                          title: 'Backup not set up',
                          subtitle:
                              'Sync to the cloud becomes available once '
                              'Firebase is configured for this build.',
                        ),
                      ],
                    )
                  else
                    SettingsGroup(
                      label: 'Backup & sync',
                      rows: <Widget>[
                        SettingsRow(
                          icon: _syncIcon(syncSnap.phase),
                          title: _syncTitle(syncSnap),
                          subtitle: _syncSubtitle(syncSnap),
                        ),
                        SettingsRow(
                          icon: Icons.sync,
                          title: 'Sync now',
                          enabled: !(_syncing || syncSnap.isSyncing),
                          onTap: _syncNow,
                          trailing: (_syncing || syncSnap.isSyncing)
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : null,
                        ),
                        const SettingsRow(
                          icon: Icons.cloud_download_outlined,
                          title: 'Restoring on a new device',
                          subtitle:
                              'Signing in on a fresh install automatically '
                              'pulls your backup before Home opens — nothing '
                              'to tap here.',
                        ),
                      ],
                    ),
                  const SizedBox(height: Insets.md - 2),
                  SettingsGroup(
                    label: 'Your data',
                    rows: <Widget>[
                      SettingsRow(
                        icon: Icons.refresh,
                        title: 'Rebuild report data',
                        subtitle:
                            'Recomputes every cached total from your '
                            'transactions. Use this if a report or budget '
                            'figure looks wrong.',
                        enabled: !_rebuilding,
                        onTap: _rebuildAggregates,
                        trailing: _rebuilding
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : null,
                      ),
                      SettingsRow(
                        icon: Icons.download_outlined,
                        title: 'Export my data',
                        subtitle:
                            'A complete JSON copy of everything you added',
                        enabled: !_exporting,
                        onTap: _exportData,
                        trailing: _exporting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : null,
                      ),
                      SettingsRow(
                        icon: Icons.delete_forever_outlined,
                        title: 'Delete all local data',
                        subtitle: 'Cloud backup is not affected',
                        danger: true,
                        enabled: !_wiping,
                        onTap: _deleteAllData,
                        trailing: _wiping
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : null,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

IconData _syncIcon(SyncPhase phase) => switch (phase) {
  SyncPhase.syncing => Icons.cloud_sync_outlined,
  SyncPhase.offline => Icons.cloud_off_outlined,
  SyncPhase.error => Icons.sync_problem_outlined,
  SyncPhase.idle => Icons.cloud_done_outlined,
};

String _syncTitle(SyncSnapshot s) => switch (s.phase) {
  SyncPhase.syncing => 'Backing up…',
  SyncPhase.offline => 'Offline',
  SyncPhase.error => 'Last backup failed',
  SyncPhase.idle => 'Backed up',
};

String _syncSubtitle(SyncSnapshot s) {
  final parts = <String>[];
  final at = s.lastSyncedAt;
  if (at != null) {
    parts.add('Last synced ${DateFormat('d MMM, HH:mm').format(at.toLocal())}');
  } else {
    parts.add('Not synced yet');
  }
  if (s.pendingCount > 0) {
    parts.add('${s.pendingCount} pending');
  }
  if (s.phase == SyncPhase.error && s.lastError != null) {
    parts.add(s.lastError!);
  }
  return parts.join(' · ');
}
