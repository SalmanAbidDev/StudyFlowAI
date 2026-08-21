// lib/features/exams/exam_editor_screen.dart
//
// Add or edit an exam. Same screen for both: the only differences are the
// title, the seed, and whether saving inserts or updates.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/theme.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models/exam.dart';
import '../../data/models/subject.dart';
import '../categories/category_view_model.dart';
import 'exams_view_model.dart';

class ExamEditorScreen extends ConsumerStatefulWidget {
  const ExamEditorScreen({super.key, this.exam});

  /// Null to add, an exam to edit.
  final Exam? exam;

  @override
  ConsumerState<ExamEditorScreen> createState() => _ExamEditorScreenState();
}

class _ExamEditorScreenState extends ConsumerState<ExamEditorScreen> {
  final _title = TextEditingController();
  var _saving = false;

  @override
  void initState() {
    super.initState();
    _title.text = widget.exam?.title ?? '';
    // Seeding the form is a provider write, which cannot happen during build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(examEditorProvider.notifier).start(widget.exam);
    });
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _pickDate(DateTime? current) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? today,
      // An exam in the past is not a countdown, and `upcomingExams()` would
      // filter it straight back out of the list you just added it to.
      firstDate: today,
      lastDate: today.add(const Duration(days: 365 * 3)),
    );
    if (picked != null) ref.read(examEditorProvider.notifier).date(picked);
  }

  Future<void> _pickTime(TimeOfDay? current) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: current ?? const TimeOfDay(hour: 9, minute: 0),
    );
    if (picked != null) ref.read(examEditorProvider.notifier).time(picked);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(saveExamProvider)(examId: widget.exam?.id);
      navigator.pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(
        SnackBar(content: Text("Couldn't save that exam. $error")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final sf = context.sf;
    final draft = ref.watch(examEditorProvider);
    final subjects = ref.watch(subjectsProvider).value ?? const <Subject>[];
    final editing = widget.exam != null;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            SfModalHeader(title: editing ? 'Edit exam' : 'New exam'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(22, 0, 22, 24),
                children: [
                  SfEyebrow('What', color: sf.ink3),
                  const SizedBox(height: 10),
                  SfField(
                    controller: _title,
                    hint: 'Organic Chemistry final',
                    icon: Icons.edit_outlined,
                    onChanged: ref.read(examEditorProvider.notifier).title,
                  ),

                  const SizedBox(height: 20),
                  SfEyebrow('When', color: sf.ink3),
                  const SizedBox(height: 10),
                  _PickerRow(
                    icon: Icons.event_outlined,
                    label: 'Date',
                    value: draft.date == null
                        ? 'Pick a date'
                        : Exam(
                            id: '',
                            title: '',
                            examDate: draft.date!,
                            accent: SubjectAccent.indigo,
                          ).schedule,
                    empty: draft.date == null,
                    onTap: () => _pickDate(draft.date),
                  ),
                  const SizedBox(height: 8),
                  _PickerRow(
                    icon: Icons.schedule_outlined,
                    label: 'Time',
                    // Optional on purpose: plenty of exams are "some time that
                    // Thursday", and forcing a made-up 9:00 would put a time on
                    // the card that nobody chose.
                    value: draft.time == null
                        ? 'Optional'
                        : Exam(
                            id: '',
                            title: '',
                            examDate: DateTime.now(),
                            examTime: draft.time,
                            accent: SubjectAccent.indigo,
                          ).time,
                    empty: draft.time == null,
                    onTap: () => _pickTime(draft.time),
                    onClear: draft.time == null
                        ? null
                        : () => ref.read(examEditorProvider.notifier).time(null),
                  ),

                  const SizedBox(height: 20),
                  SfEyebrow('Priority', color: sf.ink3),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      for (final priority in ExamPriority.values) ...[
                        if (priority != ExamPriority.values.first)
                          const SizedBox(width: 8),
                        Expanded(
                          child: _PriorityChip(
                            priority: priority,
                            selected: draft.priority == priority,
                            onTap: () => ref
                                .read(examEditorProvider.notifier)
                                .priority(priority),
                          ),
                        ),
                      ],
                    ],
                  ),

                  if (subjects.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    SfEyebrow('Subject', color: sf.ink3),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final subject in subjects)
                          SfSelectChip(
                            label: subject.name,
                            icon: subject.icon,
                            accent: subject.accent.color(context),
                            selected: draft.subjectId == subject.id,
                            // Tapping the selected one clears it — the subject
                            // is optional and there has to be a way back out.
                            onTap: () => ref
                                .read(examEditorProvider.notifier)
                                .subject(draft.subjectId == subject.id
                                    ? null
                                    : subject.id),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 8, 22, 16),
              child: SfButton(
                editing ? 'Save changes' : 'Add exam',
                size: SfButtonSize.lg,
                expand: true,
                busy: _saving,
                // Disabled rather than saving something incomplete and
                // explaining afterwards.
                onPressed: draft.isValid && !_saving ? _save : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A tappable row that reads as a field but opens a picker.
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

class _PriorityChip extends StatelessWidget {
  const _PriorityChip({
    required this.priority,
    required this.selected,
    required this.onTap,
  });

  final ExamPriority priority;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final sf = context.sf;
    final scheme = context.scheme;
    final high = priority == ExamPriority.high;
    final tint = high ? sf.coralInk : sf.ink2;

    return SfCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      onTap: onTap,
      color: selected ? (high ? sf.coralSoft : scheme.surfaceContainerHigh) : null,
      borderColor: selected ? tint : null,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            high ? Icons.my_location_rounded : Icons.circle_outlined,
            size: 15,
            color: selected ? tint : sf.ink4,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              high ? 'High' : 'Normal',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? tint : sf.ink2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
