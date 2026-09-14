// Security review (Phase 12), P2: turns the CLAUDE.md §3 architecture rule
// ("`domain/` imports nothing from `data/`") from a review-discipline
// convention into something a failing test actually catches.
//
// `domain/` is meant to be plain Dart: entities, abstract repository
// interfaces, and pure logic services with no storage/network/UI framework
// underneath them (CLAUDE.md §3/§5). A violation here is a maintainability
// regression waiting to happen, not just a style nit — it's exactly what
// makes "swap the storage layer without touching gamification logic" true.
//
// This scans source, not compiled output, so it catches the mistake at the
// same place a reviewer would, before it ever reaches `flutter analyze`.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Packages `domain/` has no legitimate reason to depend on — each one is a
/// framework/infrastructure concern that belongs in `data/` or
/// `presentation/` instead.
const _forbiddenPackages = <String>[
  'flutter',
  'flutter_riverpod',
  'hive',
  'hive_flutter',
  'firebase_core',
  'firebase_auth',
  'cloud_firestore',
  'http',
  'image_picker',
  'flutter_image_compress',
  'flutter_secure_storage',
  'connectivity_plus',
  'path_provider',
];

final _importPattern = RegExp(
  r'''^\s*import\s+['"]([^'"]+)['"]''',
  multiLine: true,
);

void main() {
  test('domain/ imports nothing from data/ or any infrastructure package', () {
    final domainDir = Directory('lib/domain');
    expect(
      domainDir.existsSync(),
      isTrue,
      reason: 'expected to run from the repo root (lib/domain missing)',
    );

    final violations = <String>[];

    for (final entity in domainDir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final relativePath = entity.path.replaceAll('\\', '/');
      final content = entity.readAsStringSync();

      for (final match in _importPattern.allMatches(content)) {
        final target = match.group(1)!;

        final isDataImport =
            target.contains('data/') || target.startsWith('package:spendly/data/');
        final isForbiddenPackage = _forbiddenPackages.any(
          (pkg) => target == 'package:$pkg' || target.startsWith('package:$pkg/'),
        );

        if (isDataImport || isForbiddenPackage) {
          violations.add('$relativePath imports "$target"');
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason:
          'domain/ must stay framework- and data-layer-free (CLAUDE.md §3). '
          'Move this logic to data/ or presentation/, or invert the '
          'dependency behind a domain/repositories interface:\n'
          '${violations.join('\n')}',
    );
  });
}
