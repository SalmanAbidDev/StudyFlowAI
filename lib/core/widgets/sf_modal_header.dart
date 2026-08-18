// lib/core/widgets/sf_modal_header.dart
//
// The bar at the top of a screen that is dismissed with a close button rather
// than a back arrow (§3.2 of CluadeWork.md: ✕ screens are pushed with
// `sfModalRoute`). Upload had this inline; Flashcards and Quiz had it only on
// their *populated* branch, so an empty deck left the screen with no way out
// except a "Back" button parked in the middle of the page.

import 'package:flutter/material.dart';

import '../theme/theme.dart';
import 'sf_primitives.dart';

class SfModalHeader extends StatelessWidget {
  const SfModalHeader({
    super.key,
    required this.title,
    this.trailing,
    this.onClose,
    this.padding = const EdgeInsets.fromLTRB(22, 12, 22, 18),
  });

  final String title;

  /// Optional right-hand action. When absent the slot is still reserved, so
  /// the title stays optically centred against the close button.
  final Widget? trailing;

  /// Defaults to popping the route, which is what every caller wants.
  final VoidCallback? onClose;

  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final sf = context.sf;

    return Padding(
      padding: padding,
      child: Row(
        children: [
          SfIconButton(
            icon: Icons.close_rounded,
            onPressed: onClose ?? () => Navigator.of(context).maybePop(),
          ),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: AppTextStyles.fontUi,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
                color: sf.ink,
              ),
            ),
          ),
          // Matches SfIconButton's default size so the title sits centred
          // whether or not there is a trailing action.
          SizedBox(width: 38, child: trailing),
        ],
      ),
    );
  }
}
