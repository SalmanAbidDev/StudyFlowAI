// lib/screens/home_screen.dart
//
// The daily dashboard: streak, quick actions, resume card, today's tasks,
// exam countdown, and recent materials.

import 'package:flutter/material.dart';

import '../theme/theme.dart';
import '../widgets/widgets.dart';
import 'app_shell.dart';
import 'chat_screen.dart';
import 'flashcards_screen.dart';
import 'quiz_screen.dart';
import 'summaries_screen.dart';
import 'upload_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _done = <int>{0};

  @override
  Widget build(BuildContext context) {
    final sf = context.sf;

    return ListView(
      padding: const EdgeInsets.only(
        top: 14,
        bottom: kFloatingNavHeight + 24,
      ),
      children: [
        _greeting(context),
        const SizedBox(height: 18),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 22),
          child: _StreakHero(),
        ),
        const SizedBox(height: 16),
        _quickActions(context),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader('Pick up where you left off'),
              _ResumeCard(
                onResume: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SummariesScreen()),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeader(
                'Today',
                subtitle: '3 tasks · 2h 15m',
                action: 'See all',
                onAction: () =>
                    AppShellScope.of(context).go(ShellPage.planner),
              ),
              ..._tasks(context),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          // IntrinsicHeight so the pair match height; a bare `stretch` Row
          // would inherit the ListView's unbounded height.
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _NextExamCard(
                    onTap: () =>
                        AppShellScope.of(context).go(ShellPage.exams),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _FlowSuggestionCard(
                    onStart: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ChatScreen()),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: SectionHeader(
            'Recent materials',
            action: 'All',
            onAction: () => AppShellScope.of(context).go(ShellPage.materials),
          ),
        ),
        // Sized by its content rather than a fixed height: the card is two
        // text lines tall, so any font-metric or text-scale difference would
        // overflow a hard-coded strip height.
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
              for (final d in <({String title, String meta, Color color, IconData icon})>[
                (
                  title: 'Stereochem.pdf',
                  meta: '12 pages',
                  color: sf.coral,
                  icon: Icons.science_outlined
                ),
                (
                  title: 'Macro lec 7',
                  meta: '8 pages',
                  color: context.scheme.primary,
                  icon: Icons.show_chart_rounded
                ),
                (
                  title: 'Linear Alg',
                  meta: '24 pages',
                  color: sf.emerald,
                  icon: Icons.menu_book_outlined
                ),
              ])
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: SizedBox(
                    width: 140,
                    child: SfCard(
                      padding: const EdgeInsets.all(14),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const SummariesScreen()),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SoftIconTile(
                            icon: d.icon,
                            color: d.color,
                            width: 36,
                            height: 44,
                            radius: 8,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            d.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.1,
                              color: sf.ink,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            d.meta,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 11, color: sf.ink3),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Greeting ───────────────────────────────────────────────────────────

  Widget _greeting(BuildContext context) {
    final sf = context.sf;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tuesday, May 6',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: sf.ink3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Morning, Alex 👋',
                  style: AppTextStyles.heading.copyWith(
                    fontSize: 26,
                    letterSpacing: -0.8,
                    color: sf.ink,
                  ),
                ),
              ],
            ),
          ),
          SfIconButton(
            icon: Icons.notifications_none_rounded,
            size: 40,
            badge: true,
            onPressed: () {},
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => AppShellScope.of(context).go(ShellPage.profile),
            child: SfAvatar(initials: 'AM', size: 40),
          ),
        ],
      ),
    );
  }

  // ── Quick actions ──────────────────────────────────────────────────────

  Widget _quickActions(BuildContext context) {
    final sf = context.sf;
    final actions = <({
      IconData icon,
      String label,
      Color color,
      Color background,
      VoidCallback onTap
    })>[
      (
        icon: Icons.file_upload_outlined,
        label: 'Upload',
        color: context.scheme.primary,
        background: sf.indigoSoft,
        onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const UploadScreen()),
            ),
      ),
      (
        icon: Icons.style_outlined,
        label: 'Flashcards',
        color: sf.violetInk,
        background: sf.lavenderSoft,
        onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const FlashcardsScreen()),
            ),
      ),
      (
        icon: Icons.help_outline_rounded,
        label: 'Quiz',
        color: sf.coralInk,
        background: sf.coralSoft,
        onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const QuizScreen()),
            ),
      ),
      (
        icon: Icons.auto_awesome_outlined,
        label: 'Ask Flow',
        color: sf.emeraldInk,
        background: sf.emeraldSoft,
        onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ChatScreen()),
            ),
      ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Row(
        children: [
          for (var i = 0; i < actions.length; i++) ...[
            if (i > 0) const SizedBox(width: 10),
            Expanded(
              child: SfCard(
                radius: AppRadius.md + 2,
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                onTap: actions[i].onTap,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SoftIconTile(
                      icon: actions[i].icon,
                      color: actions[i].color,
                      background: actions[i].background,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      actions[i].label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.1,
                        color: sf.ink,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Today's tasks ──────────────────────────────────────────────────────

  List<Widget> _tasks(BuildContext context) {
    final sf = context.sf;
    final rows = <({String title, String meta, Color color})>[
      (
        title: 'Review macro flashcards',
        meta: '20 cards · 15m',
        color: sf.emerald
      ),
      (
        title: 'Read Ch.4 stereochemistry',
        meta: '11:00 AM · 45m',
        color: context.scheme.primary
      ),
      (title: 'Practice MCAT bio quiz', meta: '3:30 PM · 1h', color: sf.coral),
    ];

    return [
      for (var i = 0; i < rows.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: SfCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            onTap: () => setState(
              () => _done.contains(i) ? _done.remove(i) : _done.add(i),
            ),
            child: Row(
              children: [
                _Checkbox(checked: _done.contains(i), color: rows[i].color),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        rows[i].title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _done.contains(i) ? sf.ink3 : sf.ink,
                          decoration: _done.contains(i)
                              ? TextDecoration.lineThrough
                              : null,
                          decorationColor: sf.ink3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(rows[i].meta,
                          style: TextStyle(fontSize: 11, color: sf.ink3)),
                    ],
                  ),
                ),
                Container(
                  width: 4,
                  height: 36,
                  decoration: BoxDecoration(
                    color: rows[i].color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ),
          ),
        ),
    ];
  }
}

class _Checkbox extends StatelessWidget {
  const _Checkbox({required this.checked, required this.color});

  final bool checked;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: checked ? color : Colors.transparent,
        border: Border.all(
          color: checked ? color : context.scheme.outlineVariant,
          width: 2,
        ),
      ),
      child: checked
          ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
          : null,
    );
  }
}

// ─── Streak hero ──────────────────────────────────────────────────────────

class _StreakHero extends StatelessWidget {
  const _StreakHero();

  @override
  Widget build(BuildContext context) {
    final sf = context.sf;

    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: sf.brandSweep,
          ),
          boxShadow: [
            BoxShadow(
              color: sf.brand.withValues(alpha: 0.5),
              blurRadius: 32,
              spreadRadius: -12,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              top: -70,
              right: -50,
              child: _Bubble(size: 180, opacity: 0.08),
            ),
            const Positioned(
              bottom: -60,
              left: -40,
              child: _Bubble(size: 120, opacity: 0.06),
            ),
            Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.local_fire_department_rounded,
                                  size: 15, color: sf.streak),
                              const SizedBox(width: 6),
                              SfEyebrow(
                                'Streak',
                                size: 10,
                                tracking: 1,
                                color: Colors.white.withValues(alpha: 0.7),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            '12 days',
                            style: TextStyle(
                              fontFamily: AppTextStyles.fontUi,
                              fontSize: 38,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -1.5,
                              height: 1,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "You're on fire — beat your record at 17 days.",
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.35,
                              color: Colors.white.withValues(alpha: 0.75),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    SfRing(
                      value: 0.7,
                      size: 66,
                      stroke: 5,
                      color: sf.streak,
                      track: Colors.white.withValues(alpha: 0.15),
                      child: const Text(
                        '70%',
                        style: TextStyle(
                          fontFamily: AppTextStyles.fontMono,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    for (var i = 0; i < 7; i++)
                      Expanded(
                        child: Column(
                          children: [
                            Container(
                              width: 22,
                              height: 22,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                color: i < 5
                                    ? sf.streak
                                    : Colors.white.withValues(alpha: 0.15),
                              ),
                              child: i < 5
                                  ? Icon(Icons.check_rounded,
                                      size: 13, color: sf.brand)
                                  : i == 5
                                      ? Container(
                                          width: 6,
                                          height: 6,
                                          decoration: const BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: Colors.white,
                                          ),
                                        )
                                      : null,
                            ),
                            const SizedBox(height: 4),
                            SfMono(
                              const ['M', 'T', 'W', 'T', 'F', 'S', 'S'][i],
                              size: 10,
                              color: Colors.white.withValues(alpha: 0.6),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Resume card ──────────────────────────────────────────────────────────

class _ResumeCard extends StatelessWidget {
  const _ResumeCard({required this.onResume});

  final VoidCallback onResume;

  @override
  Widget build(BuildContext context) {
    final sf = context.sf;
    final scheme = context.scheme;

    return SfCard(
      padding: EdgeInsets.zero,
      clip: true,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 90,
              alignment: Alignment.center,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [sf.indigoSoft, sf.lavenderSoft],
                ),
              ),
              child: Container(
                width: 60,
                height: 76,
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: scheme.surface,
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: AppShadows.resolve(
                      AppShadows.sm, Theme.of(context).brightness),
                ),
                child: Stack(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final w in [0.70, 0.85, 0.60, 0.78])
                          Padding(
                            padding: const EdgeInsets.only(bottom: 3),
                            child: FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: w,
                              child: Container(
                                height: 2,
                                color: scheme.outline,
                              ),
                            ),
                          ),
                      ],
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: SfMono('p.42', size: 7, color: sf.ink4),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SfChip('Organic Chemistry', small: true),
                    const SizedBox(height: 8),
                    Text(
                      'Ch 4: Stereochemistry & Chirality',
                      style: TextStyle(
                        fontFamily: AppTextStyles.fontUi,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                        height: 1.2,
                        color: sf.ink,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Expanded(child: SfProgress(value: 0.42)),
                        const SizedBox(width: 8),
                        SfMono('42%', color: sf.ink3),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            '23 min left',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 11, color: sf.ink3),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SfButton(
                          'Resume',
                          size: SfButtonSize.sm,
                          trailingIcon: Icons.play_arrow_rounded,
                          onPressed: onResume,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Next exam / Flow suggestion ──────────────────────────────────────────

class _NextExamCard extends StatelessWidget {
  const _NextExamCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final sf = context.sf;

    return SfCard(
      onTap: onTap,
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomRight,
        colors: [sf.coralSoft, context.scheme.surface],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.my_location_rounded, size: 14, color: sf.coral),
              const SizedBox(width: 6),
              SfEyebrow('Next exam', size: 10, color: sf.coralInk),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '9d',
            style: AppTextStyles.displayL.copyWith(
              fontSize: 32,
              letterSpacing: -1.2,
              height: 1,
              color: sf.ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Organic Chem Final',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: sf.ink2,
            ),
          ),
          const SizedBox(height: 10),
          SfProgress(value: 0.62, color: sf.coral),
          const SizedBox(height: 4),
          Text('62% prepared',
              style: TextStyle(fontSize: 10, color: sf.ink3)),
        ],
      ),
    );
  }
}

class _FlowSuggestionCard extends StatelessWidget {
  const _FlowSuggestionCard({required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final sf = context.sf;

    return SfCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const FlowOrb(size: 14),
              const SizedBox(width: 6),
              SfEyebrow('Flow suggests',
                  size: 10, color: context.scheme.primary),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Review enantiomers — you scored 60% last time.',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              height: 1.35,
              color: sf.ink,
            ),
          ),
          const SizedBox(height: 10),
          SfButton(
            'Start review',
            variant: SfButtonVariant.soft,
            size: SfButtonSize.sm,
            trailingIcon: Icons.arrow_forward_rounded,
            onPressed: onStart,
          ),
        ],
      ),
    );
  }
}

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
