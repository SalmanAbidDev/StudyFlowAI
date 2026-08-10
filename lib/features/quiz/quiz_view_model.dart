// lib/state/quiz_state.dart
//
// Picking an option reveals the answer immediately; "Next question" moves on.
// Scoring is tallied here and handed to the result screen.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/demo_content.dart';

const _perQuestionSeconds = 42;

class QuizRun {
  const QuizRun({
    this.index = 0,
    this.picked,
    this.revealed = false,
    this.correct = 0,
    this.missed = const [],
    this.remaining = _perQuestionSeconds,
    this.elapsed = 0,
  });

  final int index;
  final String? picked;
  final bool revealed;
  final int correct;
  final List<String> missed;
  final int remaining;
  final int elapsed;

  QuizQuestion get question => demoQuiz[index];
  bool get isLastQuestion => index == demoQuiz.length - 1;

  String get clock {
    final m = remaining ~/ 60;
    final s = (remaining % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  /// `picked` is intentionally not in the named arguments: it has to be
  /// clearable, and an omitted-vs-null argument cannot express that. The
  /// callers that need to clear it pass `clearPicked: true`.
  QuizRun copyWith({
    int? index,
    String? picked,
    bool clearPicked = false,
    bool? revealed,
    int? correct,
    List<String>? missed,
    int? remaining,
    int? elapsed,
  }) {
    return QuizRun(
      index: index ?? this.index,
      picked: clearPicked ? null : (picked ?? this.picked),
      revealed: revealed ?? this.revealed,
      correct: correct ?? this.correct,
      missed: missed ?? this.missed,
      remaining: remaining ?? this.remaining,
      elapsed: elapsed ?? this.elapsed,
    );
  }
}

class QuizController extends Notifier<QuizRun> {
  Timer? _ticker;

  @override
  QuizRun build() {
    // The timer is owned by the provider, so it is cancelled when the provider
    // goes away rather than depending on a widget remembering to dispose it.
    ref.onDispose(() => _ticker?.cancel());
    _startTimer();
    return const QuizRun();
  }

  void _startTimer() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      state = state.copyWith(
        elapsed: state.elapsed + 1,
        remaining: state.remaining > 0 ? state.remaining - 1 : 0,
      );
    });
  }

  void pick(QuizOption option) {
    if (state.revealed) return;
    _ticker?.cancel();
    state = state.copyWith(
      picked: option.id,
      revealed: true,
      correct: option.correct ? state.correct + 1 : null,
      missed: option.correct
          ? null
          : [...state.missed, 'Q${state.index + 1} · ${state.question.prompt}'],
    );
  }

  /// Moves to the next question. Returns false at the end of the deck, which
  /// is the screen's cue to navigate to the results.
  bool advance() {
    if (state.isLastQuestion) {
      _ticker?.cancel();
      return false;
    }
    state = state.copyWith(
      index: state.index + 1,
      clearPicked: true,
      revealed: false,
      remaining: _perQuestionSeconds,
    );
    _startTimer();
    return true;
  }
}

/// autoDispose so reopening the quiz starts a fresh run rather than resuming
/// the previous score — which is what the old per-route State object did.
final quizProvider =
    NotifierProvider.autoDispose<QuizController, QuizRun>(QuizController.new);
