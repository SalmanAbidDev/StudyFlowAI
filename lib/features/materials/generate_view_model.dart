// lib/features/materials/generate_view_model.dart
//
// "Generate flashcards" / "Generate quiz" — the one piece of state both
// buttons need, and the one place that knows what to invalidate afterwards.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/ai_repository.dart';
import '../../data/supabase_providers.dart';
import '../flashcards/flashcards_view_model.dart';
import '../quiz/quiz_view_model.dart';
import '../summaries/summaries_view_model.dart';
import 'materials_view_model.dart';
import 'study_progress.dart';

enum GenerateTarget { flashcards, quiz, summary }

/// Whether a generation is in flight, and what went wrong if it failed.
class GenerateState {
  const GenerateState({this.busy = false, this.error});

  final bool busy;
  final String? error;
}

class GenerateViewModel extends Notifier<GenerateState> {
  @override
  GenerateState build() => const GenerateState();

  /// Builds cards or questions for the currently selected material.
  ///
  /// Returns true on success. Failures are kept in state rather than thrown:
  /// this is called from a button, and a model that cannot find enough in a
  /// two-line note to make four cards is an ordinary outcome, not a crash.
  Future<bool> run(GenerateTarget target) async {
    if (state.busy) return false;

    final material = await ref.read(currentMaterialProvider.future);
    if (material == null) {
      state = const GenerateState(error: 'Pick a document first.');
      return false;
    }

    state = const GenerateState(busy: true);
    try {
      final ai = ref.read(aiRepositoryProvider);
      final userId = ref.read(currentUserIdProvider);

      if (target == GenerateTarget.summary) {
        await ai.generateSummary(userId: userId, materialId: material.id);
        ref.invalidate(summarySectionsProvider);
      } else if (target == GenerateTarget.flashcards) {
        await ai.generateDeck(
          userId: userId,
          materialId: material.id,
          title: material.title,
          subjectId: null,
        );
        ref.invalidate(deckProvider);
      } else {
        await ai.generateQuiz(
          userId: userId,
          materialId: material.id,
          title: material.title,
        );
        ref.invalidate(quizDataProvider);
        ref.invalidate(quizProvider);
      }

      // New practice means the material's progress denominator changed, and
      // everything downstream of it — exam preparation, the day's tasks.
      ref.invalidate(materialsProvider);
      ref.invalidate(studyProgressProvider);

      state = const GenerateState();
      return true;
    } on AiException catch (error) {
      state = GenerateState(error: error.message);
      return false;
    } catch (error) {
      state = GenerateState(error: 'Something went wrong. $error');
      return false;
    }
  }

  void clearError() => state = const GenerateState();
}

final generateProvider =
    NotifierProvider<GenerateViewModel, GenerateState>(GenerateViewModel.new);
