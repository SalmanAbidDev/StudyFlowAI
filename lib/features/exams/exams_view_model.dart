// lib/features/exams/exams_view_model.dart
//
// Exams, and the one number that used to be a lie.
//
// `exams.preparation` was a stored 0..1 that nothing in the app ever wrote, so
// every card would have read 0% forever — the same trap as `profiles.streak_days`
// (§5.1). The column is gone. Preparation is now **derived**: how far you have
// read the materials attached to the exam. Attach nothing and there is no
// number to show, which is exactly what "No materials added" means.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/view_models.dart';
import '../../data/models/exam.dart';
import '../../data/models/study_material.dart';
import '../../data/supabase_providers.dart';
import '../materials/materials_view_model.dart';
import '../planner/planner_view_model.dart';

/// An exam with its attachments resolved against the live library.
class ExamPrep {
  const ExamPrep({required this.exam, required this.materials});

  final Exam exam;

  /// The attached documents, as they exist *now*. An attachment whose material
  /// has been deleted simply is not here — the join row cascades, but this
  /// also holds between the delete and the next refetch.
  final List<StudyMaterial> materials;

  bool get hasMaterials => materials.isNotEmpty;

  /// Mean reading progress across the attached documents, or null when there
  /// is nothing attached. **Null is not zero**: "nothing to measure" and
  /// "measured, and you have done none of it" are different things to say.
  double? get preparation {
    if (materials.isEmpty) return null;
    final total = materials.fold<double>(0, (sum, m) => sum + m.progress);
    return total / materials.length;
  }

  String get preparationLabel {
    final value = preparation;
    return value == null ? '—' : '${(value * 100).round()}%';
  }
}

/// Every upcoming exam, paired with what it is revised from.
///
/// Derived from [materialsProvider] rather than querying progress separately,
/// so reading a document moves the exam's preparation with it and deleting one
/// takes it out of the average (§5.1.1).
final examPrepsProvider = FutureProvider<List<ExamPrep>>((ref) async {
  final exams = await ref.watch(upcomingExamsProvider.future);
  final library = await ref.watch(materialsProvider.future);
  final byId = {for (final m in library) m.id: m};

  return [
    for (final exam in exams)
      ExamPrep(
        exam: exam,
        materials: [
          for (final id in exam.materialIds) ?byId[id],
        ],
      ),
  ];
});

/// Which exam the detail screen is showing. Set before pushing the route, the
/// same way `selectedMaterialProvider` works for documents.
final selectedExamProvider =
    NotifierProvider<ValueViewModel<String?>, String?>(
  () => ValueViewModel(null),
);

/// The selected exam, re-read from the list so an edit made on the detail
/// screen shows up there without the screen holding its own copy.
final currentExamProvider = Provider<ExamPrep?>((ref) {
  final id = ref.watch(selectedExamProvider);
  final preps = ref.watch(examPrepsProvider).value ?? const <ExamPrep>[];
  // No selection falls back to the soonest exam, matching
  // `currentMaterialProvider`. A selection that no longer resolves does *not*
  // fall back — it has been deleted or its date has passed, and quietly
  // showing a different exam under the same heading would be worse than
  // saying so.
  if (id == null) return preps.firstOrNull;
  return preps.where((p) => p.exam.id == id).firstOrNull;
});

// ─── Writing ──────────────────────────────────────────────────────────────

/// What the editor collects. A plain value type so the form can be validated
/// and tested without a widget.
class ExamDraft {
  const ExamDraft({
    this.title = '',
    this.date,
    this.time,
    this.priority = ExamPriority.normal,
    this.subjectId,
  });

  factory ExamDraft.from(Exam exam) => ExamDraft(
        title: exam.title,
        date: exam.examDate,
        time: exam.examTime,
        priority: exam.priority,
        subjectId: exam.subjectId,
      );

  final String title;
  final DateTime? date;
  final TimeOfDay? time;
  final ExamPriority priority;
  final String? subjectId;

  /// A title and a date are the whole requirement. Time and subject are
  /// genuinely optional — plenty of exams are "some time that Thursday".
  bool get isValid => title.trim().isNotEmpty && date != null;

  ExamDraft copyWith({
    String? title,
    DateTime? date,
    TimeOfDay? time,
    bool clearTime = false,
    ExamPriority? priority,
    String? subjectId,
    bool clearSubject = false,
  }) =>
      ExamDraft(
        title: title ?? this.title,
        date: date ?? this.date,
        // `time` and `subjectId` are clearable, which an omitted-vs-null
        // argument cannot express on its own.
        time: clearTime ? null : (time ?? this.time),
        priority: priority ?? this.priority,
        subjectId: clearSubject ? null : (subjectId ?? this.subjectId),
      );
}

class ExamEditor extends Notifier<ExamDraft> {
  @override
  ExamDraft build() => const ExamDraft();

  /// Seeds the form when the editor is opened on an existing exam.
  void start(Exam? exam) {
    state = exam == null ? const ExamDraft() : ExamDraft.from(exam);
  }

  void title(String value) => state = state.copyWith(title: value);
  void date(DateTime value) => state = state.copyWith(date: value);
  void time(TimeOfDay? value) =>
      state = state.copyWith(time: value, clearTime: value == null);
  void priority(ExamPriority value) => state = state.copyWith(priority: value);
  void subject(String? value) =>
      state = state.copyWith(subjectId: value, clearSubject: value == null);
}

final examEditorProvider =
    NotifierProvider.autoDispose<ExamEditor, ExamDraft>(ExamEditor.new);

/// Saves the draft, creating or updating. Returns the exam's id.
final saveExamProvider =
    Provider<Future<String> Function({String? examId})>((ref) {
  return ({String? examId}) async {
    final draft = ref.read(examEditorProvider);
    final repo = ref.read(plannerRepositoryProvider);

    final id = examId == null
        ? await repo.createExam(
            userId: ref.read(currentUserIdProvider),
            title: draft.title.trim(),
            examDate: draft.date!,
            examTime: draft.time,
            priority: draft.priority,
            subjectId: draft.subjectId,
          )
        : await () async {
            await repo.updateExam(
              examId: examId,
              title: draft.title.trim(),
              examDate: draft.date!,
              examTime: draft.time,
              priority: draft.priority,
              subjectId: draft.subjectId,
            );
            return examId;
          }();

    ref.invalidate(upcomingExamsProvider);
    return id;
  };
});

final deleteExamProvider = Provider<Future<void> Function(String)>((ref) {
  return (examId) async {
    await ref.read(plannerRepositoryProvider).deleteExam(examId);
    ref.invalidate(upcomingExamsProvider);
  };
});

/// Replaces what an exam is revised from.
final setExamMaterialsProvider =
    Provider<Future<void> Function(String, List<String>)>((ref) {
  return (examId, materialIds) async {
    await ref.read(plannerRepositoryProvider).setExamMaterials(
          examId: examId,
          userId: ref.read(currentUserIdProvider),
          materialIds: materialIds,
        );
    ref.invalidate(upcomingExamsProvider);
  };
});
