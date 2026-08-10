// lib/features/exams/exams_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/theme.dart';
import '../../core/widgets/widgets.dart';
import '../../data/demo_content.dart';
import '../shell/shell_view_model.dart';

class ExamsScreen extends ConsumerWidget {
  const ExamsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sf = context.sf;
    final featured = demoExams.first;
    final rest = demoExams.skip(1).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 8),
          child: Row(
            children: [
              SfIconButton(
                icon: Icons.arrow_back_rounded,
                size: 38,
                onPressed: () =>
                    ref.read(shellPageProvider.notifier).go(ShellPage.planner),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Exams',
                      style: AppTextStyles.displayL
                          .copyWith(fontSize: 28, color: sf.ink),
                    ),
                    Text(
                      '${demoExams.length} upcoming · next in '
                      '${featured.daysLeft} days',
                      style: TextStyle(fontSize: 12, color: sf.ink3),
                    ),
                  ],
                ),
              ),
              SfIconButton(
                icon: Icons.add_rounded,
                size: 40,
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Exam editor is not built yet')),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 14),
          child: _FeaturedExam(exam: featured),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 0, 22, 10),
          child: Align(
            alignment: Alignment.centerLeft,
            child: SfEyebrow('Upcoming', color: sf.ink3),
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: EdgeInsets.fromLTRB(
                22, 0, 22, sfNavContentInset(context)),
            itemCount: rest.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) => _ExamRow(exam: rest[i]),
          ),
        ),
      ],
    );
  }
}

class _FeaturedExam extends StatelessWidget {
  const _FeaturedExam({required this.exam});

  final Exam exam;

  @override
  Widget build(BuildContext context) {
    final sf = context.sf;

    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [sf.coral, const Color(0xFFD14B62)],
          ),
          boxShadow: [
            BoxShadow(
              color: sf.coral.withValues(alpha: 0.5),
              blurRadius: 32,
              spreadRadius: -10,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              top: -62,
              right: -62,
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.1),
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.my_location_rounded,
                        size: 14, color: Colors.white),
                    const SizedBox(width: 6),
                    Flexible(
                      child: SfEyebrow(
                        'High priority',
                        size: 10,
                        tracking: 1,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            exam.title,
                            style: AppTextStyles.heading.copyWith(
                              fontSize: 22,
                              letterSpacing: -0.5,
                              height: 1.1,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          SfMono(
                            'THU · MAY 15 · 9:00 AM',
                            size: 12,
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${exam.daysLeft}',
                          style: const TextStyle(
                            fontFamily: AppTextStyles.fontUi,
                            fontSize: 56,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -3,
                            height: 0.9,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'DAYS LEFT',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1,
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Preparation',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                    SfMono(
                      '${(exam.preparation * 100).round()}%',
                      size: 11,
                      weight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                SfProgress(
                  value: exam.preparation,
                  color: Colors.white,
                  track: Colors.white.withValues(alpha: 0.2),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ExamRow extends StatelessWidget {
  const _ExamRow({required this.exam});

  final Exam exam;

  @override
  Widget build(BuildContext context) {
    final sf = context.sf;
    final accent = exam.accent.color(context);

    return SfCard(
      padding: const EdgeInsets.all(14),
      onTap: () {},
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: AppRadius.brMd,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${exam.daysLeft}',
                  style: TextStyle(
                    fontFamily: AppTextStyles.fontUi,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -1,
                    height: 1,
                    color: accent,
                  ),
                ),
                SfMono('DAYS',
                    size: 9,
                    weight: FontWeight.w700,
                    color: accent.withValues(alpha: 0.85)),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  exam.title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.1,
                    color: sf.ink,
                  ),
                ),
                const SizedBox(height: 4),
                SfMono(exam.date, color: sf.ink3),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: SfProgress(
                        value: exam.preparation,
                        color: accent,
                        height: 4,
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 30,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: SfMono(
                          '${(exam.preparation * 100).round()}%',
                          size: 10,
                          color: sf.ink3,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
