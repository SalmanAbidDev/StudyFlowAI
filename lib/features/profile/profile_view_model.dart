// lib/features/profile/profile_view_model.dart
//
// The three numbers above the Profile settings list. All three used to be
// string literals — "12d", "124h", "342" — shown to every account regardless
// of what it had done.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/preferences.dart';
import '../../data/supabase_providers.dart';
import '../auth/auth_view_model.dart';

/// Whether daily reminders are on. Stored locally, like the theme: there is
/// nothing to schedule them with yet (§9), so this is the user's stated
/// preference rather than a description of anything happening.
class NotificationsViewModel extends Notifier<bool> {
  static const storageKey = 'notifications_enabled';

  @override
  bool build() =>
      ref.read(preferencesProvider).getString(storageKey) != 'false';

  Future<void> set(bool enabled) async {
    // Flip first, persist second — the switch must not wait on a disk write.
    state = enabled;
    await ref
        .read(preferencesProvider)
        .setString(storageKey, enabled ? 'true' : 'false');
  }
}

final notificationsProvider =
    NotifierProvider<NotificationsViewModel, bool>(NotificationsViewModel.new);

/// The signed-in address. Read from the session rather than the profile row —
/// it is the auth identity, and `profiles` does not carry it.
final accountEmailProvider = Provider<String?>(
  (ref) => ref.watch(authRepositoryProvider).currentUser?.email,
);

class PasswordChangeState {
  const PasswordChangeState({this.saving = false, this.error, this.done = false});

  final bool saving;
  final String? error;
  final bool done;
}

/// Changing the password in place. Supabase re-authenticates the session on
/// success, so the user is not signed out.
class PasswordChangeViewModel extends Notifier<PasswordChangeState> {
  /// Supabase's own floor. Checking it here means the user is told before the
  /// round trip rather than by a raw AuthException after it.
  static const minLength = 6;

  @override
  PasswordChangeState build() => const PasswordChangeState();

  Future<bool> submit({
    required String password,
    required String confirmation,
  }) async {
    if (state.saving) return false;

    if (password.length < minLength) {
      state = PasswordChangeState(
        error: 'Use at least $minLength characters.',
      );
      return false;
    }
    if (password != confirmation) {
      state = const PasswordChangeState(error: 'The two do not match.');
      return false;
    }

    state = const PasswordChangeState(saving: true);
    try {
      await ref.read(authRepositoryProvider).updatePassword(password);
      state = const PasswordChangeState(done: true);
      return true;
    } catch (error) {
      state = PasswordChangeState(
        // Supabase says "New password should be different from the old
        // password" and similar, which are worth passing through verbatim.
        error: switch (error) {
          final Object e when e.toString().contains('should be different') =>
            'That is already your password.',
          _ => "Couldn't change it. Check your connection and try again.",
        },
      );
      return false;
    }
  }
}

final passwordChangeProvider =
    NotifierProvider.autoDispose<PasswordChangeViewModel, PasswordChangeState>(
  PasswordChangeViewModel.new,
);

class ProfileStats {
  const ProfileStats({
    required this.streakDays,
    required this.studiedMinutes,
    required this.cardsMastered,
  });

  final int streakDays;
  final int studiedMinutes;
  final int cardsMastered;

  String get streakLabel => '${streakDays}d';

  /// "124h" once there is an hour to show, "45m" below that. Rounding 45
  /// minutes down to "0h" would read as having done nothing.
  String get studiedLabel {
    if (studiedMinutes <= 0) return '0h';
    if (studiedMinutes < 60) return '${studiedMinutes}m';
    return '${studiedMinutes ~/ 60}h';
  }

  String get masteredLabel => '$cardsMastered';
}

/// Consecutive days, counting back from today, on which at least one study
/// block was ticked off.
///
/// Today not being done yet does **not** break the streak — the day is still
/// running. It starts from yesterday in that case, which is how every app that
/// counts streaks behaves and the only version that is not infuriating at
/// breakfast.
int streakFrom(Set<DateTime> days, DateTime today) {
  if (days.isEmpty) return 0;

  var cursor = days.contains(today)
      ? today
      : today.subtract(const Duration(days: 1));
  if (!days.contains(cursor)) return 0;

  var streak = 0;
  while (days.contains(cursor)) {
    streak++;
    cursor = cursor.subtract(const Duration(days: 1));
  }
  return streak;
}

/// Derived from rows the app actually writes.
///
/// **Not** from `profiles.streak_days`, and **not** from `study_sessions`.
/// Both columns exist; nothing maintains either (§9), so reading them would
/// have replaced three hard-coded numbers with three stuck ones. Completed
/// study blocks are real: `setBlockDone` writes them every time a task is
/// ticked. Mastered cards come from `flashcards.interval_days`, which
/// `reviewCard` writes.
final profileStatsProvider = FutureProvider<ProfileStats>((ref) async {
  final blocks = await ref.watch(plannerRepositoryProvider).completedBlocks();

  var minutes = 0;
  final days = <DateTime>{};
  for (final block in blocks) {
    minutes += block.minutes;
    days.add(block.day);
  }

  final mastered =
      await ref.watch(analyticsRepositoryProvider).masteredCount();

  final now = DateTime.now();
  return ProfileStats(
    streakDays: streakFrom(days, DateTime(now.year, now.month, now.day)),
    studiedMinutes: minutes,
    cardsMastered: mastered,
  );
});
