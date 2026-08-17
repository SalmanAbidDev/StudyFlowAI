// lib/features/profile/achievements_screen.dart
//
// The full badge catalogue, earned and not. A pushed route — it has a back
// arrow, so it is not a shell tab (§3.2 of CluadeWork.md).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/theme.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models/achievement.dart';
import '../home/home_view_model.dart';

class AchievementsScreen extends ConsumerWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sf = context.sf;
    final async = ref.watch(achievementsProvider);
    final achievements = async.value ?? const <Achievement>[];
    final earned = achievements.where((a) => a.earned).length;
    final accents = [sf.coral, sf.amber, sf.violet, context.scheme.primary];

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
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Achievements',
                          style: AppTextStyles.displayL
                              .copyWith(fontSize: 28, color: sf.ink),
                        ),
                        Text(
                          '$earned of ${achievements.length} earned',
                          style: TextStyle(fontSize: 12, color: sf.ink3),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: async.when(
                loading: () => const SfLoadingList(rows: 5, height: 72),
                error: (error, _) => SfErrorView(
                  error: error,
                  onRetry: () => ref.invalidate(achievementsProvider),
                ),
                data: (_) => GridView.builder(
                  padding: const EdgeInsets.fromLTRB(22, 8, 22, 24),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    // An explicit height rather than an aspect ratio, and one
                    // that grows with the text scale. A grid cell is a fixed
                    // box: at scale 1.3 a ratio tuned for 1.0 overflows, which
                    // is the trap in §7 of CluadeWork.md.
                    mainAxisExtent: 172 + (_textScale(context) - 1) * 90,
                  ),
                  itemCount: achievements.length,
                  itemBuilder: (context, i) => _AchievementCard(
                    achievement: achievements[i],
                    color: accents[achievements[i].accent],
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

/// How much larger than normal the user's text is, used to size the grid
/// cells. `textScalerOf` has no direct "factor" getter, so scale a known size
/// and compare.
double _textScale(BuildContext context) =>
    MediaQuery.textScalerOf(context).scale(14) / 14;

class _AchievementCard extends StatelessWidget {
  const _AchievementCard({required this.achievement, required this.color});

  final Achievement achievement;
  final Color color;

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  @override
  Widget build(BuildContext context) {
    final sf = context.sf;
    final scheme = context.scheme;
    final earned = achievement.earned;

    return Opacity(
      // Locked badges stay legible rather than hidden — they are the point of
      // the screen, not clutter.
      opacity: earned ? 1 : 0.6,
      child: SfCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              width: 52,
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: earned
                    ? LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [color, color.withValues(alpha: 0.7)],
                      )
                    : null,
                color: earned ? null : scheme.surfaceContainerHigh,
                boxShadow: earned
                    ? AppShadows.resolve(
                        [
                          BoxShadow(
                            color: color.withValues(alpha: 0.33),
                            blurRadius: 16,
                            spreadRadius: -4,
                            offset: const Offset(0, 6),
                          ),
                        ],
                        Theme.of(context).brightness,
                      )
                    : null,
              ),
              child: Icon(
                earned ? achievement.icon : Icons.lock_outline_rounded,
                size: 24,
                color: earned ? Colors.white : sf.ink3,
              ),
            ),
            // Takes the slack between the badge and the status chip, so the
            // chip stays pinned to the bottom of every card regardless of how
            // many lines the name and detail need.
            Flexible(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      achievement.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: AppTextStyles.fontUi,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                        color: sf.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Flexible(
                      child: Text(
                        achievement.detail,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          height: 1.3,
                          color: sf.ink3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (earned)
              SfChip(
                _earnedLabel(achievement.earnedAt!),
                tone: SfTone.emerald,
                icon: Icons.check_rounded,
                small: true,
              )
            else
              const SfChip('Locked', small: true),
          ],
        ),
      ),
    );
  }

  static String _earnedLabel(DateTime at) {
    final local = at.toLocal();
    return '${_months[local.month - 1]} ${local.day}';
  }
}
