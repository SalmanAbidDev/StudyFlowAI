// lib/features/exams/exam_detail_screen.dart
//
// One exam: the countdown, what it is revised from, and the practice built
// from those materials.
//
// This is where "no materials added" gets resolved. An exam with nothing
// attached has no preparation to report — see `ExamPrep.preparation`, which is
// null rather than 0 for exactly that case.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/navigation.dart';
import '../../core/theme/theme.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models/exam.dart';
import '../../data/models/subject.dart';
import '../../data/models/study_material.dart';
import '../documents/document_screen.dart';
import '../materials/material_browser.dart';
import '../materials/materials_view_model.dart';
import 'exams_view_model.dart';

class ExamDetailScreen extends ConsumerWidget {
  const ExamDetailScreen({super.key});

  Future<void> _attach(BuildContext context, WidgetRef ref, ExamPrep prep)
      async {
    final picked = await showSfSheet<List<String>>(
      context,
      (_) => _AttachSheet(
        selected: prep.materials.map((m) => m.id).toSet(),
      ),
    );
    if (picked == null) return;
    await ref.read(setExamMaterialsProvider)(prep.exam.id, picked);
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, Exam exam) async {
    final confirmed = await showSfSheet<bool>(
      context,
      (_) => SfConfirmSheet(
        icon: Icons.delete_outline_rounded,
        title: 'Delete this exam?',
        body: '"${exam.title}" and its list of materials will be removed. '
            'The documents themselves stay in your library.',
        confirmLabel: 'Delete',
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final navigator = Navigator.of(context);
    await ref.read(deleteExamProvider)(exam.id);
    navigator.pop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sf = context.sf;
    final prep = ref.watch(currentExamProvider);

    // Deleted from under us, or opened without a selection.
    if (prep == null) {
      return Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              const SfModalHeader(
                title: 'Exam',
                leadingIcon: Icons.arrow_back_rounded,
              ),
              const Expanded(
                child: SfEmptyView(
                  icon: Icons.event_busy_outlined,
                  title: 'Exam not found',
                  body: 'It may have been deleted, or its date has passed.',
                ),
              ),
            ],
          ),
        ),
      );
    }

    final exam = prep.exam;
    final accent = exam.accent.color(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            SfModalHeader(
              title: 'Exam',
              leadingIcon: Icons.arrow_back_rounded,
              trailing: SfIconButton(
                icon: Icons.delete_outline_rounded,
                iconSize: 16,
                color: sf.coralInk,
                onPressed: () => _delete(context, ref, exam),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(22, 0, 22, 24),
                children: [
                  _Countdown(prep: prep, accent: accent),
                  const SizedBox(height: 20),

                  Row(
                    children: [
                      Expanded(
                        child: SectionHeader(
                          prep.hasMaterials
                              ? 'Materials (${prep.materials.length})'
                              : 'Materials',
                          action: 'Add',
                          onAction: () => _attach(context, ref, prep),
                        ),
                      ),
                    ],
                  ),

                  if (!prep.hasMaterials)
                    SfCard(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 18),
                      onTap: () => _attach(context, ref, prep),
                      child: Row(
                        children: [
                          SoftIconTile(
                            icon: Icons.playlist_add_rounded,
                            color: context.scheme.primary,
                            background: sf.indigoSoft,
                            width: 40,
                            height: 40,
                            radius: 12,
                            iconSize: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'No materials added. Attach the documents you '
                              'are revising from and this exam will track how '
                              'far through them you are.',
                              style: TextStyle(
                                fontSize: 13,
                                height: 1.35,
                                color: sf.ink3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    for (final material in prep.materials) ...[
                      MaterialRow(
                        material: material,
                        onTap: () {
                          ref
                              .read(selectedMaterialProvider.notifier)
                              .update(material.id);
                          Navigator.of(context).push(
                            sfRoute(builder: (_) => const DocumentScreen()),
                          );
                        },
                      ),
                      const SizedBox(height: 10),
                    ],
                ],
              ),
            ),

            // No practice row here. Flashcards, Quiz and Flow all run on one
            // document at a time, and every attached document is already a
            // row above with those actions a tap away — a second set at the
            // bottom would have had to guess which one you meant.
          ],
        ),
      ),
    );
  }
}

