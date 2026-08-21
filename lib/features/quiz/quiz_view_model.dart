// lib/features/quiz/quiz_view_model.dart
//
// Picking an option reveals the answer immediately; "Next question" moves on,
// and "Previous" goes back to look at one you have already answered. The
// finished run is written to quiz_attempts.
//
// **Answers are stored per question, not accumulated.** The score used to be a
// running total incremented on each pick — which was fine while the only way
// through was forwards, and would have counted a question twice the moment a
// Previous button existed.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/quiz.dart';
import '../../data/supabase_providers.dart';
import '../home/home_view_model.dart';
import '../materials/materials_view_model.dart';
import '../materials/study_progress.dart';

/// The quiz for whichever document is selected — see the note on
/// `deckProvider`, which works the same way.
final quizDataProvider = FutureProvider.autoDispose<Quiz?>((ref) {
  final repo = ref.watch(studyRepositoryProvider);
  final materialId = ref.watch(selectedMaterialProvider);
  return materialId == null
      ? repo.firstQuiz()
      : repo.quizForMaterial(materialId);
});

class QuizRun {
  const QuizRun({
    required this.quiz,
    this.index = 0,
    this.answers = const {},
    this.elapsed = 0,
  });

  final Quiz? quiz;
  final int index;

  /// Question index → the option picked for it. The single source of truth for
  /// the score, so going back and forward cannot change it.
  final Map<int, String> answers;

  final int elapsed;

  List<QuizQuestion> get questions => quiz?.questions ?? const [];
  bool get isEmpty => questions.isEmpty;
  QuizQuestion? get question => isEmpty ? null : questions[index];
  bool get isLastQuestion => index >= questions.length - 1;
  bool get isFirstQuestion => index == 0;
  int get total => questions.length;

  /// What was picked for the question on screen, and whether that means the
  /// answer is showing. Derived, so they can never disagree with [answers].
  String? get picked => answers[index];
  bool get revealed => answers.containsKey(index);

  /// Every question must be answered before moving on — "Next" used to advance
  /// past a question nobody had looked at.
  bool get canAdvance => revealed;

  int get correct {
    var count = 0;
    for (final entry in answers.entries) {
      final options = questions[entry.key].options;
      if (options.any((o) => o.id == entry.value && o.correct)) count++;
    }
    return count;
  }

  List<String> get missed => [
        for (final entry in answers.entries)
          if (!questions[entry.key].options
              .any((o) => o.id == entry.value && o.correct))
            'Q${entry.key + 1} · ${questions[entry.key].prompt}',
      ];

  QuizRun copyWith({
    int? index,
    Map<int, String>? answers,
    int? elapsed,
  }) {
    return QuizRun(
      quiz: quiz,
      index: index ?? this.index,
      answers: answers ?? this.answers,
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

  /// Counts how long the run took, for the results screen. There is no
  /// per-question countdown any more — a clock ticking down in the header
  /// rushed a revision exercise for no reason.
  void _startTimer() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      final run = _run;
      if (run == null) return;
      state = AsyncData(run.copyWith(elapsed: run.elapsed + 1));
    });
  }

  void pick(QuizOption option) {
    final run = _run;
    // Already answered: the choice stands. Letting it be changed after the
    // answer is revealed would make the score a measure of persistence.
    if (run == null || run.revealed) return;
    state = AsyncData(
      run.copyWith(answers: {...run.answers, run.index: option.id}),
    );
  }

  /// Advances, or returns false at the end of the deck — the screen's cue to
  /// navigate to the results.
  bool advance() {
    final run = _run;
    if (run == null || !run.canAdvance) return true;
    if (run.isLastQuestion) {
      _ticker?.cancel();
      return false;
    }
    state = AsyncData(run.copyWith(index: run.index + 1));
    return true;
  }

  /// Back one question, to look at something already answered.
  void back() {
    final run = _run;
    if (run == null || run.isFirstQuestion) return;
    state = AsyncData(run.copyWith(index: run.index - 1));
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

      // Flow's suggestion reads the latest attempt first, so a finished quiz
      // changes what it should say. Without this it kept recommending the
      // review you had just done.
      ref.invalidate(flowSuggestionProvider);

      // A recorded attempt is what makes the quiz half of a material's
      // progress count — and can be the thing that ticks off today's task.
      final materialId = ref.read(selectedMaterialProvider);
      if (materialId != null) {
        await ref.read(syncStudyProgressProvider)(materialId);
      }
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
