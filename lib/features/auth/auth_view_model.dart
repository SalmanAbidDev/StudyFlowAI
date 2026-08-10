// lib/features/auth/auth_view_model.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/view_models.dart';

/// Whether the password field is masked.
final passwordObscuredProvider =
    NotifierProvider.autoDispose<FlagViewModel, bool>(
  () => FlagViewModel(initial: true),
);
