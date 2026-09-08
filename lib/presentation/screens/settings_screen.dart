import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/sync_snapshot.dart';
import '../providers/auth_providers.dart';
import '../providers/repository_providers.dart';
import '../providers/sync_providers.dart';

/// Minimal settings. Phase 10 fills this in (consent, AI toggles, wipe data);
/// for now it hosts the account section (Phase 5) and the report-data rebuild
/// action (Phase 4 Part B).
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _rebuilding = false;
  bool _signingOut = false;
  bool _syncing = false;

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

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
          'Your data stays on this device. You can sign back in any time.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _signingOut = true);
    await ref.read(signOutProvider)();
    if (!mounted) return;
    // AuthGate has already rebuilt to the sign-in screen underneath; leave the
    // pushed screens (Settings, Home) so it is visible.
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final email = ref.watch(currentUserEmailProvider);
    final syncAvailable = ref.watch(syncAvailableProvider);
    final syncSnap =
        ref.watch(syncSnapshotProvider).value ?? const SyncSnapshot();

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: <Widget>[
          const _SectionHeader('Account'),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: Text(email ?? 'Signed in'),
            subtitle: email == null ? null : const Text('Signed in'),
          ),
          ListTile(
            leading: Icon(
              Icons.logout,
              color: Theme.of(context).colorScheme.error,
            ),
            title: Text(
              'Sign out',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            trailing: _signingOut
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : null,
            onTap: _signingOut ? null : _signOut,
          ),
          const Divider(),
          const _SectionHeader('Backup & sync'),
          if (!syncAvailable)
            const ListTile(
              leading: Icon(Icons.cloud_off_outlined),
              title: Text('Backup not set up'),
              subtitle: Text(
                'Sync to the cloud becomes available once Firebase is '
                'configured for this build.',
              ),
            )
          else ...<Widget>[
            ListTile(
              leading: Icon(_syncIcon(syncSnap.phase)),
              title: Text(_syncTitle(syncSnap)),
              subtitle: Text(_syncSubtitle(syncSnap)),
            ),
            ListTile(
              leading: const Icon(Icons.sync),
              title: const Text('Sync now'),
              trailing: (_syncing || syncSnap.isSyncing)
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : null,
              onTap: (_syncing || syncSnap.isSyncing) ? null : _syncNow,
            ),
          ],
          const Divider(),
          const _SectionHeader('Data'),
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

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        text,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}
