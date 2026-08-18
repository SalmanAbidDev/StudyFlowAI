// lib/data/models/subject.dart

import 'package:flutter/material.dart';

import '../../core/theme/theme.dart';

/// Which accent a subject is painted with. Resolved against the theme so the
/// same subject reads correctly in light and dark.
enum SubjectAccent { indigo, emerald, violet, coral, amber }

extension SubjectAccentColor on SubjectAccent {
  Color color(BuildContext context) {
    final sf = context.sf;
    return switch (this) {
      SubjectAccent.indigo => context.scheme.primary,
      SubjectAccent.emerald => sf.emerald,
      SubjectAccent.violet => sf.violet,
      SubjectAccent.coral => sf.coral,
      SubjectAccent.amber => sf.amber,
    };
  }

  String get wireName => name;

  /// Unknown values fall back rather than throwing: a row written by a newer
  /// build of the app should not crash an older one.
  static SubjectAccent parse(String? value) => SubjectAccent.values
      .firstWhere((a) => a.name == value, orElse: () => SubjectAccent.indigo);
}

/// The database stores a stable key; the icon set lives here so it can change
/// without a data migration.
IconData iconForKey(String? key) => switch (key) {
      'science' => Icons.science_outlined,
      'chart' => Icons.show_chart_rounded,
      'document' => Icons.description_outlined,
      'calculate' => Icons.calculate_outlined,
      'code' => Icons.terminal_rounded,
      'globe' => Icons.public_rounded,
      'brain' => Icons.psychology_outlined,
      _ => Icons.menu_book_outlined,
    };

class Subject {
  const Subject({
    required this.id,
    required this.name,
    required this.accent,
    required this.iconKey,
  });

  factory Subject.fromRow(Map<String, dynamic> row) => Subject(
        id: row['id'] as String,
        name: row['name'] as String,
        accent: SubjectAccentColor.parse(row['accent'] as String?),
        iconKey: (row['icon'] as String?) ?? 'book',
      );

  final String id;
  final String name;
  final SubjectAccent accent;
  final String iconKey;

  IconData get icon => iconForKey(iconKey);
}

/// A category offered on the filing screen before the user has any of their
/// own. Nothing is written until one is picked — these are suggestions, not
/// seeded rows (the §5.2 pattern: catalogue in the app, data in the database).
class CategorySuggestion {
  const CategorySuggestion(this.name, this.accent, this.iconKey);

  final String name;
  final SubjectAccent accent;
  final String iconKey;

  IconData get icon => iconForKey(iconKey);
}

/// Deliberately broad and short. A long list is a menu to read rather than a
/// choice to make, and anything missing is one tap away in the custom field.
const categorySuggestions = <CategorySuggestion>[
  CategorySuggestion('Mathematics', SubjectAccent.indigo, 'calculate'),
  CategorySuggestion('Physics', SubjectAccent.violet, 'science'),
  CategorySuggestion('Chemistry', SubjectAccent.emerald, 'science'),
  CategorySuggestion('Biology', SubjectAccent.coral, 'science'),
  CategorySuggestion('Computer Science', SubjectAccent.indigo, 'code'),
  CategorySuggestion('Economics', SubjectAccent.amber, 'chart'),
  CategorySuggestion('History', SubjectAccent.coral, 'globe'),
  CategorySuggestion('Psychology', SubjectAccent.violet, 'brain'),
  CategorySuggestion('Literature', SubjectAccent.emerald, 'book'),
];
