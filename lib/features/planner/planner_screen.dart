// lib/features/planner/planner_screen.dart
//
// Today's blocks, drag-to-reorder. Long-press a row (or grab the handle) to
// move it; the order is kept in memory only.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/theme.dart';
import '../../core/widgets/widgets.dart';
import '../../data/demo_content.dart';
import '../shell/shell_view_model.dart';
import 'planner_view_model.dart';

class PlannerScreen extends ConsumerWidget {
  const PlannerScreen({super.key});

  static const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sf = context.sf;
    final blocks = ref.watch(plannerBlocksProvider);
    final selectedDay = ref.watch(selectedDayProvider);

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
                      'May 6 · 4h 15m planned today',
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
                    date: 4 + i,
                    selected: i == selectedDay,
                    marked: i == 3 || i == 5,
                    onTap: () =>
                        ref.read(selectedDayProvider.notifier).update(i),
                  ),
                ),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 0, 22, 12),
          child: GestureDetector(
            onTap: () => ref.read(shellPageProvider.notifier).go(ShellPage.exams),
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
                        text: 'Flow planned your day ',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          height: 1.35,
                          color: context.scheme.primary,
                        ),
                        children: [
                          TextSpan(
                            text: 'around your Organic Chem final in 9d.',
                            style: TextStyle(color: sf.ink),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.chevron_right_rounded,
                      size: 16, color: context.scheme.primary),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: ReorderableListView.builder(
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 8),
            buildDefaultDragHandles: false,
            itemCount: blocks.length,
            onReorderItem: ref.read(plannerBlocksProvider.notifier).reorder,
            proxyDecorator: (child, index, animation) => Material(
              color: Colors.transparent,
              child: Transform.scale(scale: 1.02, child: child),
            ),
            itemBuilder: (context, i) {
              final block = blocks[i];
              return Padding(
                key: ValueKey(block.id),
                padding: const EdgeInsets.only(bottom: 8),
                child: _BlockRow(block: block, index: i),
              );
            },
          ),
        ),
        Padding(
          // A pinned footer rather than scroll content, so it has to clear the
          // pill on its own.
          padding: EdgeInsets.fromLTRB(
              22, 0, 22, sfNavContentInset(context, extra: 8)),
          child: _AddBlockButton(
            onTap: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Block editor is not built yet')),
            ),
          ),
        ),
      ],
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

class _AddBlockButton extends StatelessWidget {
  const _AddBlockButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final sf = context.sf;
    return GestureDetector(
      onTap: onTap,
      child: DashedBorderBox(
        color: context.scheme.outlineVariant,
        radius: 16,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_rounded, size: 16, color: sf.ink3),
              const SizedBox(width: 6),
              Text(
                'Add a study block',
                style: TextStyle(
                  fontFamily: AppTextStyles.fontUi,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: sf.ink3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
