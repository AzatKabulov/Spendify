import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/insets.dart';
import '../../domain/repositories/auth_repository.dart';
import '../providers/auth_providers.dart';
import '../providers/gamification_providers.dart';
import '../widgets/form_header.dart';
import '../widgets/home/home_sections.dart';
import '../widgets/settings/settings_widgets.dart';

/// Account — profile + security (mockup's "Account" sub-screen).
///
/// **What's real, and what isn't (flagged).** The mockup shows "Change
/// Photo", biometric unlock, two-factor authentication and Google/Apple
/// "Connected Accounts". None of that exists: auth is Firebase email/password
/// only (CLAUDE.md §2), there is no profile-photo upload, and no
/// biometric/2FA library is wired in. Rather than draw controls that would do
/// nothing, this screen shows only what the app actually does — name and
/// email (read-only; there is no edit-profile flow yet), and a real
/// "Change password" action — and says plainly, once, that there's nothing
/// else here yet.
class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key});

  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
  bool _sendingReset = false;

  Future<void> _changePassword() async {
    final email = ref.read(currentUserEmailProvider);
    if (email == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change password?'),
        content: Text(
          "We'll send a password reset link to $email. Follow it to choose "
          'a new password.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Send link'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _sendingReset = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(authRepositoryProvider).sendPasswordReset(email: email);
      messenger.showSnackBar(
        SnackBar(content: Text('Reset link sent to $email')),
      );
    } on AuthException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _sendingReset = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final email = ref.watch(currentUserEmailProvider);
    final name = ref.watch(currentUserFirstNameProvider);
    final level = ref.watch(gamificationStateProvider).value?.level;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: <Widget>[
            const FormHeader(
              title: 'Account',
              subtitle: 'Profile and security',
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
                  HomeCard(
                    child: Row(
                      children: <Widget>[
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: scheme.primaryContainer,
                          child: Text(
                            name.isEmpty ? '?' : name[0].toUpperCase(),
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: scheme.onPrimaryContainer,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: Insets.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                name,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                email ?? 'Signed in',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                              if (level != null)
                                Text(
                                  'Level $level',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: scheme.primary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: Insets.md),
                  SettingsGroup(
                    label: 'Security',
                    rows: <Widget>[
                      SettingsRow(
                        icon: Icons.lock_outline,
                        title: 'Change password',
                        subtitle: 'Sends a reset link to your email',
                        enabled: !_sendingReset,
                        onTap: _changePassword,
                        trailing: _sendingReset
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
                  const SizedBox(height: Insets.sm),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Insets.xs),
                    child: Text(
                      'Spendify uses email and password only in this build — '
                      'no biometric unlock, two-factor authentication or '
                      'Google/Apple sign-in yet.',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
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
