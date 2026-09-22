import 'package:flutter/material.dart';

import '../../core/theme/insets.dart';
import '../widgets/form_header.dart';
import '../widgets/settings/settings_widgets.dart';

/// Notifications (mockup sub-screen). Spendify has **no push-notification
/// infrastructure** — no `flutter_local_notifications`, no
/// `firebase_messaging`, nothing scheduling a system notification. The
/// mockup's toggles (Budget Alerts, Goal Updates, Spending Summaries,
/// Achievement Updates, Product Updates, Marketing) would all be switches
/// that visibly flip but do nothing, which is worse than not having the
/// screen at all — so this says plainly what does happen instead.
class NotificationsInfoScreen extends StatelessWidget {
  const NotificationsInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(
        child: Column(
          children: <Widget>[
            FormHeader(
              title: 'Notifications',
              subtitle: 'Stay informed, on your terms',
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  Insets.md,
                  0,
                  Insets.md,
                  Insets.lg,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    SettingsInfoCard(
                      icon: Icons.notifications_off_outlined,
                      title: 'No push notifications yet',
                      body:
                          "This build of Spendify doesn't send anything to "
                          "your phone's notification tray — there's nothing "
                          'to turn on or off here.',
                    ),
                    SizedBox(height: Insets.md - 2),
                    SettingsInfoCard(
                      icon: Icons.dashboard_outlined,
                      title: 'What happens instead',
                      body:
                          'Budget warnings show live, right where they '
                          'matter: on the Home dashboard and the Budgets tab, '
                          'the moment a limit is approaching or exceeded — no '
                          'need for a separate alert.',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
