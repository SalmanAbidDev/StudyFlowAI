// lib/features/exams/exams_screen.dart
//
// A pushed route, not a shell tab. It used to be an IndexedStack child, which
// meant no page transition, the tab bar sitting on top of it, and the system
// back button having nothing to pop.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/theme.dart';
import '../../core/widgets/widgets.dart';
import '../../core/navigation.dart';
import '../../data/models/exam.dart';
import '../../data/models/subject.dart';
import 'exam_detail_screen.dart';
import 'exam_editor_screen.dart';
import 'exams_view_model.dart';

class ExamsScreen extends ConsumerWidget {
  const ExamsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sf = context.sf;
    final examsAsync = ref.watch(examPrepsProvider);
    final exams = examsAsync.value ?? const <ExamPrep>[];
    final featured = exams.isEmpty ? null : exams.first;
    final rest = exams.skip(1).toList();

    void open(ExamPrep prep) {
      ref.read(selectedExamProvider.notifier).update(prep.exam.id);
      Navigator.of(context).push(
        sfRoute(builder: (_) => const ExamDetailScreen()),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 8),
          child: Row(
            children: [
              SfIconButton(
                icon: Icons.arrow_back_rounded,
                size: 38,
                // Pops back to whoever pushed it — Home or Planner — rather
                // than always landing on one of them.
                onPressed: () => Navigator.of(context).maybePop(),
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
                      featured == null
                          ? 'Nothing scheduled'
                          : '${exams.length} upcoming · next '
                              '${featured.exam.countdown}',
                      style: TextStyle(fontSize: 12, color: sf.ink3),
                    ),
                  ],
                ),
              ),
              SfIconButton(
                icon: Icons.add_rounded,
                size: 40,
                filled: true,
                onPressed: () => Navigator.of(context).push(
                  sfModalRoute(builder: (_) => const ExamEditorScreen()),
                ),
              ),
            ],
          ),
        ),
        if (featured != null) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 14),
            child: GestureDetector(
              onTap: () => open(featured),
              child: _FeaturedExam(prep: featured),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 10),
            child: Align(
              alignment: Alignment.centerLeft,
              child: SfEyebrow('Upcoming', color: sf.ink3),
            ),
          ),
        ],
        Expanded(
          child: examsAsync.when(
            loading: () => const SfLoadingList(rows: 3, height: 72),
            error: (error, _) => SfErrorView(
              error: error,
              onRetry: () => ref.invalidate(examPrepsProvider),
            ),
            data: (_) => exams.isEmpty
                // No action button: adding is the ＋ in the header, and one
                // control per job beats the same job offered twice on the same
                // screen — the same rule the Materials empty state follows.
                ? const SfEmptyView(
                    icon: Icons.event_available_outlined,
                    title: 'No exams scheduled',
                    body: 'Tap ＋ to add an exam date, and Flow will plan '
                        'around it.',
                  )
                : ListView.separated(
                    // No nav pill to clear any more — this is a pushed route.
                    padding: const EdgeInsets.fromLTRB(22, 0, 22, 24),
                    itemCount: rest.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, i) => _ExamRow(
                      prep: rest[i],
                      onTap: () => open(rest[i]),
                    ),
                  ),
          ),
        ),
      ],
        ),
      ),
    );
  }
}

class _FeaturedExam extends StatelessWidget {
  const _FeaturedExam({required this.prep});

  final ExamPrep prep;

  @override
  Widget build(BuildContext context) {
    final sf = context.sf;
    final exam = prep.exam;

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
                // Said 'High priority' on whatever exam happened to be
                // next. Now it says it only when the exam is one.
                Row(
                  children: [
                    Icon(
                      exam.priority == ExamPriority.high
                          ? Icons.my_location_rounded
                          : Icons.event_outlined,
                      size: 14,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: SfEyebrow(
                        exam.priority == ExamPriority.high
                            ? 'High priority'
                            : 'Next up',
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
                          // Was that literal string for every exam.
                          // Built from the row now, and it drops the
                          // time when none was entered.
                          SfMono(
                            exam.schedule,
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
                      prep.preparationLabel,
                      size: 11,
                      weight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                SfProgress(
                  value: prep.preparation ?? 0,
                  color: Colors.white,
                  track: Colors.white.withValues(alpha: 0.2),
                ),
                if (!prep.hasMaterials) ...[
                  const SizedBox(height: 8),
                  Text(
                    'No materials added — tap to add them',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ExamRow extends StatelessWidget {
  const _ExamRow({required this.prep, required this.onTap});

  final ExamPrep prep;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final sf = context.sf;
    final exam = prep.exam;
    final accent = exam.accent.color(context);

    return SfCard(
      padding: const EdgeInsets.all(14),
      onTap: onTap,
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
                SfMono(
                  exam.examTime == null
                      ? exam.date
                      : '${exam.date} · ${exam.time}',
                  color: sf.ink3,
                ),
                const SizedBox(height: 8),
                // Nothing attached says so, instead of a 0% bar that
                // reads as 'you have done none of it' when the truth is
                // 'there is nothing to measure'.
                if (!prep.hasMaterials)
                  Text(
                    'No materials added',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: sf.ink4,
                    ),
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: SfProgress(
                          value: prep.preparation ?? 0,
                          color: accent,
                          height: 4,
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 34,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: SfMono(
                            prep.preparationLabel,
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
