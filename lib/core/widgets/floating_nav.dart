// lib/widgets/floating_nav.dart
//
// The frosted pill that floats above every tab screen, with the Flow orb
// raised out of its centre.

import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/theme.dart';
import 'brand.dart';

enum SfNavTab { home, materials, planner, profile }

/// Height the tab pill occupies, including its bottom margin.
const double kFloatingNavHeight = 88;

/// Bottom padding a tab screen owes its scroll content so the last item clears
/// the floating pill.
///
/// [kFloatingNavHeight] alone is not enough: the pill is laid out inside a
/// `SafeArea`, so on a device with a three-button navigation bar it floats a
/// system inset higher than on a gesture-nav device, and a flat constant hides
/// the tail of the list by exactly that inset. Reading the inset here keeps the
/// clearance honest on both.
double sfNavContentInset(BuildContext context, {double extra = 24}) =>
    kFloatingNavHeight + MediaQuery.paddingOf(context).bottom + extra;

class FloatingNavBar extends StatelessWidget {
  const FloatingNavBar({
    super.key,
    required this.active,
    required this.onSelect,
    required this.onFlow,
  });

  final SfNavTab active;
  final ValueChanged<SfNavTab> onSelect;
  final VoidCallback onFlow;

  @override
  Widget build(BuildContext context) {
    final sf = context.sf;
    final scheme = context.scheme;
    final dark = context.isDark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 18),
      // The orb is a sibling of the pill rather than a child of it. The pill's
      // ClipRRect exists to confine the backdrop blur to the rounded shape, so
      // anything inside it is clipped too — the orb would be sheared off at the
      // top the moment it rose above the bar. Clip.none lets it hover clear.
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                height: 70,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: scheme.surface.withValues(alpha: dark ? 0.85 : 0.92),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: dark
                        ? Colors.white.withValues(alpha: 0.08)
                        : AppColors.textPrimary.withValues(alpha: 0.06),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: dark
                          ? Colors.black.withValues(alpha: 0.5)
                          : AppColors.textPrimary.withValues(alpha: 0.12),
                      blurRadius: dark ? 40 : 32,
                      spreadRadius: dark ? 0 : -8,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                // Each tab takes an equal share so long labels shrink rather
                // than push the bar past the screen edge.
                child: Row(
                  children: [
                    Expanded(
                      child: _NavItem(
                        icon: Icons.home_outlined,
                        label: 'Home',
                        selected: active == SfNavTab.home,
                        onTap: () => onSelect(SfNavTab.home),
                      ),
                    ),
                    Expanded(
                      child: _NavItem(
                        icon: Icons.description_outlined,
                        label: 'Materials',
                        selected: active == SfNavTab.materials,
                        onTap: () => onSelect(SfNavTab.materials),
                      ),
                    ),
                    // Holds the gap the overlaid orb sits in. Four equal
                    // Expanded tabs around a fixed slot keeps it centred.
                    const SizedBox(width: _kFlowSize),
                    Expanded(
                      child: _NavItem(
                        icon: Icons.event_note_outlined,
                        label: 'Planner',
                        selected: active == SfNavTab.planner,
                        onTap: () => onSelect(SfNavTab.planner),
                      ),
                    ),
                    Expanded(
                      child: _NavItem(
                        icon: Icons.person_outline,
                        label: 'Profile',
                        selected: active == SfNavTab.profile,
                        onTap: () => onSelect(SfNavTab.profile),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          _FlowButton(onTap: onFlow, sf: sf),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? context.scheme.primary : context.sf.ink3;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(height: 3),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppTextStyles.fontUi,
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Side of the Flow tile. Also the width of the slot the nav row reserves for
/// it, so the two stay in step.
const double _kFlowSize = 54;

/// The Flow orb raised out of the pill's centre, hovering slowly in place.
class _FlowButton extends StatefulWidget {
  const _FlowButton({required this.onTap, required this.sf});

  final VoidCallback onTap;
  final SfColors sf;

  @override
  State<_FlowButton> createState() => _FlowButtonState();
}

class _FlowButtonState extends State<_FlowButton>
    with TickerProviderStateMixin {
  // Assigned eagerly rather than through a `late` initializer: a lazy field
  // whose first read lands in dispose() would build a Ticker against an
  // already-deactivated element.
  late final AnimationController _riseC;
  late final AnimationController _glowC;
  late final Animation<double> _rise;
  late final Animation<double> _glow;

  @override
  void initState() {
    super.initState();
    // Deliberately mismatched periods. On a shared clock the orb would be
    // brightest at exactly the top of every hover, which reads as one
    // mechanical throb; letting the two drift in and out of phase is what
    // makes it look alive.
    _riseC = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    );
    _glowC = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1750),
    );
    // easeInOut so both slow at the ends of their travel — linear reads
    // mechanical.
    _rise = CurvedAnimation(parent: _riseC, curve: Curves.easeInOut);
    _glow = CurvedAnimation(parent: _glowC, curve: Curves.easeInOut);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // A permanent idle animation is exactly what reduce-motion exists to stop,
    // so park the orb mid-travel instead of looping.
    final still = MediaQuery.disableAnimationsOf(context);
    for (final c in [_riseC, _glowC]) {
      if (still) {
        c
          ..stop()
          ..value = 0.5;
      } else if (!c.isAnimating) {
        c.repeat(reverse: true);
      }
    }
  }

  @override
  void dispose() {
    _riseC.dispose();
    _glowC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sf = widget.sf;

    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: Listenable.merge([_rise, _glow]),
        // The orb itself is static; only its position, halo and shadow move.
        child: FlowOrb(
          size: 26,
          color: Colors.white,
          glow: sf.lavender,
          animate: false,
        ),
        builder: (context, child) {
          // 0 at the bottom of the hover, 1 at the top.
          final rise = _rise.value;
          final glow = _glow.value;
          return Transform.translate(
            offset: Offset(0, -5.5 - 6 * rise),
            child: Container(
              width: _kFlowSize,
              height: _kFlowSize,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [sf.brand, sf.brandMid],
                ),
                boxShadow: [
                  // The halo: no offset, so it reads as light thrown off the
                  // tile in every direction rather than a shadow cast by it.
                  BoxShadow(
                    color: sf.brandMid.withValues(
                      alpha: ui.lerpDouble(0.22, 0.55, glow)!,
                    ),
                    blurRadius: ui.lerpDouble(14, 30, glow)!,
                    spreadRadius: ui.lerpDouble(-2, 5, glow)!,
                  ),
                  // The cast shadow drifts and softens as the orb climbs,
                  // which is what sells the lift — a button that moves with a
                  // fixed shadow just looks like it is sliding.
                  BoxShadow(
                    color: sf.brand
                        .withValues(alpha: ui.lerpDouble(0.5, 0.3, rise)!),
                    blurRadius: ui.lerpDouble(18, 30, rise)!,
                    spreadRadius: ui.lerpDouble(-4, -7, rise)!,
                    offset: Offset(0, ui.lerpDouble(7, 14, rise)!),
                  ),
                ],
              ),
              child: child,
            ),
          );
        },
      ),
    );
  }
}
