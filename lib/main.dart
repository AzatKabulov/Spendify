import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/local/hive_initializer.dart';
import 'presentation/providers/repository_providers.dart';

/// Entry point.
///
/// Phase 1: encrypted local storage is wired up (Hive + AES key from the
/// Keystore) and the default categories are seeded on first launch. There is
/// still no feature UI — that starts in Phase 2.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final HiveStore store = await bootstrapHive();

  final container = ProviderContainer(
    overrides: [hiveStoreProvider.overrideWithValue(store)],
  );
  // First-launch seed of the default category set (Phase 1 task 7).
  await container.read(categoryRepositoryProvider).ensureDefaultsSeeded();

  runApp(
    UncontrolledProviderScope(container: container, child: const SpendlyApp()),
  );
}

class SpendlyApp extends StatelessWidget {
  const SpendlyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Spendly',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2E7D32)),
        useMaterial3: true,
      ),
      home: const HomePlaceholderScreen(),
    );
  }
}

/// Temporary landing screen. Replaced by the real home screen in Phase 2.
class HomePlaceholderScreen extends StatelessWidget {
  const HomePlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Spendly')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(
              Icons.savings_outlined,
              size: 72,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text('Spendly', style: textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(
              'Encrypted storage ready — Phase 1',
              style: textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
