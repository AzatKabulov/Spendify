import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/sync_snapshot.dart';
import '../providers/sync_providers.dart';
import '../screens/settings_screen.dart';

/// Small, unobtrusive backup-status icon for the home AppBar (CLAUDE.md §3: the
/// UI *observes* sync, never waits on it). Hidden entirely when sync is not
/// configured. Tap -> Settings, where "Sync now" and details live.
class SyncStatusIndicator extends ConsumerWidget {
  const SyncStatusIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(syncAvailableProvider)) return const SizedBox.shrink();
    final snap = ref.watch(syncSnapshotProvider).value ?? const SyncSnapshot();

    final (IconData icon, String tooltip) = switch (snap.phase) {
      SyncPhase.syncing => (Icons.cloud_sync_outlined, 'Backing up…'),
      SyncPhase.offline => (
        Icons.cloud_off_outlined,
        'Offline — changes will back up later',
      ),
      SyncPhase.error => (
        Icons.sync_problem_outlined,
        snap.lastError ?? 'Backup failed — will retry',
      ),
      SyncPhase.idle when snap.pendingCount > 0 => (
        Icons.cloud_upload_outlined,
        '${snap.pendingCount} change${snap.pendingCount == 1 ? "" : "s"} to back up',
      ),
      SyncPhase.idle => (Icons.cloud_done_outlined, _syncedLabel(snap)),
    };

    return IconButton(
      icon: Icon(icon, size: 20),
      tooltip: tooltip,
      onPressed: () => Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => const SettingsScreen())),
    );
  }
}

String _syncedLabel(SyncSnapshot snap) {
  final at = snap.lastSyncedAt;
  if (at == null) return 'Backed up';
  return 'Backed up ${DateFormat('d MMM, HH:mm').format(at.toLocal())}';
}
