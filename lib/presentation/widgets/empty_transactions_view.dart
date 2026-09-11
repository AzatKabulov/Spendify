import 'package:flutter/material.dart';

import 'centered_message.dart';

/// Shown on the home screen before the first transaction exists.
class EmptyTransactionsView extends StatelessWidget {
  const EmptyTransactionsView({super.key});

  @override
  Widget build(BuildContext context) {
    return const CenteredMessage(
      icon: Icons.receipt_long_outlined,
      title: 'No transactions yet',
      message: 'Tap the + button to record your first income or expense.',
    );
  }
}
