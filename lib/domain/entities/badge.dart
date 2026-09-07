/// A gamification badge definition. Static catalogue — **not synced, not a
/// Hive type** (CLAUDE.md §4). What a user has unlocked is
/// `GamificationState.unlockedBadgeIds`; this class is just the metadata for
/// rendering and for the unlock rules.
class Badge {
  const Badge({
    required this.id,
    required this.name,
    required this.description,
    required this.criteriaDescription,
    required this.iconCode,
  });

  final String id;
  final String name;
  final String description;

  /// Human-readable unlock condition, shown in the badges screen.
  final String criteriaDescription;
  final int iconCode;

  @override
  bool operator ==(Object other) => other is Badge && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Badge($id, "$name")';
}
