// lib/features/analytics/analytics_view_model.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/view_models.dart';
import '../../data/repositories/analytics_repository.dart';
import '../../data/supabase_providers.dart';

/// Which range the Insights header is showing: Week / Month / Year.
final analyticsRangeProvider = NotifierProvider<ValueViewModel<int>, int>(
  () => ValueViewModel(0),
);

const _rangeDays = [7, 30, 365];

final studyStatsProvider = FutureProvider<StudyStats>((ref) {
  final range = ref.watch(analyticsRangeProvider);
  return ref.watch(analyticsRepositoryProvider).stats(days: _rangeDays[range]);
});
