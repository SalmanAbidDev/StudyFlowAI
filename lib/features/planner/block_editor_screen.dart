// lib/features/planner/block_editor_screen.dart
//
// Add or edit one study block. Same screen for both, like the exam editor.
//
// A block can point at a document, at an exam, or at neither — the third is a
// real choice rather than a fallback, because plenty of study time is "past
// paper" or "office hours", which are in nobody's library.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/theme.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models/exam.dart';
import '../../data/models/study_block.dart';
import '../../data/models/study_material.dart';
import '../../data/models/subject.dart';
import '../exams/exams_view_model.dart';
import '../materials/material_browser.dart';
import '../materials/materials_view_model.dart';
import 'planner_view_model.dart';

/// The lengths worth one tap. Anything else goes through "Custom".
const _presetMinutes = [25, 30, 45, 60, 90, 120];

class BlockEditorScreen extends ConsumerStatefulWidget {
  const BlockEditorScreen({super.key, this.block, required this.day});

  /// Null to add, a block to edit.
  final StudyBlock? block;

  /// The day being planned — the strip's selection, so ＋ lands where you are.
  final DateTime day;

  @override
  ConsumerState<BlockEditorScreen> createState() => _BlockEditorScreenState();
}

class _BlockEditorScreenState extends ConsumerState<BlockEditorScreen> {
  final _title = TextEditingController();
  var _saving = false;

  @override
  void initState() {
    super.initState();
    _title.text = widget.block?.title ?? '';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref
          .read(blockEditorProvider.notifier)
          .start(block: widget.block, day: widget.day);
    });
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  /// Keeps the field in step when linking overwrites the title.
  void _syncTitle(String value) {
    if (_title.text == value) return;
    _title.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }

  Future<void> _pickMaterial() async {
    final picked = await showSfSheet<StudyMaterial>(
      context,
      (_) => const _MaterialSheet(),
    );
    if (picked == null) return;
    ref.read(blockEditorProvider.notifier).link(
          target: BlockTarget.material,
          materialId: picked.id,
          subjectId: picked.subjectId,
          suggestedTitle: picked.title,
        );
  }

  Future<void> _pickExam() async {
    final picked = await showSfSheet<Exam>(context, (_) => const _ExamSheet());
    if (picked == null) return;
    ref.read(blockEditorProvider.notifier).link(
          target: BlockTarget.exam,
          examId: picked.id,
          subjectId: picked.subjectId,
          suggestedTitle: 'Revise · ${picked.title}',
        );
  }

  Future<void> _pickStart(TimeOfDay? current) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: current ?? const TimeOfDay(hour: 9, minute: 0),
    );
    if (picked == null) return;
    final editor = ref.read(blockEditorProvider.notifier);
    editor.startsAt(picked);
    // A start with no length is a block of zero minutes, which reads as
    // untimed. Give it one so picking a time is enough on its own.
    if (ref.read(blockEditorProvider).minutes == 0) editor.minutes(60);
  }

  Future<void> _pickCustomLength(int current) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current ~/ 60, minute: current % 60),
      helpText: 'How long?',
      builder: (context, child) => MediaQuery(
        // A duration is hours and minutes, not a time of day — the 24h dial
        // is the only one that reads correctly for it.
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked == null) return;
    ref
        .read(blockEditorProvider.notifier)
        .minutes(picked.hour * 60 + picked.minute);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(saveBlockProvider)(blockId: widget.block?.id);
      navigator.pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(
        SnackBar(content: Text("Couldn't save that block. $error")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final sf = context.sf;
    final draft = ref.watch(blockEditorProvider);
    final editing = widget.block != null;

    ref.listen(blockEditorProvider, (_, next) => _syncTitle(next.title));

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            SfModalHeader(title: editing ? 'Edit Study Block' : 'New Study Block'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(22, 0, 22, 24),
                children: [
                  SfEyebrow('What are you working on', color: sf.ink3),
                  const SizedBox(height: 4),
                  Text(
                    'Every block points at a material or an exam, so it can be '
                    'opened from the plan.',
                    style: TextStyle(fontSize: 12, height: 1.35, color: sf.ink3),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _TargetTile(
                          icon: Icons.description_outlined,
                          label: 'Material',
                          selected: draft.target == BlockTarget.material,
                          onTap: _pickMaterial,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _TargetTile(
                          icon: Icons.event_available_outlined,
                          label: 'An exam',
                          selected: draft.target == BlockTarget.exam,
                          onTap: _pickExam,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SfField(
                    controller: _title,
                    hint: 'Read chapter 4',
                    icon: Icons.title_rounded,
                    onChanged: ref.read(blockEditorProvider.notifier).title,
                  ),

                  const SizedBox(height: 20),
                  SfEyebrow('When', color: sf.ink3),
                  const SizedBox(height: 10),
                  _PickerRow(
                    icon: Icons.schedule_outlined,
                    label: 'Starts',
                    // Optional on purpose: a block with no clock on it is a
                    // task for the day, and plenty of study is exactly that.
                    value: draft.startsAt == null
                        ? 'Optional'
                        : draft.startsAt!.format(context),
                    empty: draft.startsAt == null,
                    onTap: () => _pickStart(draft.startsAt),
                    onClear: draft.startsAt == null
                        ? null
                        : () => ref
                            .read(blockEditorProvider.notifier)
                            .startsAt(null),
                  ),

                  // A length means nothing without a start to measure from.
                  if (draft.startsAt != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      'How long',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: sf.ink2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final minutes in _presetMinutes)
                          SfSelectChip(
                            label: formatMinutes(minutes),
                            selected: draft.minutes == minutes,
                            onTap: () => ref
                                .read(blockEditorProvider.notifier)
                                .minutes(minutes),
                          ),
                        SfSelectChip(
                          label: _presetMinutes.contains(draft.minutes)
                              ? 'Custom'
                              : formatMinutes(draft.minutes),
                          icon: Icons.tune_rounded,
                          selected: !_presetMinutes.contains(draft.minutes),
                          onTap: () => _pickCustomLength(draft.minutes),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      scheduleOf(draft.startsAt, draft.minutes),
                      style: TextStyle(fontSize: 12, color: sf.ink3),
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 8, 22, 16),
              child: SfButton(
                editing ? 'Save changes' : 'Add block',
                size: SfButtonSize.lg,
                expand: true,
                busy: _saving,
                onPressed: draft.isValid && !_saving ? _save : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

}

class _TargetTile extends StatelessWidget {
  const _TargetTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final sf = context.sf;
    final scheme = context.scheme;
    final tint = selected ? scheme.primary : sf.ink3;

    return SfCard(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      onTap: onTap,
      color: selected ? sf.indigoSoft : null,
      borderColor: selected ? scheme.primary : null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: tint),
          const SizedBox(height: 6),
          Text(
            label,
            maxLines: 2,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: selected ? scheme.primary : sf.ink2,
            ),
          ),
        ],
      ),
    );
  }
}

class _PickerRow extends StatelessWidget {
  const _PickerRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.empty,
    required this.onTap,
    this.onClear,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool empty;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final sf = context.sf;

    return SfCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, size: 18, color: sf.ink3),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: sf.ink2,
            ),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: empty ? sf.ink4 : sf.ink,
              ),
            ),
          ),
          if (onClear != null)
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: GestureDetector(
                onTap: onClear,
                child: Icon(Icons.close_rounded, size: 16, color: sf.ink3),
              ),
            ),
        ],
      ),
    );
  }
}