/// The days-left card, in the featured exam's colours.
class _Countdown extends StatelessWidget {
  const _Countdown({required this.prep, required this.accent});

  final ExamPrep prep;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final sf = context.sf;
    final exam = prep.exam;

    return SfCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (exam.priority == ExamPriority.high) ...[
                Icon(Icons.my_location_rounded, size: 13, color: sf.coralInk),
                const SizedBox(width: 6),
                Flexible(
                  child: SfEyebrow('High priority',
                      size: 10, tracking: 1, color: sf.coralInk),
                ),
              ] else
                Flexible(
                  child: SfEyebrow(exam.schedule, size: 10, tracking: 1),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            exam.title,
            style: AppTextStyles.heading
                .copyWith(fontSize: 22, letterSpacing: -0.5, color: sf.ink),
          ),
          const SizedBox(height: 4),
          SfMono(exam.schedule, size: 12, color: sf.ink3),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${exam.daysLeft}',
                style: TextStyle(
                  fontFamily: AppTextStyles.fontUi,
                  fontSize: 44,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -2,
                  height: 0.9,
                  color: accent,
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  exam.daysLeft == 1 ? 'DAY LEFT' : 'DAYS LEFT',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                    color: sf.ink3,
                  ),
                ),
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
                  color: sf.ink2,
                ),
              ),
              SfMono(
                prep.preparationLabel,
                size: 11,
                weight: FontWeight.w700,
                color: prep.hasMaterials ? sf.ink : sf.ink4,
              ),
            ],
          ),
          const SizedBox(height: 6),
          // A zero-width bar over an em dash, rather than an empty bar that
          // reads as "0% done" when the truth is "nothing to measure".
          SfProgress(value: prep.preparation ?? 0, color: accent),
          if (!prep.hasMaterials) ...[
            const SizedBox(height: 8),
            Text(
              'Add materials to track this.',
              style: TextStyle(fontSize: 11, color: sf.ink3),
            ),
          ],
        ],
      ),
    );
  }
}

/// Ticks the documents this exam is revised from. Pops the full set rather
/// than one id — the caller replaces the attachments wholesale.
class _AttachSheet extends ConsumerStatefulWidget {
  const _AttachSheet({required this.selected});

  final Set<String> selected;

  @override
  ConsumerState<_AttachSheet> createState() => _AttachSheetState();
}

class _AttachSheetState extends ConsumerState<_AttachSheet> {
  late final Set<String> _picked = {...widget.selected};

  @override
  Widget build(BuildContext context) {
    final sf = context.sf;
    final all = ref.watch(materialsProvider).value ?? const <StudyMaterial>[];

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
                  'Revising from',
                  style: AppTextStyles.heading.copyWith(
                    fontSize: 20,
                    letterSpacing: -0.5,
                    color: sf.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Tick everything this exam covers. Preparation is how far '
                  'through them you are.',
                  style: TextStyle(fontSize: 13, height: 1.35, color: sf.ink3),
                ),
              ],
            ),
          ),
          if (all.isEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 2, bottom: 14),
              child: Text(
                'Nothing in your library yet.',
                style: TextStyle(fontSize: 13, color: sf.ink3),
              ),
            ),
          for (final material in all) ...[
            MaterialRow(
              material: material,
              showProgress: false,
              selected: _picked.contains(material.id),
              onTap: () => setState(() {
                if (!_picked.remove(material.id)) _picked.add(material.id);
              }),
              trailing: Icon(
                _picked.contains(material.id)
                    ? Icons.check_circle_rounded
                    : Icons.circle_outlined,
                size: 20,
                color: _picked.contains(material.id)
                    ? context.scheme.primary
                    : sf.ink4,
              ),
            ),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 6),
          SfButton(
            _picked.isEmpty ? 'Save with none' : 'Save ${_picked.length}',
            size: SfButtonSize.lg,
            expand: true,
            onPressed: () => Navigator.of(context).pop(_picked.toList()),
          ),
        ],
      ),
    );
  }
}
