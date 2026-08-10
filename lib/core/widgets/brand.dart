// lib/widgets/brand.dart
//
// Brand marks: the StudyFlow glyph/wordmark, the animated Flow orb, and the
// Google "G" used on the auth screen. All of these are drawn rather than
// shipped as assets so they stay crisp at every size and follow the theme.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/theme.dart';

/// The rounded-square StudyFlow mark: three white rules with a lavender dot,
/// on the indigo → lavender brand sweep.
class SfMark extends StatelessWidget {
  const SfMark({
    super.key,
    this.size = 32,
    this.radius,
    this.glyphFraction = 1,
    this.shadow,
  });

  final double size;
  final double? radius;
  final double glyphFraction;
  final List<BoxShadow>? shadow;

  @override
  Widget build(BuildContext context) {
    final sf = context.sf;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius ?? size * 0.28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [sf.brand, sf.brandMid, sf.lavender],
        ),
        boxShadow: shadow,
      ),
      child: CustomPaint(
        painter: _MarkGlyphPainter(
          glyphFraction: glyphFraction,
          dotColor: sf.lavender,
        ),
      ),
    );
  }
}

class _MarkGlyphPainter extends CustomPainter {
  _MarkGlyphPainter({required this.glyphFraction, required this.dotColor});

  final double glyphFraction;
  final Color dotColor;

  @override
  void paint(Canvas canvas, Size size) {
    final box = size.width * glyphFraction;
    final dx = (size.width - box) / 2;
    final dy = (size.height - box) / 2;

    double x(double u) => dx + box * u;
    double y(double v) => dy + box * v;

    final rule = Paint()
      ..color = Colors.white
      ..strokeWidth = box * 0.0857
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    canvas.drawLine(Offset(x(0.32), y(0.32)), Offset(x(0.68), y(0.32)), rule);
    canvas.drawLine(Offset(x(0.32), y(0.50)), Offset(x(0.68), y(0.50)), rule);
    canvas.drawLine(Offset(x(0.32), y(0.68)), Offset(x(0.536), y(0.68)), rule);

    canvas.drawCircle(
      Offset(x(0.714), y(0.68)),
      box * 0.0786,
      Paint()..color = dotColor,
    );
  }

  @override
  bool shouldRepaint(_MarkGlyphPainter old) =>
      old.glyphFraction != glyphFraction || old.dotColor != dotColor;
}

/// Mark + "StudyFlow" wordmark, locked up horizontally.
class SfLogo extends StatelessWidget {
  const SfLogo({super.key, this.size = 28, this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SfMark(size: size, radius: size * 0.28),
        SizedBox(width: size * 0.29),
        Text(
          'StudyFlow',
          style: TextStyle(
            fontFamily: AppTextStyles.fontUi,
            fontWeight: FontWeight.w700,
            fontSize: size * 0.6,
            letterSpacing: -0.4,
            color: color ?? context.sf.ink,
          ),
        ),
      ],
    );
  }
}

/// The Flow orb — the app's AI presence indicator. A lit sphere with a soft
/// bloom, optionally breathing.
class FlowOrb extends StatefulWidget {
  const FlowOrb({
    super.key,
    this.size = 24,
    this.color,
    this.glow,
    this.animate = true,
  });

  final double size;
  final Color? color;
  final Color? glow;
  final bool animate;

  @override
  State<FlowOrb> createState() => _FlowOrbState();
}

class _FlowOrbState extends State<FlowOrb> with SingleTickerProviderStateMixin {
  // Built eagerly, not lazily: a static orb (`animate: false`) never touches
  // the controller during its lifetime, and a `late` field would then be
  // constructed inside dispose() — which creates a Ticker against an
  // already-deactivated element.
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
    if (widget.animate) _c.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(FlowOrb old) {
    super.didUpdateWidget(old);
    if (widget.animate && !_c.isAnimating) {
      _c.repeat(reverse: true);
    } else if (!widget.animate && _c.isAnimating) {
      _c.stop();
      _c.value = 0;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sf = context.sf;
    final core = widget.color ?? sf.brand;
    final glow = widget.glow ?? sf.lavender;
    final s = widget.size;

    final orb = Container(
      width: s,
      height: s,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: const Alignment(-0.3, -0.4),
          radius: 0.95,
          colors: [glow, core],
          stops: const [0, 0.75],
        ),
        boxShadow: [
          BoxShadow(
            color: glow.withValues(alpha: 0.55),
            blurRadius: s * 0.6,
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: s * 0.18,
            left: s * 0.22,
            child: Container(
              width: s * 0.28,
              height: s * 0.18,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.65),
                borderRadius: BorderRadius.all(Radius.elliptical(s, s * 0.6)),
              ),
            ),
          ),
        ],
      ),
    );

    if (!widget.animate) return SizedBox(width: s, height: s, child: orb);

    return SizedBox(
      width: s,
      height: s,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, child) => Transform.scale(
          scale: 1 + 0.05 * Curves.easeInOut.transform(_c.value),
          child: child,
        ),
        child: orb,
      ),
    );
  }
}

/// Google's four-colour "G", drawn as four arcs plus the crossbar.
class GoogleGlyph extends StatelessWidget {
  const GoogleGlyph({super.key, this.size = 20});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _GooglePainter()),
    );
  }
}

class _GooglePainter extends CustomPainter {
  static const _blue = Color(0xFF4285F4);
  static const _green = Color(0xFF34A853);
  static const _yellow = Color(0xFFFBBC04);
  static const _red = Color(0xFFEA4335);

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.22;
    final rect = Rect.fromLTWH(
      stroke / 2,
      stroke / 2,
      size.width - stroke,
      size.height - stroke,
    );
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;

    double rad(double deg) => deg * math.pi / 180;

    void arc(Color c, double startDeg, double sweepDeg) {
      canvas.drawArc(rect, rad(startDeg), rad(sweepDeg), false, p..color = c);
    }

    arc(_red, 194, 110); // upper-left through the top
    arc(_blue, 310, 62); // right shoulder down to the crossbar
    arc(_green, 20, 88); // bottom-right through the bottom
    arc(_yellow, 112, 78); // bottom-left up the left side

    // Crossbar — the horizontal stem that closes the G.
    final cy = size.height / 2;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(
          size.width * 0.48,
          cy - stroke / 2,
          size.width,
          cy + stroke / 2,
        ),
        Radius.circular(stroke / 2),
      ),
      Paint()..color = _blue,
    );
  }

  @override
  bool shouldRepaint(_GooglePainter oldDelegate) => false;
}
