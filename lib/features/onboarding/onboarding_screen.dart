// lib/features/onboarding/onboarding_screen.dart
//
// Four-page value story, ending on the Pro pitch. The header and footer live
// outside the PageView so the progress rail and CTA animate continuously
// while the art and copy swipe.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/navigation.dart';
import '../../core/theme/theme.dart';
import '../../core/widgets/widgets.dart';
import '../auth/auth_screen.dart';
import 'onboarding_view_model.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

/// The [PageController] stays here — it is a scroll position, not app state.
/// Which page is showing lives in [onboardingPageProvider] because the dots
/// and the button label both read it.
class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();

  static const _pages = <({String eyebrow, String title, String body})>[
    (
      eyebrow: '01 · Understand fast',
      title: 'AI summaries from any material.',
      body:
          'Upload a PDF, paste your notes, or scan with your camera. Flow turns '
          '40 pages into a 6-minute read.',
    ),
    (
      eyebrow: '02 · Remember more',
      title: 'Flashcards that learn how you forget.',
      body:
          'Spaced repetition built from your own materials. The cards you fail '
          'show up sooner — automatically.',
    ),
    (
      eyebrow: '03 · Stay on track',
      title: 'A study plan that bends around your week.',
      body:
          'Tell us your exam dates. Flow drops focus blocks into your calendar '
          '— and reschedules when life happens.',
    ),
    (
      eyebrow: '04 · Go Pro',
      title: 'The best students study unlimited.',
      body:
          'Unlimited Flow chats, advanced decks, full analytics. 7 days free, '
          'then \$5.99/mo billed yearly.',
    ),
  ];

  List<Color> _accents(BuildContext context) => [
        context.scheme.primary,
        context.sf.violetInk,
        context.sf.emeraldInk,
        context.sf.coralInk,
      ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _finish() {
    Navigator.of(context).pushReplacement(
      sfRoute(builder: (_) => const AuthScreen()),
    );
  }

  void _next() {
    if (ref.read(onboardingPageProvider) == _pages.length - 1) {
      _finish();
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final sf = context.sf;
    final accents = _accents(context);
    final index = ref.watch(onboardingPageProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SfLogo(size: 24),
                  TextButton(
                    onPressed: _finish,
                    style: TextButton.styleFrom(foregroundColor: sf.ink3),
                    child: Text(
                      'Skip',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: sf.ink3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged:
                    ref.read(onboardingPageProvider.notifier).update,
                itemBuilder: (context, i) {
                  final page = _pages[i];
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Center(
                            child: FittedBox(
                              fit: BoxFit.contain,
                              child: SizedBox(
                                width: 280,
                                height: 280,
                                child: _artFor(i),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        SfEyebrow(
                          page.eyebrow,
                          color: accents[i],
                          tracking: 1.5,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          page.title,
                          style: AppTextStyles.displayL.copyWith(color: sf.ink),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          page.body,
                          style: TextStyle(
                            fontSize: 15,
                            height: 1.5,
                            color: sf.ink2,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: List.generate(_pages.length, (i) {
                      final active = i == index;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                        margin: const EdgeInsets.only(right: 6),
                        width: active ? 24 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(99),
                          color: active
                              ? context.scheme.primary
                              : context.scheme.outlineVariant,
                        ),
                      );
                    }),
                  ),
                  SfButton(
                    index == _pages.length - 1 ? 'Get Started' : 'Continue',
                    trailingIcon: Icons.arrow_forward_rounded,
                    onPressed: _next,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _artFor(int i) => switch (i) {
        0 => const _ArtSummaries(),
        1 => const _ArtFlashcards(),
        2 => const _ArtPlanner(),
        _ => const _ArtPro(),
      };
}

// ─── 01 · Summaries ───────────────────────────────────────────────────────

class _ArtSummaries extends StatelessWidget {
  const _ArtSummaries();

  @override
  Widget build(BuildContext context) {
    final sf = context.sf;
    final scheme = context.scheme;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomRight,
          colors: [sf.indigoSoft, sf.lavenderSoft],
        ),
        boxShadow: AppShadows.resolve(
            AppShadows.brandGlow, Theme.of(context).brightness),
      ),
      child: Stack(
        children: [
          // Source document
          Positioned(
            top: 30,
            left: 30,
            child: Container(
              width: 150,
              height: 200,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(14),
                boxShadow: AppShadows.resolve(
                    AppShadows.md, Theme.of(context).brightness),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SfMono('CHAPTER 12.PDF', size: 9, color: sf.ink4),
                  const SizedBox(height: 8),
                  for (final w in [0.70, 0.90, 0.60, 0.85, 0.40])
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: w,
                        child: Container(
                          height: 4,
                          decoration: BoxDecoration(
                            color: scheme.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          // Generated summary
          Positioned(
            bottom: 24,
            right: 24,
            child: Container(
              width: 180,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: scheme.outline),
                boxShadow: AppShadows.resolve(
                    AppShadows.lg, Theme.of(context).brightness),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const FlowOrb(size: 16),
                      const SizedBox(width: 6),
                      Flexible(
                        child: SfEyebrow('Summary',
                            size: 11, color: scheme.primary, tracking: 0.5),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Mitochondria convert glucose to ATP through the citric '
                    'acid cycle…',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      fontWeight: FontWeight.w500,
                      color: sf.ink,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 02 · Flashcards ──────────────────────────────────────────────────────

class _ArtFlashcards extends StatelessWidget {
  const _ArtFlashcards();

  @override
  Widget build(BuildContext context) {
    final sf = context.sf;
    final scheme = context.scheme;

    Color deckColor(int i) => switch (i) {
          0 => scheme.surface,
          1 => sf.lavenderSoft,
          _ => Color.lerp(sf.lavenderSoft, sf.lavender, 0.35)!,
        };

    return Stack(
      children: [
        for (final i in [2, 1, 0])
          Positioned(
            top: 30 + i * 8,
            left: (40 - i * 8).toDouble(),
            right: (40 + i * 8).toDouble(),
            height: 180,
            child: Container(
              padding: EdgeInsets.all(i == 0 ? 22 : 0),
              decoration: BoxDecoration(
                color: deckColor(i),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: scheme.outline),
                boxShadow: AppShadows.resolve(
                  i == 0 ? AppShadows.lg : AppShadows.md,
                  Theme.of(context).brightness,
                ),
              ),
              child: i != 0
                  ? null
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const SfChip('Biology',
                                tone: SfTone.lavender, small: true),
                            SfMono('3/24', color: sf.ink4),
                          ],
                        ),
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  'What is the powerhouse of the cell?',
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTextStyles.heading
                                      .copyWith(color: sf.ink, fontSize: 20),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Tap to flip →',
                                maxLines: 1,
                                style:
                                    TextStyle(fontSize: 12, color: sf.ink3),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        Positioned(
          top: 16,
          right: 16,
          child: Transform.rotate(
            angle: 0.14,
            child: Container(
              width: 56,
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [sf.coral, const Color(0xFFFF4F70)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: sf.coral.withValues(alpha: 0.6),
                    blurRadius: 24,
                    spreadRadius: -8,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: const Icon(Icons.bolt_rounded,
                  size: 28, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── 03 · Planner ─────────────────────────────────────────────────────────

class _ArtPlanner extends StatelessWidget {
  const _ArtPlanner();

  @override
  Widget build(BuildContext context) {
    final sf = context.sf;
    final scheme = context.scheme;

    final blocks = <({String day, Color color, double height})>[
      (day: 'Mon', color: scheme.primary, height: 84),
      (day: 'Tue', color: sf.coral, height: 112),
      (day: 'Wed', color: sf.emerald, height: 70),
      (day: 'Thu', color: sf.violet, height: 98),
      (day: 'Fri', color: sf.amber, height: 63),
    ];

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: scheme.outline),
        boxShadow:
            AppShadows.resolve(AppShadows.lg, Theme.of(context).brightness),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('This Week',
                      style: AppTextStyles.title
                          .copyWith(color: sf.ink, fontSize: 18)),
                  Text('14 hrs planned',
                      style: TextStyle(fontSize: 11, color: sf.ink3)),
                ],
              ),
              const SfChip('AI',
                  tone: SfTone.emerald,
                  icon: Icons.auto_awesome_outlined,
                  small: true),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final b in blocks)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            height: b.height,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  b.color,
                                  b.color.withValues(alpha: 0.8),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          SfMono(b.day, size: 10, color: sf.ink3),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 04 · Pro ─────────────────────────────────────────────────────────────

class _ArtPro extends StatelessWidget {
  const _ArtPro();

  @override
  Widget build(BuildContext context) {
    final sf = context.sf;

    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomRight,
            colors: sf.brandSweep,
          ),
          boxShadow: [
            BoxShadow(
              color: sf.brand.withValues(alpha: 0.6),
              blurRadius: 50,
              spreadRadius: -10,
              offset: const Offset(0, 20),
            ),
          ],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              top: -64,
              right: -64,
              child: _Bubble(size: 200, opacity: 0.08),
            ),
            const Positioned(
              bottom: -84,
              left: -64,
              child: _Bubble(size: 180, opacity: 0.06),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: const Icon(Icons.star_rounded,
                          size: 18, color: Colors.white),
                    ),
                    const SizedBox(width: 8),
                    const Flexible(
                      child: SfEyebrow('StudyFlow Pro',
                          color: Colors.white, tracking: 1),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Unlimited AI for your hardest semester.',
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.heading.copyWith(
                    fontSize: 26,
                    letterSpacing: -0.8,
                    height: 1.1,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                for (final f in const [
                  'Unlimited summaries',
                  'Pro flashcard sets',
                  'Advanced analytics',
                ])
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 18,
                          height: 18,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.2),
                          ),
                          child: const Icon(Icons.check_rounded,
                              size: 11, color: Colors.white),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            f,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Soft translucent circle used to give the brand gradients depth.
class _Bubble extends StatelessWidget {
  const _Bubble({required this.size, required this.opacity});

  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: opacity),
      ),
    );
  }
}
