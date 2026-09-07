import 'badge.dart';

/// The fixed set of badges. Unlock rules that reference these ids are built in
/// Phase 8 (`GamificationEngine`); Phase 1 only fixes the ids so
/// `GamificationState.unlockedBadgeIds` has stable values to hold.
///
/// Icon codes are Material `IconData.codePoint` values (const, tree-shake-safe).
const List<Badge> kBadgeCatalogue = <Badge>[
  Badge(
    id: 'first_transaction',
    name: 'First Steps',
    description: 'Logged your first transaction.',
    criteriaDescription: 'Record any transaction.',
    iconCode: 0xe5ca, // Icons.check
  ),
  Badge(
    id: 'week_within_budget',
    name: 'On Track',
    description: 'Stayed within every limit for a full week.',
    criteriaDescription: 'Finish a week without exceeding any budget.',
    iconCode: 0xe8e5, // Icons.trending_up
  ),
  Badge(
    id: 'streak_7',
    name: 'Consistent',
    description: 'Logged spending 7 days in a row.',
    criteriaDescription: 'Reach a 7-day logging streak.',
    iconCode: 0xe80e, // Icons.local_fire_department (approx)
  ),
];

Badge? badgeById(String id) {
  for (final badge in kBadgeCatalogue) {
    if (badge.id == id) return badge;
  }
  return null;
}
