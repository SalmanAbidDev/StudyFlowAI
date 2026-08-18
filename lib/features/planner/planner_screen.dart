// lib/features/planner/planner_screen.dart
//
// Today's blocks, drag-to-reorder. Long-press a row (or grab the handle) to
// move it; the order is kept in memory only.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/navigation.dart';
import '../../core/theme/theme.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models/study_block.dart';
import '../../data/models/subject.dart';
import '../exams/exams_screen.dart';
import 'planner_view_model.dart';

class PlannerScreen extends ConsumerWidget {
  const PlannerScreen({super.key});

  static const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  /// "May 6 · 4h 15m planned" — the date and the total the blocks add up to,
  /// rather than a figure that has to be kept in step by hand.
  static String _subtitle(DateTime day, List<StudyBlock> blocks) {
    final date = '${_months[day.month - 1]} ${day.day}';
    var minutes = 0;
    for (final block in blocks) {
      final start = block.startsAt;
      final end = block.endsAt;
      if (start == null || end == null) continue;
      minutes += (end.hour * 60 + end.minute) - (start.hour * 60 + start.minute);
    }
    if (minutes <= 0) return '$date · nothing planned';

    final h = minutes ~/ 60;
    final m = minutes % 60;
    final total = h == 0 ? '${m}m' : (m == 0 ? '${h}h' : '${h}h ${m}m');
    return '$date · $total planned';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sf = context.sf;
    final blocks = ref.watch(plannerBlocksProvider);
    final selectedDay = ref.watch(selectedDayProvider);
    // Null while it loads as well as when there is nothing to say, so the
    // banner never flashes in and pushes the list down.
    final note = ref.watch(plannerNoteProvider).value;

    final now = DateTime.now();
    final monday = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
    final exams = ref.watch(upcomingExamsProvider).value ?? const [];
    final examDays = {
      for (final exam in exams)
        if (exam.examDate.difference(monday).inDays.clamp(0, 6) ==
            exam.examDate.difference(monday).inDays)
          exam.examDate.day,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Planner',
                      style: AppTextStyles.displayL
                          .copyWith(fontSize: 28, color: sf.ink),
                    ),
                    Text(
                      _subtitle(ref.watch(selectedDateProvider),
                          blocks.value ?? const []),
                      style: TextStyle(fontSize: 12, color: sf.ink3),
                    ),
                  ],
                ),
              ),
              SfIconButton(
                icon: Icons.auto_awesome_outlined,
                size: 40,
                filled: true,
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Auto-planning needs the AI service'),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Adding a block is a header action, like uploading on
              // Materials. It used to be a full-width dashed button pinned
              // above the nav pill, which put the screen's primary action in
              // its least reachable corner.
              SfIconButton(
                icon: Icons.add_rounded,
                size: 40,
                iconSize: 20,
                filled: true,
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Block editor is not built yet')),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 12),
          child: Row(
            children: [
              for (var i = 0; i < _days.length; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                Expanded(
                  child: _DayCell(
                    label: _days[i],
                    date: monday.add(Duration(days: i)).day,
                    selected: i == selectedDay,
                    // A dot marks a day that has an exam on it.
                    marked: examDays.contains(
                      monday.add(Duration(days: i)).day,
                    ),
                    onTap: () =>
                        ref.read(selectedDayProvider.notifier).update(i),
                  ),
                ),
              ],
            ],
          ),
        ),
        // Absent, not empty, when Flow has nothing to say — see
        // plannerNoteProvider.
        if (note != null) _FlowNote(note: note),
        Expanded(
          child: blocks.when(
            loading: () => const SfLoadingList(rows: 4, height: 68),
            error: (error, _) => SfErrorView(
              error: error,
              onRetry: () => ref.invalidate(plannerBlocksProvider),
            ),
            data: (items) => items.isEmpty
                // Offset above the nav pill so it reads as centred in the
                // space that is actually visible.
                ? Padding(
                    padding: EdgeInsets.only(
                      bottom: sfNavContentInset(context, extra: 0),
                    ),
                    child: const SfEmptyView(
                      icon: Icons.event_note_outlined,
                      title: 'Nothing planned',
                      body: 'Tap ＋ to add a focus block for this day.',
                    ),
                  )
                : ReorderableListView.builder(
                    // The list now runs to the bottom of the screen — there is
                    // no pinned footer left to clear the nav pill for it.
                    padding: EdgeInsets.fromLTRB(
                        22, 0, 22, sfNavContentInset(context)),
                    buildDefaultDragHandles: false,
                    itemCount: items.length,
                    onReorderItem:
                        ref.read(plannerBlocksProvider.notifier).reorder,
                    proxyDecorator: (child, index, animation) => Material(
                      color: Colors.transparent,
                      child: Transform.scale(scale: 1.02, child: child),
                    ),
                    itemBuilder: (context, i) {
                      final block = items[i];
                      return Padding(
                        key: ValueKey(block.id),
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _BlockRow(block: block, index: i),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }
}

/// Flow's line under the week strip. Taps through to Exams, which is where
/// both of its messages point — either the exam it is counting down to, or the
/// screen where you add the one it is asking for.
class _FlowNote extends StatelessWidget {
  const _FlowNote({required this.note});

  final PlannerNote note;

  @override
  Widget build(BuildContext context) {
    final sf = context.sf;
    final scheme = context.scheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 0, 22, 12),
      child: GestureDetector(
        onTap: () => Navigator.of(context).push(
          sfRoute(builder: (_) => const ExamsScreen()),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: AppRadius.brMd,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [sf.lavenderSoft, sf.indigoSoft],
            ),
          ),
          child: Row(
            children: [
              const FlowOrb(size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    text: note.lead,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                      color: scheme.primary,
                    ),
                    children: [
                      TextSpan(
                        text: note.detail,
                        style: TextStyle(color: sf.ink),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded,
                  size: 16, color: scheme.primary),
            ],
          ),
        ),
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.label,
    required this.date,
    required this.selected,
    required this.marked,
    required this.onTap,
  });

  final String label;
  final int date;
  final bool selected;
  final bool marked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final sf = context.sf;
    final scheme = context.scheme;
    final onSelected =
        context.isDark ? AppColors.textPrimary : Colors.white;
    final fg = selected ? onSelected : sf.ink2;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
        decoration: BoxDecoration(
          color: selected ? scheme.primary : scheme.surface,
          borderRadius: AppRadius.brMd,
          border: Border.all(
            color: selected ? scheme.primary : scheme.outline,
          ),
        ),
        child: Column(
          children: [
            SfMono(
              label.toUpperCase(),
              size: 10,
              color: fg.withValues(alpha: selected ? 0.85 : 0.6),
            ),
            const SizedBox(height: 2),
            Text(
              '$date',
              style: TextStyle(
                fontFamily: AppTextStyles.fontUi,
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: fg,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected
                    ? onSelected
                    : marked
                        ? sf.coral
                        : Colors.transparent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BlockRow extends StatelessWidget {
  const _BlockRow({required this.block, required this.index});

  final StudyBlock block;
  final int index;

  @override
  Widget build(BuildContext context) {
    final sf = context.sf;
    final scheme = context.scheme;
    final accent = block.accent.color(context);

    // The subject stripe is a child rather than a `Border` side: a
    // BoxDecoration with a borderRadius requires a *uniform* border, so the
    // accent edge is drawn inside a clipped row instead.
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: scheme.outline),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 4, color: accent),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      SoftIconTile(
                        icon: block.icon,
                        color: accent,
                        width: 36,
                        height: 36,
                        radius: 10,
                        iconSize: 16,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              block.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                letterSpacing: -0.1,
                                color: sf.ink,
                              ),
                            ),
                            const SizedBox(height: 2),
                            SfMono('${block.window}  ·  ${block.duration}',
                                color: sf.ink3),
                          ],
                        ),
                      ),
                      ReorderableDragStartListener(
                        index: index,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Icon(Icons.drag_indicator_rounded,
                              size: 20, color: sf.ink4),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