/// Pops the picked document.
class _MaterialSheet extends ConsumerWidget {
  const _MaterialSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sf = context.sf;
    final all = ref.watch(materialsProvider).value ?? const <StudyMaterial>[];

    return SfSheetShell(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SheetTitle(
            title: 'Which document?',
            subtitle: 'The block will open it, and take its subject colour.',
          ),
          if (all.isEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 2),
              child: Text(
                'Nothing in your library yet.',
                style: TextStyle(fontSize: 13, color: sf.ink3),
              ),
            ),
          for (final material in all) ...[
            MaterialRow(
              material: material,
              showProgress: false,
              onTap: () => Navigator.of(context).pop(material),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

/// Pops the picked exam.
class _ExamSheet extends ConsumerWidget {
  const _ExamSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sf = context.sf;
    final preps = ref.watch(examPrepsProvider).value ?? const <ExamPrep>[];

    return SfSheetShell(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SheetTitle(
            title: 'Which exam?',
            subtitle: 'The block will open it, so you can see what it covers.',
          ),
          if (preps.isEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 2),
              child: Text(
                'No exams scheduled yet.',
                style: TextStyle(fontSize: 13, color: sf.ink3),
              ),
            ),
          for (final prep in preps) ...[
            SfCard(
              padding: const EdgeInsets.all(14),
              onTap: () => Navigator.of(context).pop(prep.exam),
              child: Row(
                children: [
                  SoftIconTile(
                    icon: Icons.event_available_outlined,
                    color: prep.exam.accent.color(context),
                    width: 40,
                    height: 40,
                    radius: 10,
                    iconSize: 18,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          prep.exam.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: sf.ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${prep.exam.date} · ${prep.exam.countdown}',
                          style: TextStyle(fontSize: 11, color: sf.ink3),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, size: 18, color: sf.ink4),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _SheetTitle extends StatelessWidget {
  const _SheetTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final sf = context.sf;

    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: AppTextStyles.heading
                .copyWith(fontSize: 20, letterSpacing: -0.5, color: sf.ink),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(fontSize: 13, height: 1.35, color: sf.ink3),
          ),
        ],
      ),
    );
  }
}
