// lib/widgets/floating_nav.dart
//
// The frosted pill that floats above every tab screen, with the Flow orb
// raised out of its centre.

import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/theme.dart';
import 'brand.dart';

enum SfNavTab { home, materials, planner, profile }

/// Height the tab pill occupies, including its bottom margin. Screens pad
/// their scroll content by this much so nothing hides underneath.
const double kFloatingNavHeight = 88;

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
      child: ClipRRect(
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
                _FlowButton(onTap: onFlow, sf: sf),
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

class _FlowButton extends StatelessWidget {
  const _FlowButton({required this.onTap, required this.sf});

  final VoidCallback onTap;
  final SfColors sf;

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: const Offset(0, -8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 54,
          height: 54,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [sf.brand, sf.brandMid],
            ),
            boxShadow: [
              BoxShadow(
                color: sf.brand.withValues(alpha: 0.5),
                blurRadius: 20,
                spreadRadius: -4,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: FlowOrb(
            size: 26,
            color: Colors.white,
            glow: sf.lavender,
            animate: false,
          ),
        ),
      ),
    );
  }
}
