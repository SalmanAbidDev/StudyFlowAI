// lib/core/widgets/sf_sheet.dart
//
// Every modal in this app is a bottom sheet — there are no Dialogs. Material's
// AlertDialog, ListTile and the default showModalBottomSheet all bring their
// own typography and shape, which read as if they came from a different
// product. These are the primitives that keep modals on-brand.

import 'package:flutter/material.dart';

import '../theme/theme.dart';
import 'sf_primitives.dart';

/// Opens a sheet built from the design tokens rather than Material's defaults.
///
/// The transparent background is what lets [SfSheetShell] own its corners,
/// border and grabber — and it is also why `showDragHandle` must be off:
/// `AppTheme` enables it globally, and Flutter paints that handle *above* the
/// builder, so against a transparent background it floats on the scrim beside
/// the shell's own grabber.
Future<T?> showSfSheet<T>(
  BuildContext context,
  WidgetBuilder builder, {
  bool dismissible = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: AppColors.textPrimary.withValues(alpha: 0.45),
    showDragHandle: false,
    // Without this Flutter caps a sheet at 9/16 of the screen and its content
    // overflows rather than the sheet growing — which is exactly what the
    // five-row upload source picker did on a shorter phone. The shell's Column
    // is still `min`, so short sheets are unaffected; this only lifts the
    // ceiling. 0.9 keeps a strip of scrim visible so it still reads as a sheet
    // and not a page.
    isScrollControlled: true,
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * 0.9,
    ),
    isDismissible: dismissible,
    enableDrag: dismissible,
    builder: builder,
  );
}

/// The chrome every sheet shares: canvas background, rounded top, hairline
/// border, grabber, and bottom safe-area padding.
class SfSheetShell extends StatelessWidget {
  const SfSheetShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;

    return Padding(
      // Lifts the sheet clear of the keyboard. A bottom sheet does not do this
      // on its own: it is laid out against the full screen, so a sheet with a
      // text field in it sits *behind* the keyboard it just raised. Outside
      // the SafeArea below, because the two do not stack — with the keyboard
      // up the bottom inset is zero anyway.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        decoration: BoxDecoration(
          // The canvas colour, so cards inside sit on it as they do on any
          // other screen. Using `surface` here would make them vanish into
          // their own background.
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(top: BorderSide(color: scheme.outline)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: scheme.outline,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                // Flexible + scroll rather than a bare child: once the sheet
                // reaches its ceiling something has to give, and a scroll is
                // the only answer that does not clip content off the bottom.
                // The grabber stays pinned above it.
                Flexible(
                  child: SingleChildScrollView(child: child),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A yes/no confirmation. Centred rather than left-aligned like a picker:
/// this is one focused question, not a list to scan.
///
/// Pops `true` to confirm and `false` to cancel; dismissing by scrim or swipe
/// yields null, which callers must treat as "not confirmed".
class SfConfirmSheet extends StatelessWidget {
  const SfConfirmSheet({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    required this.confirmLabel,
    this.cancelLabel = 'Cancel',
    this.destructive = true,
  });

  final IconData icon;
  final String title;
  final String body;
  final String confirmLabel;
  final String cancelLabel;

  /// Coral throughout when true — the accent is what tells you this one is not
  /// routine.
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final sf = context.sf;
    final accent = destructive ? sf.coralInk : context.scheme.primary;
    final wash = destructive ? sf.coralSoft : sf.indigoSoft;

    return SfSheetShell(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: SoftIconTile(
              icon: icon,
              color: accent,
              background: wash,
              width: 56,
              height: 56,
              radius: 18,
              iconSize: 26,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppTextStyles.heading.copyWith(
              fontSize: 20,
              letterSpacing: -0.5,
              color: sf.ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppTextStyles.fontUi,
              fontSize: 13,
              height: 1.45,
              color: sf.ink3,
            ),
          ),
          const SizedBox(height: 22),
          // Stacked rather than side by side: at a large text scale two
          // buttons in a Row would each be squeezed to a few characters.
          SfButton(
            confirmLabel,
            variant:
                destructive ? SfButtonVariant.coral : SfButtonVariant.primary,
            size: SfButtonSize.lg,
            expand: true,
            onPressed: () => Navigator.of(context).pop(true),
          ),
          const SizedBox(height: 8),
          // `secondary`, not `ghost`: the sheet body is the *canvas* colour, so
          // a surface fill with an outline reads as a button here. Ghost was
          // carried over from when this was a Dialog on `scheme.surface`,
          // where a surface-filled button would have been invisible — on the
          // canvas it is the borderless one that disappears.
          SfButton(
            cancelLabel,
            variant: SfButtonVariant.secondary,
            size: SfButtonSize.lg,
            expand: true,
            onPressed: () => Navigator.of(context).pop(false),
          ),
        ],
      ),
    );
  }
}
