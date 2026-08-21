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
import '../materials/generate_button.dart';
import '../materials/generate_view_model.dart';
import '../materials/generated_empty_view.dart';
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

  /// True while the last card's review is being written. Finishing the deck
  /// syncs progress and can tick off today's task, which is a round trip —
  /// without this the Done button looks stuck.
  var _finishing = false;

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

  /// "Again" and "Got it" both record the review; only the direction differs.
  /// The card is read from the *live* deck rather than captured, because the
  /// index can have moved by the time the button is pressed.
  Future<void> _review(Deck deck, {required bool remembered}) async {
    if (_finishing) return;
    final index =
        ref.read(flashcardIndexProvider).clamp(0, deck.cards.length - 1);
    final card = deck.cards[index];
    final last = index == deck.cards.length - 1;

    // The last card has nowhere to advance to, so it stays put and the deck
    // closes instead. It is still recorded: it is the card that takes the
    // material to 100%, which is what ticks off today's task.
    if (!last) {
      _step(1, deck.cards.length);
    } else {
      setState(() => _finishing = true);
    }

    await ref.read(reviewCardProvider)(card, remembered: remembered);

    if (!last || !mounted) return;
    Navigator.of(context).maybePop();
  }

  void _restart() {
    flip.value = 0;
    ref.read(flashcardIndexProvider.notifier).update(0);
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
                  footer: GenerateBar(target: GenerateTarget.flashcards),
                  child: GeneratedEmptyView(
                    icon: Icons.style_outlined,
                    noun: 'cards',
                  ),
                )
              : _DeckBody(
                  deck: data,
                  flip: flip,
                  onFlip: _toggleFace,
                  onStep: (delta) => _step(delta, data.cards.length),
                  onReview: ({required bool remembered}) =>
                      _review(data, remembered: remembered),
                  onRestart: _restart,
                  finishing: _finishing,
                ),
        ),
      ),
    );
  }
}

/// The states with no deck to describe still need the screen's chrome —
/// otherwise there is nothing to close them with. The populated branch draws
/// its own header, because it carries the deck title and card counter.
class _Framed extends StatelessWidget {
  const _Framed({required this.child, this.footer});

  final Widget child;

  /// Pinned under the empty state — the way *out* of having nothing.
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SfModalHeader(title: 'Flashcards'),
        Expanded(child: child),
        ?footer,
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
    required this.onReview,
    required this.onRestart,
    required this.finishing,
  });

  final Deck deck;
  final AnimationController flip;
  final VoidCallback onFlip;
  final void Function(int delta) onStep;

  /// Writes the review down, then steps. Separate from [onStep] because the
  /// arrows and the refresh button move without judging the card.
  final void Function({required bool remembered}) onReview;

  /// Back to the first card, from wherever you are.
  final VoidCallback onRestart;

  /// The last card's review is in flight and the deck is about to close.
  final bool finishing;

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
                  // The slot stays, empty, so the counter above stays
                  // optically centred. There was a settings button here with
                  // an empty onPressed — a control that did nothing at all.
                  const SizedBox(width: 38),
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
                    icon: Icons.restart_alt_rounded,
                    // Back to card one, wherever you are. It used to only
                    // un-flip the card you were already on, which is what the
                    // tap on the card itself does.
                    onTap: onRestart,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _WideAction(
                      label: 'Previous',
                      icon: Icons.arrow_back_rounded,
                      background: context.scheme.surfaceContainerHigh,
                      foreground: sf.ink2,
                      // Navigation only. Going back is not a judgement about
                      // the card, so nothing is recorded.
                      onTap: index == 0 ? null : () => onStep(-1),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _WideAction(
                      // The last card has nothing to be next to.
                      label: index == cards.length - 1 ? 'Done' : 'Next',
                      icon: index == cards.length - 1
                          ? Icons.check_rounded
                          : Icons.arrow_forward_rounded,
                      trailingIcon: true,
                      busy: finishing,
                      background: sf.emerald,
                      foreground: context.isDark
                          ? AppColors.textPrimary
                          : Colors.white,
                      glow: true,
                      // Moving on is what marks a card seen — it is the only
                      // thing left that records anything, and the progress
                      // bar and the day's task both depend on it.
                      onTap: finishing ? null : () => onReview(remembered: true),
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
              // Was "Mastery: 60%" on every card ever shown. The rating is
              // the model's, made when the card was written — see
              // `Flashcard.difficulty`.
              // Flexible: "Difficulty: Fairly easy" is a good deal longer
              // than the "Mastery: 60%" that used to sit here, and at text
              // scale 1.3 a bare Row ran 53px off the card.
              Flexible(
                child: Text(
                  card.difficultyLabel == null
                      ? 'Not rated'
                      : 'Difficulty: ${card.difficultyLabel}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: sf.ink3),
                ),
              ),
              Row(
                children: [
                  for (var i = 0; i < 5; i++)
                    Container(
                      margin: const EdgeInsets.only(left: 4),
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i < (card.difficulty ?? 0)
                            ? _difficultyColor(context, card.difficulty!)
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

/// Green for an easy card through coral for a hard one. Five dots, filled to
/// the rating.
Color _difficultyColor(BuildContext context, int difficulty) {
  final sf = context.sf;
  return switch (difficulty) {
    1 || 2 => sf.emerald,
    3 => context.scheme.primary,
    _ => sf.coral,
  };
}

/// The icon, or a spinner the same size so the button does not change width.
class _Glyph extends StatelessWidget {
  const _Glyph({required this.icon, required this.colour, required this.busy});

  final IconData icon;
  final Color colour;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    if (!busy) return Icon(icon, size: 16, color: colour);
    return SizedBox(
      width: 16,
      height: 16,
      child: CircularProgressIndicator(strokeWidth: 2, color: colour),
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
    this.trailingIcon = false,
    this.busy = false,
  });

  final String label;
  final IconData icon;
  final Color background;
  final Color foreground;

  /// Null disables it — "Previous" on the first card has nowhere to go, and a
  /// button that responds by doing nothing is worse than one that looks spent.
  final VoidCallback? onTap;
  final bool glow;

  /// Icon after the label rather than before, so "Next →" reads in the
  /// direction it moves.
  final bool trailingIcon;

  /// Swaps the icon for a spinner. The work is a round trip, and a button that
  /// looks idle while it runs reads as broken.
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: enabled ? 1 : 0.45,
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
            if (!trailingIcon) ...[
              _Glyph(icon: icon, colour: foreground, busy: busy),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: AppTextStyles.fontUi,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: foreground,
                ),
              ),
            ),
            if (trailingIcon) ...[
              const SizedBox(width: 8),
              _Glyph(icon: icon, colour: foreground, busy: busy),
            ],
          ],
        ),
      ),
      ),
    );
  }
}
