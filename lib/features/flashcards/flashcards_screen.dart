// lib/features/flashcards/flashcards_screen.dart
//
// Tap the card to flip it in 3D. "Again" sends you back a card, "Got it"
// advances — the scheduling logic lives with the (unbuilt) data layer.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/theme.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models/flashcard.dart';
import 'flashcards_view_model.dart';

class FlashcardsScreen extends ConsumerStatefulWidget {
  const FlashcardsScreen({super.key});

  @override
  ConsumerState<FlashcardsScreen> createState() => _FlashcardsScreenState();
}

/// The flip is an [AnimationController], not provider state: it is animation
/// belonging to this one card view, and it already drives its own rebuilds
/// through AnimatedBuilder. Only the deck position is shared state.
class _FlashcardsScreenState extends ConsumerState<FlashcardsScreen>
    with SingleTickerProviderStateMixin {
  // Built in initState, not as a `late final` initialiser. When the deck is
  // empty nothing in build() ever reads `flip`, so the initialiser would first
  // run inside dispose() — constructing a Ticker against an element that is
  // already deactivated, which throws.
  late final AnimationController flip;

  @override
  void initState() {
    super.initState();
    flip = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
  }

  bool get _showingBack => flip.value > 0.5;

  @override
  void dispose() {
    flip.dispose();
    super.dispose();
  }

  void _toggleFace() {
    if (_showingBack) {
      flip.reverse();
    } else {
      flip.forward();
    }
  }

  void _step(int delta, int deckSize) {
    flip.value = 0;
    final next =
        (ref.read(flashcardIndexProvider) + delta).clamp(0, deckSize - 1);
    ref.read(flashcardIndexProvider.notifier).update(next);
  }

  @override
  Widget build(BuildContext context) {
    final deck = ref.watch(deckProvider);

    return Scaffold(
      body: SafeArea(
        child: deck.when(
          loading: () => const _Framed(
            child: SfLoadingList(rows: 3, height: 120),
          ),
          error: (error, _) => _Framed(
            child: SfErrorView(
              error: error,
              onRetry: () => ref.invalidate(deckProvider),
            ),
          ),
          data: (data) => (data == null || data.cards.isEmpty)
              // No action button: the way out is the ✕ in the header, and a
              // second dismiss control in the middle of the page was the
              // "back button floating in the body" this screen used to have.
              ? const _Framed(
                  child: SfEmptyView(
                    icon: Icons.style_outlined,
                    title: 'No cards yet',
                    body:
                        'Upload a document and Flow will build a deck from it.',
                  ),
                )
              : _DeckBody(deck: data, flip: flip, onFlip: _toggleFace,
                  onStep: (delta) => _step(delta, data.cards.length)),
        ),
      ),
    );
  }
}

/// The states with no deck to describe still need the screen's chrome —
/// otherwise there is nothing to close them with. The populated branch draws
/// its own header, because it carries the deck title and card counter.
class _Framed extends StatelessWidget {
  const _Framed({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SfModalHeader(title: 'Flashcards'),
        Expanded(child: child),
      ],
    );
  }
}

class _DeckBody extends ConsumerWidget {
  const _DeckBody({
    required this.deck,
    required this.flip,
    required this.onFlip,
    required this.onStep,
  });

  final Deck deck;
  final AnimationController flip;
  final VoidCallback onFlip;
  final void Function(int delta) onStep;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sf = context.sf;
    final scheme = context.scheme;
    // A deck can shrink under a stale index — clamp rather than crash.
    final index =
        ref.watch(flashcardIndexProvider).clamp(0, deck.cards.length - 1);
    final card = deck.cards[index];
    final cards = deck.cards;

    return Column(
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
                        SfEyebrow('${deck.title} · deck', tracking: 1),
                        Text(
                          '${index + 1} / ${cards.length}',
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
                  for (var i = 0; i < cards.length; i++) ...[
                    if (i > 0) const SizedBox(width: 4),
                    Expanded(
                      child: Container(
                        height: 4,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(2),
                          color: i <= index
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
                          if (index + offset < cards.length)
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
                          onTap: onFlip,
                          child: AnimatedBuilder(
                            animation: flip,
                            builder: (context, _) {
                              final angle = flip.value * math.pi;
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
                                        child: _CardBack(card: card, tag: deck.title),
                                      )
                                    : _CardFront(card: card, tag: deck.title),
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
                    // Writing the controller's value notifies the
                    // AnimatedBuilder around the card by itself.
                    onTap: () => flip.value = 0,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _WideAction(
                      label: 'Again',
                      icon: Icons.refresh_rounded,
                      background: sf.coralSoft,
                      foreground: sf.coralInk,
                      onTap: () => onStep(-1),
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
                      onTap: () => onStep(1),
                    ),
                  ),
                ],
              ),
            ),
      ],
    );
  }
}

class _CardFront extends StatelessWidget {
  const _CardFront({required this.card, required this.tag});

  final Flashcard card;
  final String tag;

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
              SfChip(tag, small: true),
              Flexible(
                child: SfMono('TAP TO FLIP', color: sf.ink4),
              ),
            ],
          ),
          // Flexible + scroll: the card is a fixed 360 tall by design, but a
          // long question or a large text scale can exceed it. Letting the
          // middle band take the slack keeps the chip and mastery rows pinned
          // where the design puts them.
          Flexible(
            child: SingleChildScrollView(
              child: Column(
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
            ),
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
  const _CardBack({required this.card, required this.tag});

  final Flashcard card;
  final String tag;

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
          // Same reasoning as the front: a long answer takes the slack rather
          // than pushing the source line off the card.
          Flexible(
            child: SingleChildScrollView(
              child: Text(
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
