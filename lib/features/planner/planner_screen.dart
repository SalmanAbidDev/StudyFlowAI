// lib/features/planner/planner_screen.dart
//
// One day at a time, chosen from a strip that scrolls through months.
//
// Blocks are held in **drag order**, not clock order: the times are labels and
// the sequence is yours. That is also why nothing here warns about two blocks
// overlapping — warning that 08:00 and 08:30 collide, while telling you the
// clock does not decide the order, would be the screen contradicting itself.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/navigation.dart';
import '../../core/theme/theme.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models/study_block.dart';
import '../../data/models/subject.dart';
import '../documents/document_screen.dart';
import '../exams/exam_detail_screen.dart';
import '../exams/exams_screen.dart';
import '../exams/exams_view_model.dart';
import '../materials/materials_view_model.dart';
import 'block_editor_screen.dart';
import 'planner_view_model.dart';

/// One day cell plus the gap after it. The strip scrolls by whole cells, so
/// this is the only place the number lives.
const _cellWidth = 54.0;
const _cellGap = 6.0;
const _cellStride = _cellWidth + _cellGap;

/// Tall enough for the cell's three lines at whatever text scale is in force.
///
/// 28 is the fixed part — 8+8 padding, a 1px border either side, the two
/// 2px/3px gaps, and a few pixels of slack. The rest is the three labels at a
/// generous line height, because those are the parts that grow with the scale.
/// The layout sweep is what keeps these numbers honest: a first attempt at a
/// flat 70 overflowed, and a tighter formula still missed by 1.1px.
double _stripHeight(BuildContext context) {
  final scaler = MediaQuery.textScalerOf(context);
  return 28 +
      scaler.scale(10) * 1.5 +
      scaler.scale(17) * 1.5 +
      scaler.scale(11) * 1.5;
}

class PlannerScreen extends ConsumerStatefulWidget {
  const PlannerScreen({super.key});

