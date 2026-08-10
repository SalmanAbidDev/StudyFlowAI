// lib/state/home_state.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Which of today's plan rows the user has ticked off.
///
/// Not autoDispose: Home lives in the shell's IndexedStack, so ticks have to
/// survive switching tabs — the same thing the old State object gave us.
class CompletedTasks extends Notifier<Set<int>> {
  @override
  Set<int> build() => const {0};

  void toggle(int index) {
    // A new Set each time rather than mutating in place. Riverpod compares the
    // old and new state by identity, so an in-place add would notify nobody.
    state = {
      for (final i in state)
        if (i != index) i,
      if (!state.contains(index)) index,
    };
  }
}

final completedTasksProvider =
    NotifierProvider<CompletedTasks, Set<int>>(CompletedTasks.new);
