// lib/features/onboarding/onboarding_view_model.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/view_models.dart';

/// Which page of the pager is showing. autoDispose so reopening onboarding
/// starts at the first page — what the old per-route State object did.
final onboardingPageProvider =
    NotifierProvider.autoDispose<ValueViewModel<int>, int>(
  () => ValueViewModel(0),
);
