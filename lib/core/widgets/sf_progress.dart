// lib/widgets/sf_progress.dart
//
// Progress readouts: the hairline bar used on every material row, and the
// ring used for streaks, focus score, and quiz results.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/theme.dart';

/// Linear progress. Defaults to the indigo → lavender brand sweep; pass a
/// solid [color] to tie the bar to a subject accent.
///
/// A null [value] is indeterminate — for work whose size is genuinely
/// unknown, like an upload the SDK reports no byte counts for. Inventing a
/// percentage there would be a nicer-looking lie.
class SfProgress extends StatelessWidget {
  const SfProgress({
    super.key,
    required this.value,
    this.color,
    this.track,
    this.height = 6,
  });

  final double? value;
  final Color? color;
  final Color? track;
  final double height;

  @override
  Widget build(BuildContext context) {
    final sf = context.sf;
    final trackColor = track ?? context.scheme.surfaceContainerHigh;
    final gradient =
        color == null ? LinearGradient(colors: [sf.brand, sf.lavender]) : null;

    if (value == null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(height),
        child: SizedBox(
          height: height,
          child: LinearProgressIndicator(
            backgroundColor: trackColor,
            color: color ?? sf.brand,
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: SizedBox(
        height: height,
        child: Stack(
          children: [
            Positioned.fill(child: ColoredBox(color: trackColor)),
            FractionallySizedBox(
              widthFactor: value!.clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  gradient: gradient,
                  borderRadius: BorderRadius.circular(height),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Circular progress with a free-form centre. Sweeps clockwise from 12
/// o'clock with a rounded cap.
class SfRing extends StatelessWidget {
  const SfRing({
    super.key,
    required this.value,
    this.size = 64,
    this.stroke = 6,
    this.color,
    this.track,
    this.child,
  });

  final double value;
  final double size;
  final double stroke;
  final Color? color;
  final Color? track;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingPainter(
          value: value.clamp(0.0, 1.0),
          stroke: stroke,
          color: color ?? context.scheme.primary,
          track: track ?? context.scheme.surfaceContainerHigh,
        ),
        child: Center(child: child),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.value,
    required this.stroke,
    required this.color,
    required this.track,
  });

  final double value;
  final double stroke;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(
      stroke / 2,
      stroke / 2,
      size.width - stroke,
      size.height - stroke,
    );

    canvas.drawArc(
      rect,
      0,
      2 * math.pi,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = track,
    );

    if (value <= 0) return;

    canvas.drawArc(
      rect,
      -math.pi / 2,
      2 * math.pi * value,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.value != value ||
      old.stroke != stroke ||
      old.color != color ||
      old.track != track;
}

/// Shimmering placeholder block used by the loading states.
class SfSkeleton extends StatefulWidget {
  const SfSkeleton({
    super.key,
    this.width,
    this.height = 10,
    this.radius = 4,
  });

  final double? width;
  final double height;
  final double radius;

  @override
  State<SfSkeleton> createState() => _SfSkeletonState();
}

class _SfSkeletonState extends State<SfSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = context.scheme.surfaceContainerHigh;
    final highlight = context.scheme.outline;

    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value * 2 - 1; // -1 → 1
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            gradient: LinearGradient(
              begin: Alignment(t - 1, 0),
              end: Alignment(t + 1, 0),
              colors: [base, highlight, base],
            ),
          ),
        );
      },
    );
  }
}
