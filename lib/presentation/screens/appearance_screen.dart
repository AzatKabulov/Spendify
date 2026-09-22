import 'package:flutter/material.dart';

import '../../core/theme/insets.dart';
import '../widgets/form_header.dart';
import '../widgets/settings/settings_widgets.dart';

/// Appearance (mockup sub-screen: "Theme, language, display").
///
/// Both real decisions here are already made and recorded in CLAUDE.md §9:
/// dark mode is locked to light only (`AppTheme.light()` is the only
/// `ThemeData` given to `MaterialApp`), and there is no localisation
/// infrastructure, so English is the only language. Showing a dark-mode
/// switch that always snaps back to "on" or a language picker with one
/// option would be worse than just saying so.
class AppearanceScreen extends StatelessWidget {
  const AppearanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: <Widget>[
            const FormHeader(
              title: 'Appearance',
              subtitle: 'Theme, language and display',
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
                  const SettingsGroup(
                    rows: <Widget>[
                      SettingsRow(
                        icon: Icons.light_mode_outlined,
                        title: 'Theme',
                        subtitle: 'Light — dark mode is not built yet',
                      ),
                      SettingsRow(
                        icon: Icons.translate_outlined,
                        title: 'Language',
                        subtitle: 'English only, in this build',
                      ),
                    ],
                  ),
                  const SizedBox(height: Insets.md - 2),
                  const SettingsInfoCard(
                    icon: Icons.info_outline,
                    title: 'Why there are no options here',
                    body:
                        "A proper dark palette and translations weren't "
                        "genuinely finishable within this capstone's scope, "
                        'so they were left as future work rather than shipped '
                        'half-done.',
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
