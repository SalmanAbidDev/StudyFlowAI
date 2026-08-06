// lib/screens/quiz_result_screen.dart

import 'package:flutter/material.dart';

import '../theme/theme.dart';
import '../widgets/widgets.dart';
import 'quiz_screen.dart';

class QuizResultScreen extends StatelessWidget {
  const QuizResultScreen({
    super.key,
    required this.correct,
    required this.total,
    required this.elapsedSeconds,
    required this.missed,
  });

  final int correct;
  final int total;
  final int elapsedSeconds;
  final List<String> missed;

  double get _score => total == 0 ? 0 : correct / total;

  String get _clock {
    final m = elapsedSeconds ~/ 60;
    final s = (elapsedSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String _headline() {
    if (_score >= 0.9) return 'Near perfect, Alex! 🎯';
    if (_score >= 0.6) return 'Strong run, Alex! 🎯';
    return "Rough one — let's drill it.";
  }

  String _body() {
    if (missed.isEmpty) {
      return 'A clean sweep. Flow will space these cards further apart from '
          'here.';
    }
    return 'You answered $correct of $total. The ${missed.length} you missed '
        'go back into the deck for tomorrow.';
  }

  @override
  Widget build(BuildContext context) {
    final sf = context.sf;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 20, 22, 0),
              child: Column(
                children: [
                  SfRing(
                    value: _score,
                    size: 156,
                    stroke: 10,
                    color: _score >= 0.6 ? sf.emerald : sf.coral,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text.rich(
                          TextSpan(
                            text: '${(_score * 100).round()}',
                            style: AppTextStyles.displayXL.copyWith(
                              fontSize: 44,
                              letterSpacing: -2,
                              height: 1,
                              color: sf.ink,
                            ),
                            children: [
                              TextSpan(
                                text: '%',
                                style: TextStyle(
                                  fontSize: 22,
                                  color: sf.ink3,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SfEyebrow('Score', tracking: 1, color: sf.ink3),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    _headline(),
                    textAlign: TextAlign.center,
                    style: AppTextStyles.heading.copyWith(
                      fontSize: 26,
                      letterSpacing: -0.7,
                      color: sf.ink,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 300),
                    child: Text(
                      _body(),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        color: sf.ink2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      for (final s in <({String label, String value, Color color})>[
                        (
                          label: 'Correct',
                          value: '$correct/$total',
                          color: sf.emeraldInk
                        ),
                        (
                          label: 'Time',
                          value: _clock,
                          color: context.scheme.primary
                        ),
                        (
                          label: 'XP',
                          value: '+${correct * 30}',
                          color: sf.amberInk
                        ),
                      ]) ...[
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: SfCard(
                              radius: AppRadius.md,
                              padding: const EdgeInsets.symmetric(
                                  vertical: 12, horizontal: 8),
                              child: Column(
                                children: [
                                  Text(
                                    s.value,
                                    style: TextStyle(
                                      fontFamily: AppTextStyles.fontUi,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: -0.4,
                                      color: s.color,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    s.label,
                                    style: TextStyle(
                                        fontSize: 11, color: sf.ink3),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (missed.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 0, 22, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionHeader('Review missed'),
                    for (final m in missed)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: SfCard(
                          padding: const EdgeInsets.all(14),
                          onTap: () {},
                          child: Row(
                            children: [
                              SoftIconTile(
                                icon: Icons.close_rounded,
                                color: sf.coral,
                                background: sf.coralSoft,
                                width: 32,
                                height: 32,
                                radius: 9,
                                iconSize: 14,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  m,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: sf.ink,
                                  ),
                                ),
                              ),
                              Icon(Icons.chevron_right_rounded,
                                  size: 18, color: sf.ink4),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 4, 22, 8),
              child: Row(
                children: [
                  Expanded(
                    child: SfButton(
                      'Retake',
                      variant: SfButtonVariant.secondary,
                      size: SfButtonSize.lg,
                      icon: Icons.refresh_rounded,
                      expand: true,
                      onPressed: () => Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (_) => const QuizScreen()),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SfButton(
                      'Continue',
                      size: SfButtonSize.lg,
                      expand: true,
                      trailingIcon: Icons.arrow_forward_rounded,
                      onPressed: () => Navigator.of(context).pop(),
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
