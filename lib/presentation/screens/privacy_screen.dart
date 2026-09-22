import 'package:flutter/material.dart';

import '../../core/theme/insets.dart';
import '../widgets/form_header.dart';
import '../widgets/settings/settings_widgets.dart';
import 'data_sent_screen.dart';
import 'privacy_notice_screen.dart';
import 'your_rights_screen.dart';

/// Privacy (mockup: "Your data and privacy controls") — the hub Settings
/// links to. Three real, already-built destinations: the Privacy Notice, the
/// Your Rights screen, and the Gemini transparency view.
class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  void _push(BuildContext context, Widget screen) => Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => screen));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: <Widget>[
            const FormHeader(
              title: 'Privacy',
              subtitle: 'Your data and privacy controls',
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
                  SettingsGroup(
                    rows: <Widget>[
                      SettingsRow(
                        icon: Icons.description_outlined,
                        title: 'Privacy Notice',
                        subtitle: 'What we collect, and why',
                        onTap: () =>
                            _push(context, const PrivacyNoticeScreen()),
                      ),
                      SettingsRow(
                        icon: Icons.verified_user_outlined,
                        title: 'Your Rights',
                        subtitle: "Access, correct, export or delete anytime",
                        onTap: () => _push(context, const YourRightsScreen()),
                      ),
                      SettingsRow(
                        icon: Icons.visibility_outlined,
                        title: "What's sent to Gemini",
                        subtitle: 'The exact data, built from your account',
                        onTap: () => _push(context, const DataSentScreen()),
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
