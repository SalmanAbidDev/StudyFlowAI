// lib/data/models/profile.dart

class Profile {
  const Profile({
    required this.id,
    required this.fullName,
    required this.streakDays,
    required this.isPro,
    this.avatarUrl,
  });

  factory Profile.fromRow(Map<String, dynamic> row) => Profile(
        id: row['id'] as String,
        fullName: (row['full_name'] as String?) ?? '',
        streakDays: (row['streak_days'] as int?) ?? 0,
        isPro: (row['is_pro'] as bool?) ?? false,
        avatarUrl: row['avatar_url'] as String?,
      );

  final String id;
  final String fullName;
  final int streakDays;
  final bool isPro;
  final String? avatarUrl;

  String get displayName => fullName.trim().isEmpty ? 'Student' : fullName;

  /// "AM" from "Alex Morgan"; falls back to a single letter, then to a dash so
  /// the avatar is never blank.
  String get initials {
    final parts = displayName
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '–';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  /// The greeting uses the first name only.
  String get firstName => displayName.split(RegExp(r'\s+')).first;
}

class Achievement {
  const Achievement({
    required this.code,
    required this.name,
    required this.detail,
    required this.earned,
  });

  factory Achievement.fromRow(Map<String, dynamic> row) => Achievement(
        code: row['code'] as String,
        name: row['name'] as String,
        detail: (row['detail'] as String?) ?? '',
        earned: row['earned_at'] != null,
      );

  final String code;
  final String name;
  final String detail;
  final bool earned;
}
