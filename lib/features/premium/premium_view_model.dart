// lib/features/premium/premium_view_model.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/view_models.dart';

/// Yearly billing selected, as opposed to monthly.
final yearlyBillingProvider =
    NotifierProvider.autoDispose<FlagViewModel, bool>(
  () => FlagViewModel(initial: true),
);
