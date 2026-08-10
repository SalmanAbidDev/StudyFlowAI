// lib/features/summaries/summaries_view_model.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/view_models.dart';

/// Index of the expanded section; -1 when every section is collapsed.
final openSummarySectionProvider =
    NotifierProvider.autoDispose<ValueViewModel<int>, int>(
  () => ValueViewModel(0),
);

/// Whether the document is bookmarked.
final summaryBookmarkedProvider =
    NotifierProvider.autoDispose<FlagViewModel, bool>(
  () => FlagViewModel(initial: false),
);
