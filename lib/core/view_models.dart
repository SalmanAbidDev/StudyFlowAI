// lib/core/view_models.dart
//
// Shared view-model bases. Most of this app's screen state is one selection or
// one flag, and a bespoke Notifier for each would be a dozen near-identical
// three-line classes.

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A view model that exposes a single replaceable value.
class ValueViewModel<T> extends Notifier<T> {
  ValueViewModel(this._initial);

  final T _initial;

  @override
  T build() => _initial;

  void update(T value) => state = value;
}

/// A [ValueViewModel] that can also flip itself, for the on/off cases.
class FlagViewModel extends ValueViewModel<bool> {
  FlagViewModel({required bool initial}) : super(initial);

  void toggle() => state = !state;
}
