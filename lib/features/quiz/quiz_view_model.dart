// lib/features/quiz/quiz_view_model.dart
//
// Picking an option reveals the answer immediately; "Next question" moves on.
// The finished run is written to quiz_attempts.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/quiz.dart';
import '../../data/supabase_providers.dart';

const _perQuestionSeconds = 42;

final quizDataProvider = FutureProvider.autoDispose<Quiz?>(
  (ref) => ref.watch(studyRepositoryProvider).firstQuiz(),
);

class QuizRun {
  const QuizRun({
    required this.quiz,
    this.index = 0,
    this.picked,
    this.revealed = false,
    this.correct = 0,
    this.missed = const [],
    this.remaining = _perQuestionSeconds,
    this.elapsed = 0,
  });

  final Quiz? quiz;
  final int index;
  final String? picked;
  final bool revealed;
  final int correct;
  final List<String> missed;
  final int remaining;
  final int elapsed;

  List<QuizQuestion> get questions => quiz?.questions ?? const [];
  bool get isEmpty => questions.isEmpty;
  QuizQuestion? get question => isEmpty ? null : questions[index];
  bool get isLastQuestion => index >= questions.length - 1;
  int get total => questions.length;

  String get clock {
    final m = remaining ~/ 60;
    final s = (remaining % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  /// `picked` is intentionally not just a nullable named argument: it has to
  /// be clearable, and an omitted-vs-null argument cannot express that.
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
      quiz: quiz,
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

class QuizController extends AsyncNotifier<QuizRun> {
  Timer? _ticker;

  @override
  Future<QuizRun> build() async {
    // The timer belongs to the provider, so it dies with the provider rather
    // than depending on a widget remembering to cancel it.
    ref.onDispose(() => _ticker?.cancel());
    final quiz = await ref.watch(quizDataProvider.future);
    if (quiz != null && quiz.questions.isNotEmpty) _startTimer();
    return QuizRun(quiz: quiz);
  }

  QuizRun? get _run => state.value;

  void _startTimer() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      final run = _run;
      if (run == null) return;
      state = AsyncData(
        run.copyWith(
          elapsed: run.elapsed + 1,
          remaining: run.remaining > 0 ? run.remaining - 1 : 0,
        ),
      );
    });
  }

  void pick(QuizOption option) {
    final run = _run;
    if (run == null || run.revealed) return;
    _ticker?.cancel();

    state = AsyncData(
      run.copyWith(
        picked: option.id,
        revealed: true,
        correct: option.correct ? run.correct + 1 : null,
        missed: option.correct
            ? null
            : [...run.missed, 'Q${run.index + 1} · ${run.question!.prompt}'],
      ),
    );
  }

  /// Advances, or returns false at the end of the deck — the screen's cue to
  /// navigate to the results.
  bool advance() {
    final run = _run;
    if (run == null || run.isLastQuestion) {
      _ticker?.cancel();
      return false;
    }
    state = AsyncData(
      run.copyWith(
        index: run.index + 1,
        clearPicked: true,
        revealed: false,
        remaining: _perQuestionSeconds,
      ),
    );
    _startTimer();
    return true;
  }

  /// Persists the finished run. Failures are swallowed on purpose: losing a
  /// score row must not block the user from seeing their result.
  Future<void> recordAttempt() async {
    final run = _run;
    if (run == null || run.isEmpty) return;
    try {
      await ref.read(studyRepositoryProvider).recordAttempt(
            userId: ref.read(currentUserIdProvider),
            quizId: run.quiz?.id,
            correct: run.correct,
            total: run.total,
            elapsedSeconds: run.elapsed,
            missed: run.missed,
          );
    } catch (_) {
      // Intentionally ignored — see above.
    }
  }
}

/// autoDispose so reopening the quiz starts a fresh run rather than resuming
/// the previous score.
final quizProvider =
    AsyncNotifierProvider.autoDispose<QuizController, QuizRun>(
  QuizController.new,
);
