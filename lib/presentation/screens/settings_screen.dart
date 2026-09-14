import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import '../../domain/entities/ai_consent.dart';
import '../../domain/entities/sync_snapshot.dart';
import '../providers/ai_providers.dart';
import '../providers/auth_providers.dart';
import '../providers/privacy_providers.dart';
import '../providers/repository_providers.dart';
import '../providers/sync_providers.dart';
import 'data_sent_screen.dart';
import 'privacy_notice_screen.dart';

/// Settings — the account section (Phase 5), backup/sync (Phase 6), report-data
/// rebuild (Phase 4), and the Phase 10 privacy & AI surfaces: the AI on/off
/// toggle, the transparency views, clear cached advice, export data, and
/// delete-all-local-data.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _rebuilding = false;
  bool _signingOut = false;
  bool _syncing = false;
  bool _clearingAdvice = false;
  bool _exporting = false;
  bool _wiping = false;

  void _open(Widget screen) => Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => screen));

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

  Future<void> _setAi(bool on) async {
    final notifier = ref.read(aiConsentProvider.notifier);
    if (on) {
      await notifier.grant();
    } else {
      await notifier.revoke();
    }
  }

  Future<void> _clearAdvice() async {
    final ok = await _confirm(
      title: 'Clear cached advice?',
      message:
          'The last set of AI suggestions is removed. New advice is generated '
          'next time you open Insights.',
      confirmLabel: 'Clear',
    );
    if (ok != true || !mounted) return;
    setState(() => _clearingAdvice = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(adviceRecordRepositoryProvider).clear();
      messenger.showSnackBar(
        const SnackBar(content: Text('Cached advice cleared')),
      );
    } finally {
      if (mounted) setState(() => _clearingAdvice = false);
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
    final ok = await _confirm(
      title: 'Delete all local data?',
      message:
          'This permanently erases every transaction, budget, category and '
          'reward on this device, and signs you out.\n\n'
          'Your cloud backup is NOT deleted — sign in again to restore it, or '
          'create a new account to start fresh.',
      confirmLabel: 'Delete everything',
      destructive: true,
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

  Future<void> _signOut() async {
    final ok = await _confirm(
      title: 'Sign out?',
      message: 'Your data stays on this device. You can sign back in any time.',
      confirmLabel: 'Sign out',
    );
    if (ok != true) return;

    setState(() => _signingOut = true);
    await ref.read(signOutProvider)();
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<bool?> _confirm({
    required String title,
    required String message,
    required String confirmLabel,
    bool destructive = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: destructive
                ? FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                  )
                : null,
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final email = ref.watch(currentUserEmailProvider);
    final syncAvailable = ref.watch(syncAvailableProvider);
    final syncSnap =
        ref.watch(syncSnapshotProvider).value ?? const SyncSnapshot();
    final aiKeyPresent = ref.watch(aiKeyPresentProvider);
    final aiOn = ref.watch(aiConsentProvider) == AiConsent.granted;

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
            leading: Icon(Icons.logout, color: theme.colorScheme.error),
            title: Text(
              'Sign out',
              style: TextStyle(color: theme.colorScheme.error),
            ),
            trailing: _spinnerIf(_signingOut),
            onTap: _signingOut ? null : _signOut,
          ),

          const Divider(),
          const _SectionHeader('Privacy & AI'),
          if (aiKeyPresent)
            SwitchListTile(
              secondary: const Icon(Icons.auto_awesome_outlined),
              title: const Text('AI features'),
              subtitle: Text(
                aiOn
                    ? 'Receipt scanning and spending advice are on. They send '
                          'data to Google Gemini.'
                    : 'Off. Receipt scanning and advice are hidden; nothing is '
                          'sent to Google Gemini.',
              ),
              value: aiOn,
              onChanged: _setAi,
            )
          else
            const ListTile(
              leading: Icon(Icons.auto_awesome_outlined),
              title: Text('AI features'),
              subtitle: Text(
                'Not available in this build (no Gemini API key). Everything '
                'else works.',
              ),
              enabled: false,
            ),
          ListTile(
            leading: const Icon(Icons.visibility_outlined),
            title: const Text('What’s sent to Gemini'),
            subtitle: const Text('See the exact data, built from your account'),
            onTap: () => _open(const DataSentScreen()),
          ),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('Privacy notice'),
            onTap: () => _open(const PrivacyNoticeScreen()),
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
              trailing: _spinnerIf(_syncing || syncSnap.isSyncing),
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
            trailing: _spinnerIf(_rebuilding),
            onTap: _rebuilding ? null : _rebuildAggregates,
          ),
          ListTile(
            leading: const Icon(Icons.psychology_alt_outlined),
            title: const Text('Clear cached advice'),
            trailing: _spinnerIf(_clearingAdvice),
            onTap: _clearingAdvice ? null : _clearAdvice,
          ),
          ListTile(
            leading: const Icon(Icons.download_outlined),
            title: const Text('Export my data'),
            subtitle: const Text(
              'A complete JSON copy of everything you added',
            ),
            trailing: _spinnerIf(_exporting),
            onTap: _exporting ? null : _exportData,
          ),
          ListTile(
            leading: Icon(
              Icons.delete_forever_outlined,
              color: theme.colorScheme.error,
            ),
            title: Text(
              'Delete all local data',
              style: TextStyle(color: theme.colorScheme.error),
            ),
            subtitle: const Text('Cloud backup is not affected'),
            trailing: _spinnerIf(_wiping),
            onTap: _wiping ? null : _deleteAllData,
          ),
        ],
      ),
    );
  }

  Widget? _spinnerIf(bool busy) => busy
      ? const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        )
      : null;
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
