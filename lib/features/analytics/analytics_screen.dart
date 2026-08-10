// lib/features/analytics/analytics_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/theme.dart';
import '../../core/widgets/widgets.dart';
import '../../data/demo_content.dart';
import '../shell/shell_view_model.dart';
import 'analytics_view_model.dart';

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sf = context.sf;
    final scheme = context.scheme;
    final range = ref.watch(analyticsRangeProvider);

    return ListView(
      padding: EdgeInsets.only(
        top: 12,
        bottom: sfNavContentInset(context),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 0, 22, 6),
          child: Row(
            children: [
              SfIconButton(
                icon: Icons.arrow_back_rounded,
                size: 38,
                onPressed: () =>
                    ref.read(shellPageProvider.notifier).go(ShellPage.profile),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Insights',
                  style: AppTextStyles.displayL
                      .copyWith(fontSize: 28, color: sf.ink),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: scheme.surface,
                  borderRadius: AppRadius.brSm,
                  border: Border.all(color: scheme.outline),
                ),
                child: Row(
                  children: [
                    for (var i = 0; i < 3; i++)
                      GestureDetector(
                        onTap: () =>
                            ref.read(analyticsRangeProvider.notifier).update(i),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: i == range
                                ? scheme.primary
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            const ['Week', 'Month', 'Year'][i],
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: i == range
                                  ? (context.isDark
                                      ? AppColors.textPrimary
                                      : Colors.white)
                                  : sf.ink3,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Hero: hours + bar chart
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 14, 22, 14),
          child: SfCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SfEyebrow('Study hours this week', color: sf.ink3),
                          const SizedBox(height: 4),
                          // scaleDown keeps the headline number on one line
                          // when the chip beside it, a long locale string, or
                          // a large text scale squeezes the column.
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(
                                  '23.5',
                                  style: AppTextStyles.displayXL.copyWith(
                                    letterSpacing: -1.5,
                                    height: 1,
                                    color: sf.ink,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'hrs',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: sf.ink3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SfChip(
                      '+18% vs last',
                      tone: SfTone.emerald,
                      icon: Icons.check_rounded,
                      small: true,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const _WeekBars(),
              ],
            ),
          ),
        ),

        // Focus score / cards mastered
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 0, 22, 14),
          // IntrinsicHeight so the two tiles match height; a bare `stretch`
          // Row would inherit the ListView's unbounded height.
          child: IntrinsicHeight(
            child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: SfCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SfEyebrow('Focus score', tracking: 1, color: sf.ink3),
                      const SizedBox(height: 10),
                      SfRing(
                        value: 0.84,
                        size: 72,
                        color: sf.emerald,
                        child: Text(
                          '84',
                          style: TextStyle(
                            fontFamily: AppTextStyles.fontUi,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.6,
                            color: sf.ink,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text('Top 12% of users',
                          style: TextStyle(fontSize: 11, color: sf.ink3)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SfCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SfEyebrow('Cards mastered', tracking: 1, color: sf.ink3),
                      const SizedBox(height: 10),
                      Text(
                        '342',
                        style: AppTextStyles.displayL.copyWith(
                          fontSize: 32,
                          letterSpacing: -1,
                          height: 1,
                          color: sf.ink,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text('+24 this week',
                          style: TextStyle(fontSize: 11, color: sf.ink3)),
                      const SizedBox(height: 10),
                      SfProgress(value: 0.62, color: sf.violet, height: 4),
                    ],
                  ),
                ),
              ),
            ],
            ),
          ),
        ),

        // By subject
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 0, 22, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader('By subject'),
              SfCard(
                child: Column(
                  children: [
                    for (var i = 0;
                        i < demoSubjectBreakdown.length;
                        i++) ...[
                      if (i > 0) Divider(height: 1, color: scheme.outline),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    demoSubjectBreakdown[i].label,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: sf.ink,
                                    ),
                                  ),
                                ),
                                SfMono(demoSubjectBreakdown[i].hours,
                                    size: 12, color: sf.ink2),
                              ],
                            ),
                            const SizedBox(height: 6),
                            SfProgress(
                              value: demoSubjectBreakdown[i].share,
                              color:
                                  demoSubjectBreakdown[i].accent.color(context),
                              height: 5,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),

        // Flow insight
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 0, 22, 14),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: sf.indigoSoft,
              borderRadius: AppRadius.brLg,
              border:
                  Border.all(color: scheme.primary.withValues(alpha: 0.12)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const FlowOrb(size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "You're sharpest at 9–11 AM",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.1,
                          color: scheme.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'You retain 28% more when studying in the morning. '
                        'Want me to schedule hard sessions then?',
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.45,
                          color: sf.ink2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _WeekBars extends StatelessWidget {
  const _WeekBars();

  @override
  Widget build(BuildContext context) {
    final sf = context.sf;
    final scheme = context.scheme;
    final max = demoWeeklyHours.reduce((a, b) => a > b ? a : b);
    const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return SizedBox(
      height: 100,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < demoWeeklyHours.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Expanded(
                    child: FractionallySizedBox(
                      alignment: Alignment.bottomCenter,
                      heightFactor: demoWeeklyHours[i] / max,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: i == 6 ? scheme.primary : null,
                          gradient: i == 6
                              ? null
                              : LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [sf.lavender, sf.indigoSoft],
                                ),
                          boxShadow: i == 6
                              ? AppShadows.resolve(
                                  [
                                    BoxShadow(
                                      color: sf.brand.withValues(alpha: 0.4),
                                      blurRadius: 14,
                                      spreadRadius: -4,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                  Theme.of(context).brightness,
                                )
                              : null,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  SfMono(
                    labels[i],
                    size: 10,
                    color: i == 6 ? scheme.primary : sf.ink3,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
