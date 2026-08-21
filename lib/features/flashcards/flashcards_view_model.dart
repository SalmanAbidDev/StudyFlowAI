// lib/features/flashcards/flashcards_view_model.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/view_models.dart';
import '../../data/models/flashcard.dart';
import '../../data/supabase_providers.dart';
import '../materials/materials_view_model.dart';
import '../materials/study_progress.dart';

/// The deck for whichever document is selected — set by the picker when
/// Flashcards is opened from Home, and already set when it is opened from a
/// document. Falls back to the newest deck when there is no selection at all.
final deckProvider = FutureProvider.autoDispose<Deck?>((ref) {
  final repo = ref.watch(studyRepositoryProvider);
  final materialId = ref.watch(selectedMaterialProvider);
  return materialId == null
      ? repo.firstDeck()
      : repo.deckForMaterial(materialId);
});

/// Records a review and moves everything that depends on it.
///
/// The two buttons under a card used to be pure navigation — "Again" stepped
/// back, "Got it" stepped forward, and nothing was written down. Which meant
/// the scheduling in `reviewCard` never ran, `flashcards.interval_days` stayed
/// zero, and "342 mastered" on the profile could never become true.
final reviewCardProvider =
    Provider<Future<void> Function(Flashcard, {required bool remembered})>(
        (ref) {
  return (card, {required bool remembered}) async {
    await ref.read(studyRepositoryProvider).reviewCard(
          card,
          remembered: remembered,
          ease: card.ease,
          intervalDays: card.intervalDays,
        );

    final materialId = ref.read(selectedMaterialProvider);
    ref.invalidate(deckProvider);
    if (materialId != null) {
      await ref.read(syncStudyProgressProvider)(materialId);
    }
  };
});

/// Position in the deck. The flip animation is *not* here — it is an
/// AnimationController owned by the view, since it is presentation timing
/// rather than state anyone else needs.
final flashcardIndexProvider =
    NotifierProvider.autoDispose<ValueViewModel<int>, int>(
  () => ValueViewModel(0),
);
