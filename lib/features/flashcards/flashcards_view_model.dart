// lib/features/flashcards/flashcards_view_model.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/view_models.dart';
import '../../data/models/flashcard.dart';
import '../../data/supabase_providers.dart';

final deckProvider = FutureProvider.autoDispose<Deck?>(
  (ref) => ref.watch(studyRepositoryProvider).firstDeck(),
);

/// Position in the deck. The flip animation is *not* here — it is an
/// AnimationController owned by the view, since it is presentation timing
/// rather than state anyone else needs.
final flashcardIndexProvider =
    NotifierProvider.autoDispose<ValueViewModel<int>, int>(
  () => ValueViewModel(0),
);