  @override
  ConsumerState<PlannerScreen> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends ConsumerState<PlannerScreen> {
  static const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  late final ScrollController _strip;

  /// Total days the strip covers, and the index of today within it.
  static int get _dayCount => plannerDaysBack + plannerDaysForward + 1;
  static int get _todayIndex => plannerDaysBack;

  @override
  void initState() {
    super.initState();
    // Opens on today rather than at the start of a range that begins two
    // months ago.
    _strip = ScrollController(
      initialScrollOffset: _offsetFor(_todayIndex),
    );
  }

  @override
  void dispose() {
    _strip.dispose();
    super.dispose();
  }

  /// Puts the given day a little in from the left edge, so the days *around*
  /// it are visible too — centring it would hide everything before it.
  double _offsetFor(int index) =>
      (index * _cellStride - _cellStride * 2).clamp(0, double.infinity);

  DateTime _dateAt(int index) =>
      plannerRangeStart().add(Duration(days: index));

  void _goToToday() {
    ref.read(selectedDateProvider.notifier).update(plannerToday());
    _strip.animateTo(
      _offsetFor(_todayIndex).clamp(0, _strip.position.maxScrollExtent),
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _addBlock() => Navigator.of(context).push(
        sfModalRoute(
          builder: (_) =>
              BlockEditorScreen(day: ref.read(selectedDateProvider)),
        ),
      );

  /// Edit or delete, on a long press. Tapping the row opens what it points at,
  /// so the menu is where the destructive and the fiddly live.
  Future<void> _rowMenu(StudyBlock block) async {
    final action = await showSfSheet<_BlockAction>(
      context,
      (_) => _BlockMenuSheet(block: block),
    );
    if (action == null || !mounted) return;

    if (action == _BlockAction.edit) {
      await Navigator.of(context).push(
        sfModalRoute(
          builder: (_) => BlockEditorScreen(
            block: block,
            day: ref.read(selectedDateProvider),
          ),
        ),
      );
      return;
    }

    final confirmed = await showSfSheet<bool>(
      context,
      (_) => SfConfirmSheet(
        icon: Icons.delete_outline_rounded,
        title: 'Delete this block?',
        body: '"${block.title}" will be removed from this day. Anything it '
            'points at stays in your library.',
        confirmLabel: 'Delete',
      ),
    );
    if (confirmed != true) return;
    await ref.read(deleteBlockProvider)(block.id);
  }

  /// Opens whatever the block is for. Untargeted blocks do nothing — there is
  /// nowhere to go, and a row that pretends to be tappable is worse.
  void _openTarget(StudyBlock block) {
    if (block.materialId != null) {
      ref.read(selectedMaterialProvider.notifier).update(block.materialId!);
      Navigator.of(context).push(
        sfRoute(builder: (_) => const DocumentScreen()),
      );
    } else if (block.examId != null) {
      ref.read(selectedExamProvider.notifier).update(block.examId!);
      Navigator.of(context).push(
        sfRoute(builder: (_) => const ExamDetailScreen()),
      );
    }
  }

  Future<void> _copyDay(List<StudyBlock> blocks) async {
    final targets = await showSfSheet<List<DateTime>>(
      context,
      (_) => _CopyDaySheet(
        from: ref.read(selectedDateProvider),
        count: blocks.length,
      ),
    );
    if (targets == null || targets.isEmpty || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    await ref.read(copyDayProvider)(targets);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          'Copied ${blocks.length} '
          '${blocks.length == 1 ? 'block' : 'blocks'} to '
          '${targets.length} ${targets.length == 1 ? 'day' : 'days'}.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sf = context.sf;
    final blocks = ref.watch(plannerBlocksProvider);
    final selected = ref.watch(selectedDateProvider);
    final counts = ref.watch(blockCountsProvider).value ?? const {};
    final note = ref.watch(plannerNoteProvider).value;

    final examDays = {
      for (final exam in ref.watch(upcomingExamsProvider).value ?? const [])
        DateTime(exam.examDate.year, exam.examDate.month, exam.examDate.day),
    };

    final today = plannerToday();
    final isToday = selected == today;

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
                      '${_months[selected.month - 1]} ${selected.day} · '
                      '${daySummary(blocks.value ?? const [])}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: sf.ink3),
                    ),
                  ],
                ),
              ),
              // Only worth offering when you are somewhere else.
              if (!isToday) ...[
                GestureDetector(
                  onTap: _goToToday,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 8),
                    child: Text(
                      'Today',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: context.scheme.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 2),
              ],
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
                onPressed: _addBlock,
              ),
            ],
          ),
        ),

        // The strip: continuous days, no week boundaries. Bounded to the range
        // the counts were loaded for — a cell beyond it would be claiming
        // "nothing planned" about a day nobody asked the database about.
        SizedBox(
          // A horizontal list has to be told its cross-axis extent, so the
          // cell cannot simply size to its content. Derived from the text
          // scaler rather than hard-coded: at scale 1.3 a fixed 70 overflowed
          // the cell by every pixel the larger digits added.
          height: _stripHeight(context),
          child: ListView.builder(
            controller: _strip,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 22),
            itemCount: _dayCount,
            itemBuilder: (context, i) {
              final date = _dateAt(i);
              return Padding(
                padding: const EdgeInsets.only(right: _cellGap),
                child: SizedBox(
                  width: _cellWidth,
                  child: _DayCell(
                    label: _days[date.weekday - 1],
                    date: date.day,
                    count: counts[date] ?? 0,
                    selected: date == selected,
                    isToday: date == today,
                    hasExam: examDays.contains(date),
                    onTap: () =>
                        ref.read(selectedDateProvider.notifier).update(date),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),

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
                    padding: EdgeInsets.fromLTRB(
                        22, 0, 22, sfNavContentInset(context)),
                    buildDefaultDragHandles: false,
                    // One past the end for the copy-day row, which must not be
                    // draggable and is not a block.
                    itemCount: items.length + 1,
                    onReorderItem:
                        ref.read(plannerBlocksProvider.notifier).reorder,
                    proxyDecorator: (child, index, animation) => Material(
                      color: Colors.transparent,
                      child: Transform.scale(scale: 1.02, child: child),
                    ),
                    itemBuilder: (context, i) {
                      if (i == items.length) {
                        return Padding(
                          key: const ValueKey('copy-day'),
                          padding: const EdgeInsets.only(top: 4),
                          child: _CopyDayRow(onTap: () => _copyDay(items)),
                        );
                      }
                      final block = items[i];
                      return Padding(
                        key: ValueKey(block.id),
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _BlockRow(
                          block: block,
                          index: i,
                          onOpen: () => _openTarget(block),
                          onMenu: () => _rowMenu(block),
                        ),
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
    required this.count,
    required this.selected,
    required this.isToday,
    required this.hasExam,
    required this.onTap,
  });

  final String label;
  final int date;
  final int count;
  final bool selected;
  final bool isToday;
  final bool hasExam;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final sf = context.sf;
    final scheme = context.scheme;
    final onSelected = context.isDark ? AppColors.textPrimary : Colors.white;
    final fg = selected ? onSelected : sf.ink2;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
        decoration: BoxDecoration(
          color: selected ? scheme.primary : scheme.surface,
          borderRadius: AppRadius.brMd,
          border: Border.all(
            color: selected
                ? scheme.primary
                // Today is outlined rather than filled, so it stays findable
                // once you have scrolled somewhere else and selected a
                // different day.
                : isToday
                    ? scheme.primary
                    : scheme.outline,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
            const SizedBox(height: 3),
            // How much is planned, and whether an exam lands here. A day with
            // neither says nothing rather than showing a zero.
            SizedBox(
              height: MediaQuery.textScalerOf(context).scale(11) * 1.5,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (count > 0)
                    Text(
                      '$count',
                      style: TextStyle(
                        fontFamily: AppTextStyles.fontUi,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: selected
                            ? onSelected.withValues(alpha: 0.9)
                            : scheme.primary,
                      ),
                    ),
                  if (count > 0 && hasExam) const SizedBox(width: 3),
                  if (hasExam)
                    Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: selected ? onSelected : sf.coral,
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

class _BlockRow extends StatelessWidget {
  const _BlockRow({
    required this.block,
    required this.index,
    required this.onOpen,
    required this.onMenu,
  });

  final StudyBlock block;
  final int index;
  final VoidCallback onOpen;
  final VoidCallback onMenu;

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
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            // Only tappable when there is somewhere to go. A row that
            // highlights and then does nothing is worse than one that does not
            // highlight.
            onTap: block.isLinked ? onOpen : null,
            onLongPress: onMenu,
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
                          // No tick here. Completing a block is something you
                          // do to *today*, on Home; the Planner is where you
                          // arrange days you are not in. A done block still
                          // reads as done — struck through, below.
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
                                    color: block.done ? sf.ink3 : sf.ink,
                                    decoration: block.done
                                        ? TextDecoration.lineThrough
                                        : null,
                                    decorationColor: sf.ink3,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                SfMono(block.schedule, color: sf.ink3),
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
        ),
      ),
    );
  }
}

class _CopyDayRow extends StatelessWidget {
  const _CopyDayRow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final sf = context.sf;

    return SfCard(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      onTap: onTap,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.copy_all_outlined, size: 15, color: sf.ink3),
          const SizedBox(width: 8),
          Text(
            'Copy this day…',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: sf.ink3,
            ),
          ),
        ],
      ),
    );
  }
}

