// lib/core/navigation.dart
//
// One place that decides how this app moves between screens.
//
// Every push goes through here rather than constructing routes inline, so the
// transition is a single decision rather than twenty. `AppTheme` also sets
// `pageTransitionsTheme` to the Cupertino builder, which catches any route
// these helpers do not create.

import 'package:flutter/cupertino.dart';

/// The standard push: a horizontal iOS-style slide.
///
/// [CupertinoPageRoute] is used on every platform on purpose — the horizontal
/// slide reads as more deliberate than Android's default, and it brings the
/// swipe-from-the-left-edge back gesture with it, which the Material route has
/// no equivalent for.
///
/// Named `builder` so it drops straight into `Navigator.push` where a
/// `MaterialPageRoute` used to sit.
Route<T> sfRoute<T>({required WidgetBuilder builder}) {
  return CupertinoPageRoute<T>(builder: builder);
}

/// A screen presented *over* the app rather than alongside it: slides up from
/// the bottom and is dismissed by its own close button.
///
/// This deliberately drops the horizontal back-swipe — a modal is dismissed by
/// its affordance, not by an edge drag.
Route<T> sfModalRoute<T>({required WidgetBuilder builder}) {
  return CupertinoPageRoute<T>(builder: builder, fullscreenDialog: true);
}
