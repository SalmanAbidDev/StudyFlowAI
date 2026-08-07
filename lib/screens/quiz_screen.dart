// lib/screens/quiz_screen.dart
//
// Picking an option reveals the answer and its explanation immediately;
// "Next question" moves on. Scoring is tallied locally and handed to the
// result screen.

import 'dart:async';

import 'package:flutter/material.dart';

import '../data/demo_content.dart';
import '../theme/theme.dart';
import '../widgets/widgets.dart';
import 'quiz_result_screen.dart';

class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  int _index = 0;
  String? _picked;
  bool _revealed = false;
  int _correct = 0;
  final _missed = <String>[];

  static const _perQuestionSeconds = 42;
  int _remaining = _perQuestionSeconds;
  int _elapsed = 0;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _elapsed++;
        if (_remaining > 0) _remaining--;
      });
    });
  }

  void _pick(QuizOption option) {
    if (_revealed) return;
    setState(() {
      _picked = option.id;
      _revealed = true;
      _ticker?.cancel();
      if (option.correct) {
        _correct++;
      } else {
        _missed.add('Q${_index + 1} · ${demoQuiz[_index].prompt}');
      }
    });
  }

  void _advance() {
    if (_index == demoQuiz.length - 1) {
      _ticker?.cancel();
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => QuizResultScreen(
            correct: _correct,
            total: demoQuiz.length,
            elapsedSeconds: _elapsed,
            missed: _missed,
          ),
        ),
      );
      return;
    }
    setState(() {
      _index++;
      _picked = null;
      _revealed = false;
      _remaining = _perQuestionSeconds;
    });
    _startTimer();
  }

  String get _clock {
    final m = _remaining ~/ 60;
    final s = (_remaining % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final sf = context.sf;
    final scheme = context.scheme;
    final q = demoQuiz[_index];

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
                                color: i < _index
                                    ? sf.emerald
                                    : i == _index
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
                        SfMono(_clock,
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
                    'Question ${_index + 1} of ${demoQuiz.length} · MCQ',
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
                        picked: _picked == o.id,
                        revealed: _revealed,
                        onTap: () => _pick(o),
                      ),
                    ),
                  if (_revealed) ...[
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
                      onPressed: _advance,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: SfButton(
                      _index == demoQuiz.length - 1
                          ? 'See results'
                          : 'Next question',
                      size: SfButtonSize.lg,
                      expand: true,
                      trailingIcon: Icons.arrow_forward_rounded,
                      onPressed: _advance,
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
