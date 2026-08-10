// lib/features/flashcards/flashcards_view_model.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/view_models.dart';

/// Position in the deck. The flip animation is *not* here — it is an
/// AnimationController owned by the view, since it is presentation timing
/// rather than state anyone else needs.
final flashcardIndexProvider =
    NotifierProvider.autoDispose<ValueViewModel<int>, int>(
  () => ValueViewModel(0),
);
