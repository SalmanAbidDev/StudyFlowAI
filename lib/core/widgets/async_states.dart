// lib/core/widgets/async_states.dart
//
// Every screen now reads from the network, so every screen needs the same
// three answers to "what if it hasn't arrived / failed / is empty". Putting
// them here keeps a retry button from looking different on each screen.

import 'package:flutter/material.dart';

import '../theme/theme.dart';
import 'sf_primitives.dart';
import 'sf_progress.dart';

/// The loading placeholder. Skeletons rather than a spinner: the layout is
/// known before the data is, so showing its shape avoids a jarring reflow.
class SfLoadingList extends StatelessWidget {
  const SfLoadingList({
    super.key,
    this.rows = 4,
    this.height = 76,
    this.padding = const EdgeInsets.fromLTRB(22, 4, 22, 0),
  });

  final int rows;
  final double height;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    const gap = 10.0;

    return Padding(
      padding: padding,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Show as many rows as there is room for. A placeholder that
          // overflows the box it is standing in for is worse than the wait it
          // is covering — and this widget is used both inside an Expanded
          // (bounded) and as a list child (unbounded).
          final count = constraints.maxHeight.isFinite
              ? (constraints.maxHeight ~/ (height + gap)).clamp(1, rows)
              : rows;

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < count; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: gap),
                  child: SfSkeleton(height: height, radius: AppRadius.lg),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// What a failed request looks like. Always offers the retry — a dead end with
/// no way forward is the worst version of this state.
class SfErrorView extends StatelessWidget {
  const SfErrorView({
    super.key,
    required this.error,
    this.onRetry,
    this.compact = false,
  });

  final Object error;
  final VoidCallback? onRetry;
  final bool compact;

  /// Postgrest and socket errors read like stack traces. Show something a
  /// person can act on and keep the detail for the logs.
  String get _message {
    final raw = error.toString();
    if (raw.contains('SocketException') ||
        raw.contains('Failed host lookup') ||
        raw.contains('ClientException')) {
      return "Can't reach the server. Check your connection.";
    }
    if (raw.contains('JWT') || raw.contains('not authenticated')) {
      return 'Your session expired. Sign in again.';
    }
    return 'Something went wrong loading this.';
  }

  @override
  Widget build(BuildContext context) {
    final sf = context.sf;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SoftIconTile(
              icon: Icons.cloud_off_rounded,
              color: sf.coral,
              background: sf.coralSoft,
              width: compact ? 40 : 56,
              height: compact ? 40 : 56,
              radius: 16,
              iconSize: compact ? 20 : 26,
            ),
            const SizedBox(height: 12),
            Text(
              _message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: sf.ink,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 14),
              SfButton(
                'Try again',
                size: SfButtonSize.sm,
                icon: Icons.refresh_rounded,
                onPressed: onRetry,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Nothing here yet — distinct from an error, and usually the more common of
/// the two on a fresh account.
class SfEmptyView extends StatelessWidget {
  const SfEmptyView({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final sf = context.sf;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: SfCard(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SoftIconTile(
                icon: icon,
                color: context.scheme.primary,
                background: sf.indigoSoft,
                width: 56,
                height: 56,
                radius: 18,
                iconSize: 26,
              ),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: sf.ink,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                body,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, height: 1.4, color: sf.ink3),
              ),
              if (actionLabel != null) ...[
                const SizedBox(height: 14),
                SfButton(
                  actionLabel!,
                  size: SfButtonSize.sm,
                  onPressed: onAction,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
