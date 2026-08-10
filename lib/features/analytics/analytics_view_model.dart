// lib/state/analytics_state.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/view_models.dart';

/// Which range the Insights header is showing: Week / Month / All.
final analyticsRangeProvider = NotifierProvider<ValueViewModel<int>, int>(
  () => ValueViewModel(0),
);
