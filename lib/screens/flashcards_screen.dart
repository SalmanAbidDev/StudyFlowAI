// lib/screens/flashcards_screen.dart
//
// Tap the card to flip it in 3D. "Again" sends you back a card, "Got it"
// advances — the scheduling logic lives with the (unbuilt) data layer.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/demo_content.dart';
import '../theme/theme.dart';
import '../widgets/widgets.dart';

class FlashcardsScreen extends StatefulWidget {
  const FlashcardsScreen({super.key});

  @override
  State<FlashcardsScreen> createState() => _FlashcardsScreenState();
}

class _FlashcardsScreenState extends State<FlashcardsScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flip = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  );

  int _index = 0;

  bool get _showingBack => _flip.value > 0.5;

  @override
  void dispose() {
    _flip.dispose();
    super.dispose();
  }

  void _toggleFace() {
    if (_showingBack) {
      _flip.reverse();
    } else {
      _flip.forward();
    }
  }

  void _step(int delta) {
    _flip.value = 0;
    setState(() {
      _index = (_index + delta).clamp(0, demoDeck.length - 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final sf = context.sf;
    final scheme = context.scheme;
    final card = demoDeck[_index];

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 12, 22, 12),
              child: Row(
                children: [
                  SfIconButton(
                    icon: Icons.close_rounded,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        SfEyebrow('Stereochemistry · deck', tracking: 1),
                        Text(
                          '${_index + 1} / ${demoDeck.length}',
                          style: TextStyle(
                            fontFamily: AppTextStyles.fontUi,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                            color: sf.ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SfIconButton(
                    icon: Icons.settings_outlined,
                    iconSize: 16,
                    onPressed: () {},
                  ),
                ],
              ),
            ),

            // Progress rail
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 18),
              child: Row(
                children: [
                  for (var i = 0; i < demoDeck.length; i++) ...[
                    if (i > 0) const SizedBox(width: 4),
                    Expanded(
                      child: Container(
                        height: 4,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(2),
                          color: i <= _index
                              ? scheme.primary
                              : scheme.surfaceContainerHigh,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Card stack
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: Center(
                  child: SizedBox(
                    height: 360,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        for (final offset in [2, 1])
                          if (_index + offset < demoDeck.length)
                            Positioned(
                              left: offset * 8,
                              right: offset * 8,
                              top: offset * 6,
                              height: 360 - offset * 6,
                              child: Opacity(
                                opacity: 0.5,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: scheme.surface,
                                    borderRadius: BorderRadius.circular(24),
                                    border:
                                        Border.all(color: scheme.outline),
                                    boxShadow: AppShadows.resolve(
                                      AppShadows.md,
                                      Theme.of(context).brightness,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        GestureDetector(
                          onTap: _toggleFace,
                          child: AnimatedBuilder(
                            animation: _flip,
                            builder: (context, _) {
                              final angle = _flip.value * math.pi;
                              final showBack = angle > math.pi / 2;
                              return Transform(
                                alignment: Alignment.center,
                                transform: Matrix4.identity()
                                  ..setEntry(3, 2, 0.001)
                                  ..rotateY(angle),
                                child: showBack
                                    ? Transform(
                                        alignment: Alignment.center,
                                        transform: Matrix4.identity()
                                          ..rotateY(math.pi),
                                        child: _CardBack(card: card),
                                      )
                                    : _CardFront(card: card),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Actions
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 14, 22, 16),
              child: Row(
                children: [
                  _RoundAction(
                    icon: Icons.refresh_rounded,
                    onTap: () {
                      _flip.value = 0;
                      setState(() {});
                    },
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _WideAction(
                      label: 'Again',
                      icon: Icons.refresh_rounded,
                      background: sf.coralSoft,
                      foreground: sf.coralInk,
                      onTap: () => _step(-1),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _WideAction(
                      label: 'Got it',
                      icon: Icons.check_rounded,
                      background: sf.emerald,
                      foreground: context.isDark
                          ? AppColors.textPrimary
                          : Colors.white,
                      glow: true,
                      onTap: () => _step(1),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CardFront extends StatelessWidget {
  const _CardFront({required this.card});

  final Flashcard card;

  @override
  Widget build(BuildContext context) {
    final sf = context.sf;
    final scheme = context.scheme;

    return Container(
      width: double.infinity,
      height: 360,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: scheme.outline),
        boxShadow:
            AppShadows.resolve(AppShadows.lg, Theme.of(context).brightness),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SfChip(card.tag, small: true),
              Flexible(
                child: SfMono('TAP TO FLIP', color: sf.ink4),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'QUESTION',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: sf.ink3,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                card.question,
                style: AppTextStyles.heading.copyWith(
                  fontSize: 26,
                  letterSpacing: -0.6,
                  height: 1.15,
                  color: sf.ink,
                ),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Mastery: 60%',
                  style: TextStyle(fontSize: 11, color: sf.ink3)),
              Row(
                children: [
                  for (var i = 0; i < 5; i++)
                    Container(
                      margin: const EdgeInsets.only(left: 4),
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i < 3
                            ? sf.emerald
                            : scheme.surfaceContainerHigh,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CardBack extends StatelessWidget {
  const _CardBack({required this.card});

  final Flashcard card;

  @override
  Widget build(BuildContext context) {
    final sf = context.sf;

    return Container(
      width: double.infinity,
      height: 360,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomRight,
          colors: [sf.brand, sf.brandMid],
        ),
        boxShadow:
            AppShadows.resolve(AppShadows.lg, Theme.of(context).brightness),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: AppRadius.brPill,
                ),
                child: const Text(
                  'Answer',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
              SfMono('BACK', color: Colors.white.withValues(alpha: 0.7)),
            ],
          ),
          Text(
            card.answer,
            style: const TextStyle(
              fontFamily: AppTextStyles.fontUi,
              fontSize: 19,
              fontWeight: FontWeight.w600,
              height: 1.4,
              letterSpacing: -0.3,
              color: Colors.white,
            ),
          ),
          Text(
            'Source: ${card.source}',
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 54,
        height: 54,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: context.scheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: context.scheme.outline),
        ),
        child: Icon(icon, size: 20, color: context.sf.ink),
      ),
    );
  }
}

class _WideAction extends StatelessWidget {
  const _WideAction({
    required this.label,
    required this.icon,
    required this.background,
    required this.foreground,
    required this.onTap,
    this.glow = false,
  });

  final String label;
  final IconData icon;
  final Color background;
  final Color foreground;
  final VoidCallback onTap;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 54,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(18),
          boxShadow: glow
              ? AppShadows.resolve(
                  [
                    BoxShadow(
                      color: background.withValues(alpha: 0.4),
                      blurRadius: 16,
                      spreadRadius: -4,
                      offset: const Offset(0, 6),
                    ),
                  ],
                  Theme.of(context).brightness,
                )
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: foreground),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontFamily: AppTextStyles.fontUi,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: foreground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
