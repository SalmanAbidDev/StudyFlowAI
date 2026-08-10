// lib/features/quiz/quiz_screen.dart
//
// Picking an option reveals the answer and its explanation immediately;
// "Next question" moves on. The run — score, clock, position in the deck —
// lives in quizProvider; this file is the view over it.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/theme.dart';
import '../../core/widgets/widgets.dart';
import '../../data/demo_content.dart';
import 'quiz_result_screen.dart';
import 'quiz_view_model.dart';

class QuizScreen extends ConsumerWidget {
  const QuizScreen({super.key});

  /// Advances, or leaves for the results if the deck is finished.
  void _advance(BuildContext context, WidgetRef ref) {
    final run = ref.read(quizProvider);
    if (ref.read(quizProvider.notifier).advance()) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => QuizResultScreen(
          correct: run.correct,
          total: demoQuiz.length,
          elapsedSeconds: run.elapsed,
          missed: run.missed,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sf = context.sf;
    final scheme = context.scheme;
    final run = ref.watch(quizProvider);
    final q = run.question;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 12, 22, 10),
              child: Row(
                children: [
                  SfIconButton(
                    icon: Icons.close_rounded,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Row(
                      children: [
                        for (var i = 0; i < demoQuiz.length; i++) ...[
                          if (i > 0) const SizedBox(width: 4),
                          Expanded(
                            child: Container(
                              height: 4,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(2),
                                color: i < run.index
                                    ? sf.emerald
                                    : i == run.index
                                        ? scheme.primary
                                        : scheme.surfaceContainerHigh,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: sf.coralSoft,
                      borderRadius: AppRadius.brSm,
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.schedule_rounded,
                            size: 14, color: sf.coral),
                        const SizedBox(width: 6),
                        SfMono(run.clock,
                            size: 13,
                            weight: FontWeight.w700,
                            color: sf.coralInk),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Question
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(22, 14, 22, 14),
                children: [
                  SfEyebrow(
                    'Question ${run.index + 1} of ${demoQuiz.length} · MCQ',
                    color: sf.ink3,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    q.prompt,
                    style: AppTextStyles.heading.copyWith(
                      fontSize: 24,
                      letterSpacing: -0.6,
                      height: 1.2,
                      color: sf.ink,
                    ),
                  ),
                  const SizedBox(height: 22),
                  for (final o in q.options)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _OptionTile(
                        option: o,
                        picked: run.picked == o.id,
                        revealed: run.revealed,
                        onTap: () => ref.read(quizProvider.notifier).pick(o),
                      ),
                    ),
                  if (run.revealed) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: sf.indigoSoft,
                        borderRadius: AppRadius.brMd,
                        border: Border.all(
                          color: scheme.primary.withValues(alpha: 0.12),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const FlowOrb(size: 16),
                              const SizedBox(width: 6),
                              Flexible(
                                child: SfEyebrow('Explanation',
                                    tracking: 1, color: scheme.primary),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          MarkedText(
                            q.explanation,
                            accentColor: scheme.primary,
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.5,
                              color: sf.ink2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Actions
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 12, 22, 16),
              child: Row(
                children: [
                  Expanded(
                    child: SfButton(
                      'Skip',
                      variant: SfButtonVariant.secondary,
                      size: SfButtonSize.lg,
                      expand: true,
                      onPressed: () => _advance(context, ref),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: SfButton(
                      run.isLastQuestion ? 'See results' : 'Next question',
                      size: SfButtonSize.lg,
                      expand: true,
                      trailingIcon: Icons.arrow_forward_rounded,
                      onPressed: () => _advance(context, ref),
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

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.option,
    required this.picked,
    required this.revealed,
    required this.onTap,
  });

  final QuizOption option;
  final bool picked;
  final bool revealed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final sf = context.sf;
    final scheme = context.scheme;

    final isCorrect = revealed && option.correct;
    final isWrong = revealed && picked && !option.correct;

    final background = isCorrect
        ? sf.emeraldSoft
        : isWrong
            ? sf.coralSoft
            : picked
                ? sf.indigoSoft
                : scheme.surface;
    final borderColor = isCorrect
        ? sf.emerald
        : isWrong
            ? sf.coral
            : picked
                ? scheme.primary
                : scheme.outline;
    final foreground = isCorrect
        ? sf.emeraldInk
        : isWrong
            ? sf.coralInk
            : sf.ink;
    final markerColor = isCorrect
        ? sf.emerald
        : isWrong
            ? sf.coral
            : picked
                ? scheme.primary
                : scheme.surfaceContainerHigh;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: background,
          borderRadius: AppRadius.brMd,
          border: Border.all(color: borderColor, width: 2),
        ),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: markerColor,
                borderRadius: BorderRadius.circular(9),
              ),
              child: isCorrect
                  ? const Icon(Icons.check_rounded,
                      size: 14, color: Colors.white)
                  : isWrong
                      ? const Icon(Icons.close_rounded,
                          size: 14, color: Colors.white)
                      : SfMono(
                          option.id.toUpperCase(),
                          size: 12,
                          weight: FontWeight.w700,
                          color: picked ? Colors.white : sf.ink2,
                        ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                option.text,
                style: TextStyle(
                  fontFamily: AppTextStyles.fontUi,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                  color: foreground,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
