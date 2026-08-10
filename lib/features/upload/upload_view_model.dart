// lib/state/upload_state.dart

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A looping fake upload. Nothing is transferred — this drives the progress
/// bar so the screen reads as live.
class UploadProgress extends Notifier<double> {
  Timer? _ticker;

  @override
  double build() {
    _ticker = Timer.periodic(const Duration(milliseconds: 600), (_) {
      final next = state + 0.03;
      state = next >= 1 ? 0.08 : next;
    });
    ref.onDispose(() => _ticker?.cancel());
    return 0.67;
  }

  /// The ✕ on the uploading row: freezes the bar where it is.
  void cancel() => _ticker?.cancel();
}

final uploadProgressProvider =
    NotifierProvider.autoDispose<UploadProgress, double>(UploadProgress.new);