enum _BlockAction { edit, delete }

class _BlockMenuSheet extends StatelessWidget {
  const _BlockMenuSheet({required this.block});

  final StudyBlock block;

  @override
  Widget build(BuildContext context) {
    final sf = context.sf;

    return SfSheetShell(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 14),
            child: Text(
              block.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.heading
                  .copyWith(fontSize: 18, letterSpacing: -0.4, color: sf.ink),
            ),
          ),
          _SheetAction(
            icon: Icons.edit_outlined,
            label: 'Edit',
            onTap: () => Navigator.of(context).pop(_BlockAction.edit),
          ),
          const SizedBox(height: 8),
          _SheetAction(
            icon: Icons.delete_outline_rounded,
            label: 'Delete',
            destructive: true,
            onTap: () => Navigator.of(context).pop(_BlockAction.delete),
          ),
        ],
      ),
    );
  }
}

class _SheetAction extends StatelessWidget {
  const _SheetAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final sf = context.sf;
    final scheme = context.scheme;
    final tint = destructive ? sf.coralInk : sf.ink;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: AppRadius.brLg,
        border: Border.all(color: scheme.outline),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: AppRadius.brLg,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.brLg,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Icon(icon, size: 20, color: tint),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: AppTextStyles.fontUi,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                    color: tint,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Ticks the days to duplicate this one onto. Pops the chosen dates.
class _CopyDaySheet extends StatefulWidget {
  const _CopyDaySheet({required this.from, required this.count});

  final DateTime from;
  final int count;

  @override
  State<_CopyDaySheet> createState() => _CopyDaySheetState();
}

class _CopyDaySheetState extends State<_CopyDaySheet> {
  final _picked = <DateTime>{};

  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  @override
  Widget build(BuildContext context) {
    final sf = context.sf;
    // The next fortnight, which is as far as anyone copies a day by hand.
    final options = [
      for (var i = 1; i <= 14; i++) widget.from.add(Duration(days: i)),
    ];

    return SfSheetShell(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Copy this day',
                  style: AppTextStyles.heading.copyWith(
                    fontSize: 20,
                    letterSpacing: -0.5,
                    color: sf.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${widget.count} ${widget.count == 1 ? 'block' : 'blocks'}, '
                  'with their times and links. They arrive unticked.',
                  style: TextStyle(fontSize: 13, height: 1.35, color: sf.ink3),
                ),
              ],
            ),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final day in options)
                SfSelectChip(
                  label: '${_weekdays[day.weekday - 1]} '
                      '${_months[day.month - 1]} ${day.day}',
                  selected: _picked.contains(day),
                  onTap: () => setState(() {
                    if (!_picked.remove(day)) _picked.add(day);
                  }),
                ),
            ],
          ),
          const SizedBox(height: 18),
          SfButton(
            _picked.isEmpty
                ? 'Pick a day'
                : 'Copy to ${_picked.length} '
                    '${_picked.length == 1 ? 'day' : 'days'}',
            size: SfButtonSize.lg,
            expand: true,
            onPressed: _picked.isEmpty
                ? null
                : () => Navigator.of(context).pop(_picked.toList()..sort()),
          ),
        ],
      ),
    );
  }
}
