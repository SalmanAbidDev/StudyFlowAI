// lib/data/models/achievement.dart
//
// *What badges exist* is app knowledge; the database only records which ones a
// user has earned and when.
//
// They used to be seeded as four rows per account, which meant every user
// carried a copy of the same catalogue, adding a badge needed a backfill, and
// deleting the rows made the whole feature disappear from the UI rather than
// showing an unearned set.

import 'package:flutter/material.dart';

@immutable
class AchievementDef {
  const AchievementDef({
    required this.code,
    required this.name,
    required this.detail,
    required this.icon,
    required this.accent,
  });

  /// Stable identifier stored in `achievements.code`.
  final String code;
  final String name;

  /// The bar to clear, e.g. "10 days".
  final String detail;
  final IconData icon;

  /// Index into the accent list the UI resolves against the theme.
  final int accent;
}

const achievementCatalogue = <AchievementDef>[
  AchievementDef(
    code: 'hot_streak',
    name: 'Hot streak',
    detail: '10 days running',
    icon: Icons.local_fire_department_rounded,
    accent: 0,
  ),
  AchievementDef(
    code: 'quiz_ace',
    name: 'Quiz ace',
    detail: 'Score 90%+',
    icon: Icons.emoji_events_outlined,
    accent: 1,
  ),
  AchievementDef(
    code: 'card_master',
    name: 'Card master',
    detail: 'Master 500 cards',
    icon: Icons.style_outlined,
    accent: 2,
  ),
  AchievementDef(
    code: 'deep_focus',
    name: 'Deep focus',
    detail: 'One 4h block',
    icon: Icons.my_location_rounded,
    accent: 3,
  ),
  AchievementDef(
    code: 'first_upload',
    name: 'First upload',
    detail: 'Add a document',
    icon: Icons.file_upload_outlined,
    accent: 0,
  ),
  AchievementDef(
    code: 'night_owl',
    name: 'Night owl',
    detail: 'Study after midnight',
    icon: Icons.bedtime_outlined,
    accent: 2,
  ),
];

/// A catalogue entry paired with this user's progress against it.
@immutable
class Achievement {
  const Achievement({required this.def, this.earnedAt});

  final AchievementDef def;
  final DateTime? earnedAt;

  bool get earned => earnedAt != null;

  String get code => def.code;
  String get name => def.name;
  String get detail => def.detail;
  IconData get icon => def.icon;
  int get accent => def.accent;
}
