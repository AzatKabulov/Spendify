import 'badge.dart';

/// The fixed badge catalogue. Ids are permanent — `GamificationState.
/// unlockedBadgeIds` holds them. Unlock rules live in
/// `domain/services/badge_rules.dart` (Phase 8); every criterion is checkable
/// from `GamificationState` + the current event, and unlocks are permanent.
///
/// `iconCode` is a Material icon codepoint. It is stored as a bare `int` so this
/// file needs no Flutter import; the render side resolves it through the const
/// palette in `core/badge_icons.dart` (`badgeIconForCode`), which is what keeps
/// it tree-shake-safe. Every code here must match a palette entry.
const List<Badge> kBadgeCatalogue = <Badge>[
  Badge(
    id: 'first_transaction',
    name: 'First Steps',
    description: 'Logged your first transaction.',
    criteriaDescription: 'Record any transaction.',
    iconCode: 0xe28e, // Icons.flag
  ),
  Badge(
    id: 'transactions_10',
    name: 'Getting the Habit',
    description: 'Logged 10 transactions.',
    criteriaDescription: 'Log 10 transactions.',
    iconCode: 0xe50d, // Icons.receipt_long
  ),
  Badge(
    id: 'transactions_50',
    name: 'Bookkeeper',
    description: 'Logged 50 transactions.',
    criteriaDescription: 'Log 50 transactions.',
    iconCode: 0xe3dd, // Icons.menu_book
  ),
  Badge(
    id: 'transactions_100',
    name: 'Century',
    description: 'Logged 100 transactions.',
    criteriaDescription: 'Log 100 transactions.',
    iconCode: 0xe0bf, // Icons.auto_stories
  ),
  Badge(
    id: 'first_budget',
    name: 'Plan Ahead',
    description: 'Created your first spending limit.',
    criteriaDescription: 'Create a budget.',
    iconCode: 0xe553, // Icons.savings
  ),
  Badge(
    id: 'budget_kept',
    name: 'On Track',
    description: 'Finished a budget period without going over.',
    criteriaDescription: 'Complete a budget period within its limit.',
    iconCode: 0xe699, // Icons.verified
  ),
  Badge(
    id: 'streak_3',
    name: 'Warming Up',
    description: 'Logged spending 3 days in a row.',
    criteriaDescription: 'Reach a 3-day logging streak.',
    iconCode: 0xe392, // Icons.local_fire_department
  ),
  Badge(
    id: 'streak_7',
    name: 'Consistent',
    description: 'Logged spending 7 days in a row.',
    criteriaDescription: 'Reach a 7-day logging streak.',
    iconCode: 0xe392, // Icons.local_fire_department
  ),
  Badge(
    id: 'streak_30',
    name: 'Unbroken',
    description: 'Logged spending 30 days in a row.',
    criteriaDescription: 'Reach a 30-day logging streak.',
    iconCode: 0xe6e3, // Icons.whatshot
  ),
  Badge(
    id: 'first_scan',
    name: 'Snap It',
    description: 'Added a transaction from a receipt scan.',
    criteriaDescription: 'Scan a receipt.',
    iconCode: 0xe1f2, // Icons.document_scanner
  ),
  Badge(
    id: 'all_categories',
    name: 'Full Picture',
    description: 'Logged a transaction in every category.',
    criteriaDescription: 'Use every one of your categories at least once.',
    iconCode: 0xe1f9, // Icons.donut_large
  ),
  Badge(
    id: 'level_5',
    name: 'Levelling Up',
    description: 'Reached level 5.',
    criteriaDescription: 'Reach level 5.',
    iconCode: 0xe5f9, // Icons.star
  ),
  Badge(
    id: 'level_10',
    name: 'Seasoned',
    description: 'Reached level 10.',
    criteriaDescription: 'Reach level 10.',
    iconCode: 0xe3e7, // Icons.military_tech
  ),
];

Badge? badgeById(String id) {
  for (final badge in kBadgeCatalogue) {
    if (badge.id == id) return badge;
  }
  return null;
}
