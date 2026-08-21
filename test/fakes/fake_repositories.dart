// test/fakes/fake_repositories.dart
//
// In-memory stand-ins for the Supabase-backed repositories. Overriding at the
// repository seam keeps the suite hermetic — no Supabase singleton, no URL, no
// HTTP — while still exercising the real view models, providers and widgets
// above them.

import 'dart:convert';
import 'dart:typed_data';

import 'package:ai_study_helper/data/models/exam.dart';
import 'package:ai_study_helper/data/models/flashcard.dart';
import 'package:ai_study_helper/data/models/profile.dart';
import 'package:ai_study_helper/data/models/quiz.dart';
import 'package:ai_study_helper/data/models/study_block.dart';
import 'package:ai_study_helper/data/models/study_material.dart';
import 'package:ai_study_helper/data/models/subject.dart';
import 'package:ai_study_helper/data/models/summary_section.dart';
import 'package:ai_study_helper/core/config/ai_config.dart';
import 'package:ai_study_helper/data/repositories/ai_repository.dart';
import 'package:ai_study_helper/data/repositories/analytics_repository.dart';
import 'package:ai_study_helper/data/repositories/chat_repository.dart';
import 'package:ai_study_helper/data/repositories/library_repository.dart';
import 'package:ai_study_helper/data/repositories/planner_repository.dart';
import 'package:ai_study_helper/data/repositories/profile_repository.dart';
import 'package:ai_study_helper/data/repositories/storage_repository.dart';
import 'package:ai_study_helper/data/repositories/study_repository.dart';
import 'package:ai_study_helper/features/chat/chat_models.dart';
import 'package:flutter/material.dart';

const kFakeMaterialTitle = 'Stereochemistry & Chirality';

StudyMaterial _material(String id, String title, String subject,
        SubjectAccent accent, double progress) =>
    StudyMaterial(
      id: id,
      title: title,
      progress: progress,
      accent: accent,
      icon: Icons.science_outlined,
      subjectName: subject,
      pageCount: 14,
    );

class FakeLibraryRepository implements LibraryRepository {
  /// [empty] models a brand-new account, which is what Home's conditional
  /// sections have to be tested against.
  FakeLibraryRepository({this.empty = false, this.summarised = true})
      : _materials = empty
            ? []
            : [
                _material('m1', kFakeMaterialTitle, 'Organic Chemistry',
                    SubjectAccent.indigo, 0.42),
                _material('m2', 'Monetary Policy Lecture', 'Macroeconomics',
                    SubjectAccent.emerald, 1),
              ];

  final bool empty;

  /// False models a document nobody has summarised yet — the state the
  /// Summarize button exists for.
  final bool summarised;

  final List<StudyMaterial> _materials;

  /// A copy, not the backing list. The real repository builds a fresh list per
  /// call and can never hand back something the caller is still iterating —
  /// returning `_materials` directly let a delete loop mutate the list it was
  /// walking, which is a failure the app could never actually have.
  @override
  Future<List<StudyMaterial>> materials() async => List.of(_materials);

  @override
  Future<StudyMaterial?> latestMaterial() async =>
      _materials.isEmpty ? null : _materials.first;

  // No `resumeMaterial` or `leastProgressed` stubs any more — both are derived
  // from `materials()` now, so the fake only has to answer the one question.

  final _subjects = <Subject>[
    const Subject(
      id: 'sub-1',
      name: 'Organic Chemistry',
      accent: SubjectAccent.indigo,
      iconKey: 'science',
    ),
  ];

  /// Records what the category screen filed, so a test can assert on the
  /// result rather than only on the navigation.
  final filed = <String, String>{};

  /// The category name a material ended up under, resolved through the id the
  /// screen actually wrote.
  String? named(String materialId) {
    final id = filed[materialId];
    if (id == null) return null;
    for (final subject in _subjects) {
      if (subject.id == id) return subject.name;
    }
    return null;
  }

  @override
  Future<List<Subject>> subjects() async => empty ? const [] : _subjects;

  @override
  Future<Subject> ensureSubject({
    required String userId,
    required String name,
    SubjectAccent accent = SubjectAccent.indigo,
    String iconKey = 'book',
  }) async {
    for (final subject in _subjects) {
      if (subject.name.toLowerCase() == name.trim().toLowerCase()) {
        return subject;
      }
    }
    final created = Subject(
      id: 'sub-${_subjects.length + 1}',
      name: name.trim(),
      accent: accent,
      iconKey: iconKey,
    );
    _subjects.add(created);
    return created;
  }

  @override
  Future<void> setMaterialSubject(String materialId, String subjectId) async {
    filed[materialId] = subjectId;
  }

  @override
  Future<List<SummarySection>> summaryFor(String materialId) async =>
      empty || !summarised
      ? const []
      : const [
        SummarySection(
          id: 's1',
          title: '4.1 Chirality & Stereocenters',
          read: true,
          bullets: ['A **chiral** molecule cannot be superimposed.'],
        ),
      ];

  @override
  Future<void> setSectionRead(String sectionId, {required bool read}) async {}

  @override
  Future<void> setMaterialProgress(String materialId, double progress) async {}

  @override
  Future<StudyMaterial> createMaterial({
    required String userId,
    required String title,
    String? subjectId,
    String? storagePath,
    String? sourceUrl,
    String? mimeType,
    int? byteSize,
    int? pageCount,
  }) async {
    final created = _material('new', title, 'Unfiled', SubjectAccent.indigo, 0);
    _materials.insert(0, created);
    return created;
  }

  /// What was actually removed, so a test can prove a cancelled confirmation
  /// deleted nothing rather than only that the sheet closed.
  final deleted = <String>[];

  @override
  Future<void> deleteMaterial(String materialId) async {
    deleted.add(materialId);
    _materials.removeWhere((m) => m.id == materialId);
  }
}

class FakePlannerRepository implements PlannerRepository {
  FakePlannerRepository({this.empty = false, this.partialToday = false});

  final bool empty;

  @override
  Future<Map<DateTime, List<StudyBlock>>> blocksBetween(
    DateTime from,
    DateTime to,
  ) async {
    if (empty) return {};
    // Everything on today, so the week strip has exactly one judgeable day.
    final now = DateTime.now();
    return {DateTime(now.year, now.month, now.day): _blocks};
  }

  final _blocks = <StudyBlock>[
    const StudyBlock(
      id: 'b1',
      title: 'Stereochem · Read Ch 4',
      accent: SubjectAccent.indigo,
      icon: Icons.science_outlined,
      position: 0,
      done: false,
      startsAt: TimeOfDay(hour: 8, minute: 0),
      endsAt: TimeOfDay(hour: 9, minute: 30),
      // Linked, because every block the editor can now build is: it is what
      // lets a test check that tapping a row opens something.
      materialId: 'm1',
    ),
    const StudyBlock(
      id: 'b2',
      title: 'Macro · Lecture review',
      accent: SubjectAccent.emerald,
      icon: Icons.show_chart_rounded,
      position: 1,
      done: false,
      startsAt: TimeOfDay(hour: 10, minute: 0),
      endsAt: TimeOfDay(hour: 10, minute: 45),
    ),
  ];

  /// Three days running, ending today, **fully** completed — enough to tell a
  /// real streak from a hard-coded one.
  ///
  /// [partialToday] leaves one of today's two blocks outstanding, which is the
  /// case the streak must refuse to count: it used to count any day with a
  /// single tick on it.
  final bool partialToday;

  @override
  Future<List<PlannedBlock>> blockHistory() async {
    if (empty) return const [];
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return [
      for (var i = 0; i < 3; i++) ...[
        PlannedBlock(
          day: today.subtract(Duration(days: i)),
          minutes: 90,
          done: true,
        ),
        if (i == 0 && partialToday)
          PlannedBlock(day: today, minutes: 45, done: false),
      ],
    ];
  }

  /// Blocks keyed by day, so a test can plan on one date and check another is
  /// untouched — which is the whole point of a scrolling strip.
  late final Map<DateTime, List<StudyBlock>> _byDay = empty
      ? {}
      : {_key(DateTime.now()): _blocks};

  static DateTime _key(DateTime day) =>
      DateTime(day.year, day.month, day.day);

  @override
  Future<List<StudyBlock>> blocksOn(DateTime day) async =>
      List.of(_byDay[_key(day)] ?? const []);

  @override
  Future<Map<DateTime, int>> blockCountsBetween(
    DateTime from,
    DateTime to,
  ) async =>
      {
        for (final entry in _byDay.entries)
          if (!entry.key.isBefore(_key(from)) && !entry.key.isAfter(_key(to)))
            if (entry.value.isNotEmpty) entry.key: entry.value.length,
      };

  @override
  Future<void> saveOrder(List<StudyBlock> blocks) async {
    if (blocks.isEmpty) return;
    for (final entry in _byDay.entries) {
      if (entry.value.any((b) => b.id == blocks.first.id)) {
        _byDay[entry.key] = List.of(blocks);
        return;
      }
    }
  }

  @override
  Future<void> setBlockDone(String blockId, {required bool done}) async {
    for (final entry in _byDay.entries) {
      final i = entry.value.indexWhere((b) => b.id == blockId);
      if (i == -1) continue;
      final b = entry.value[i];
      entry.value[i] = StudyBlock(
        id: b.id,
        title: b.title,
        accent: b.accent,
        icon: b.icon,
        position: b.position,
        done: done,
        startsAt: b.startsAt,
        endsAt: b.endsAt,
        materialId: b.materialId,
        examId: b.examId,
        subjectId: b.subjectId,
      );
      return;
    }
  }

  var _nextBlockId = 100;

  @override
  Future<void> createBlock({
    required String userId,
    required String title,
    required DateTime day,
    TimeOfDay? startsAt,
    int minutes = 0,
    String? subjectId,
    String? materialId,
    String? examId,
    int position = 0,
  }) async {
    (_byDay[_key(day)] ??= []).add(StudyBlock(
      id: 'nb${_nextBlockId++}',
      title: title,
      accent: SubjectAccent.indigo,
      icon: Icons.book_outlined,
      position: position,
      done: false,
      startsAt: startsAt,
      endsAt: _end(startsAt, minutes),
      materialId: materialId,
      examId: examId,
      subjectId: subjectId,
    ));
  }

  /// Mirrors the repository: the end time is computed from the length rather
  /// than picked, so a test sees the same window the app would store.
  static TimeOfDay? _end(TimeOfDay? start, int minutes) {
    if (start == null || minutes <= 0) return null;
    final total = start.hour * 60 + start.minute + minutes;
    if (total >= 24 * 60) return const TimeOfDay(hour: 23, minute: 59);
    return TimeOfDay(hour: total ~/ 60, minute: total % 60);
  }

  @override
  Future<void> updateBlock({
    required String blockId,
    required String title,
    required DateTime day,
    TimeOfDay? startsAt,
    int minutes = 0,
    String? subjectId,
    String? materialId,
    String? examId,
  }) async {
    for (final entry in _byDay.entries) {
      final i = entry.value.indexWhere((b) => b.id == blockId);
      if (i == -1) continue;
      final b = entry.value[i];
      entry.value[i] = StudyBlock(
        id: b.id,
        title: title,
        accent: b.accent,
        icon: b.icon,
        position: b.position,
        done: b.done,
        startsAt: startsAt,
        endsAt: _end(startsAt, minutes),
        materialId: materialId,
        examId: examId,
        subjectId: subjectId,
      );
      return;
    }
  }

  @override
  Future<void> deleteBlock(String blockId) async {
    for (final blocks in _byDay.values) {
      blocks.removeWhere((b) => b.id == blockId);
    }
  }

  @override
  Future<void> copyDay({
    required String userId,
    required List<StudyBlock> blocks,
    required List<DateTime> targets,
  }) async {
    for (final day in targets) {
      for (var i = 0; i < blocks.length; i++) {
        final b = blocks[i];
        (_byDay[_key(day)] ??= []).add(StudyBlock(
          id: 'nb${_nextBlockId++}',
          title: b.title,
          accent: b.accent,
          icon: b.icon,
          position: i,
          // Never copied: a plan for next Tuesday that arrives already ticked
          // would claim work nobody has done.
          done: false,
          startsAt: b.startsAt,
          endsAt: b.endsAt,
          materialId: b.materialId,
          examId: b.examId,
          subjectId: b.subjectId,
        ));
      }
    }
  }

  /// Mutable so a test can add, edit, attach and delete against it and see the
  /// result — the whole point of the exam editor.
  late final List<Exam> _exams = empty
      ? []
      : [
          Exam(
            id: 'e1',
            title: 'Organic Chem Final',
            examDate: DateTime.now().add(const Duration(days: 9)),
            examTime: const TimeOfDay(hour: 9, minute: 0),
            priority: ExamPriority.high,
            accent: SubjectAccent.coral,
            // Deliberately none: "no materials added" is the state an exam
            // starts in, and the one the screens have to describe honestly.
            materialIds: const [],
          ),
        ];

  @override
  Future<List<Exam>> upcomingExams() async => List.of(_exams);

  var _nextId = 2;

  @override
  Future<String> createExam({
    required String userId,
    required String title,
    required DateTime examDate,
    TimeOfDay? examTime,
    ExamPriority priority = ExamPriority.normal,
    String? subjectId,
  }) async {
    final id = 'e${_nextId++}';
    _exams.add(Exam(
      id: id,
      title: title,
      examDate: examDate,
      examTime: examTime,
      priority: priority,
      accent: SubjectAccent.indigo,
      subjectId: subjectId,
    ));
    // Soonest first, the way the real query orders them.
    _exams.sort((a, b) => a.examDate.compareTo(b.examDate));
    return id;
  }

  @override
  Future<void> updateExam({
    required String examId,
    required String title,
    required DateTime examDate,
    TimeOfDay? examTime,
    ExamPriority priority = ExamPriority.normal,
    String? subjectId,
  }) async {
    final i = _exams.indexWhere((e) => e.id == examId);
    if (i == -1) return;
    _exams[i] = Exam(
      id: examId,
      title: title,
      examDate: examDate,
      examTime: examTime,
      priority: priority,
      accent: _exams[i].accent,
      subjectId: subjectId,
      materialIds: _exams[i].materialIds,
    );
  }

  @override
  Future<void> deleteExam(String examId) async =>
      _exams.removeWhere((e) => e.id == examId);

  @override
  Future<void> setExamMaterials({
    required String examId,
    required String userId,
    required List<String> materialIds,
  }) async {
    final i = _exams.indexWhere((e) => e.id == examId);
    if (i == -1) return;
    final exam = _exams[i];
    _exams[i] = Exam(
      id: exam.id,
      title: exam.title,
      examDate: exam.examDate,
      examTime: exam.examTime,
      priority: exam.priority,
      accent: exam.accent,
      subjectId: exam.subjectId,
      materialIds: List.of(materialIds),
    );
  }
}

class FakeStudyRepository implements StudyRepository {
  FakeStudyRepository({this.attempt, this.empty = false});

  /// Null means "no quiz finished yet", which is what Home's suggestion card
  /// falls back from.
  final QuizAttempt? attempt;

  /// No deck and no quiz — the state where those screens have nothing to show
  /// and must still offer a way out.
  final bool empty;

  @override
  Future<QuizAttempt?> latestAttempt() async => attempt;

  @override
  Future<Deck?> firstDeck() async => empty
      ? null
      : const Deck(
        id: 'd1',
        title: 'Stereochemistry',
        cards: [
          Flashcard(
            id: 'c1',
            question: 'What defines a chiral molecule?',
            answer: 'A molecule that cannot be superimposed on its mirror '
                'image.',
            source: 'Stereochem.pdf · p.4',
          ),
          Flashcard(
            id: 'c2',
            question: 'R vs S configuration?',
            answer: 'Assign CIP priorities.',
            source: 'Stereochem.pdf · p.5',
          ),
        ],
      );

  /// Only `m1` has anything generated for it. That is the realistic shape —
  /// most documents have no deck and no quiz until a model builds them — and
  /// it lets a test walk both branches of the picker.
  @override
  Future<Deck?> deckForMaterial(String materialId) async =>
      materialId == 'm1' ? firstDeck() : null;

  @override
  Future<Quiz?> quizForMaterial(String materialId) async =>
      materialId == 'm1' ? firstQuiz() : null;

  /// Practice done against practice generated. `m1` is half finished — enough
  /// for a task's progress bar to show something other than 0% or 100%.
  var progress = <String, ({int done, int total})>{
    'm1': (done: 4, total: 8),
  };

  @override
  Future<Map<String, ({int done, int total})>> progressByMaterial() async =>
      empty ? {} : Map.of(progress);

  @override
  Future<void> reviewCard(
    Flashcard card, {
    required bool remembered,
    required double ease,
    required int intervalDays,
  }) async {}

  @override
  Future<Quiz?> firstQuiz() async => empty
      ? null
      : const Quiz(
        id: 'q1',
        title: 'Stereochemistry check',
        questions: [
          QuizQuestion(
            id: 'qq1',
            prompt: 'Which statement about diastereomers is correct?',
            explanation: 'Diastereomers are **not** mirror images.',
            options: [
              QuizOption(
                id: 'o1',
                label: 'a',
                body: 'They are non-superimposable mirror images of each other',
                correct: false,
              ),
              QuizOption(
                id: 'o2',
                label: 'b',
                body: 'They are stereoisomers that are not mirror images',
                correct: true,
              ),
            ],
          ),
          QuizQuestion(
            id: 'qq2',
            prompt: 'A carbon bonded to four different groups is called a…',
            explanation: 'A **stereocenter**.',
            options: [
              QuizOption(
                  id: 'o3', label: 'a', body: 'Stereocenter', correct: true),
              QuizOption(
                  id: 'o4', label: 'b', body: 'Meso carbon', correct: false),
            ],
          ),
        ],
      );

  @override
  Future<void> recordAttempt({
    required String userId,
    required String? quizId,
    required int correct,
    required int total,
    required int elapsedSeconds,
    required List<String> missed,
  }) async {}
}

class FakeProfileRepository implements ProfileRepository {
  @override
  Future<Profile?> current() async => const Profile(
        id: 'u1',
        fullName: 'Alex Morgan',
        streakDays: 12,
        isPro: true,
      );

  @override
  Future<void> updateName(String fullName) async {}

  /// One earned badge; the rest of the catalogue comes from the app, so the
  /// list is never empty regardless of what this returns.
  @override
  Future<Map<String, DateTime>> earnedAchievements() async =>
      {'hot_streak': DateTime.utc(2026, 8, 1)};

  @override
  Future<void> seedStarterContent() async {}
}

class FakeAnalyticsRepository implements AnalyticsRepository {
  @override
  Future<StudyStats> stats({int days = 7}) async => const StudyStats(
        weeklyHours: [3, 4.5, 2, 5, 3.5, 1.5, 4],
        totalHours: 23.5,
        focusScore: 0.84,
        cardsMastered: 342,
        subjectSplit: [
          SubjectShare(
            label: 'Organic Chemistry',
            hours: 8.5,
            share: 1,
            accent: SubjectAccent.indigo,
          ),
        ],
      );

  @override
  Future<int> masteredCount() async => 342;

  @override
  Future<void> logSession({
    required String userId,
    required int durationMinutes,
    String? subjectId,
    double? focusScore,
  }) async {}
}

/// Stands in for the Edge Function. No network, no key, no Gemini — the point
/// of the seam is that the app can be tested without any of them.
class FakeAiRepository implements AiRepository {
  FakeAiRepository({
    this.used = 0,
    this.failure,
    this.limit = AiConfig.dailyChatLimit,
  });

  /// Raisable, so a layout test can build a transcript longer than a real
  /// day's allowance without the composer shutting off half way.
  final int limit;

  /// How many of today's questions are already gone.
  int used;

  /// Set to make the next call fail, which is how the limit and the error
  /// paths are exercised.
  AiException? failure;

  /// Every question asked, so a test can prove the held document and the
  /// transcript were actually handed over rather than merely displayed.
  final asked = <({String question, String? materialId, int historyLength})>[];

  /// Materials that had content generated for them.
  final generated = <String>[];

  @override
  Future<({String answer, AiUsage usage})> ask({
    required String question,
    String? materialId,
    List<({String role, String text})> history = const [],
  }) async {
    if (failure != null) throw failure!;
    asked.add((
      question: question,
      materialId: materialId,
      historyLength: history.length,
    ));
    used++;
    return (
      answer: 'Answer about ${materialId ?? 'nothing in particular'}.',
      usage: AiUsage(used: used, limit: limit),
    );
  }

  @override
  Future<AiUsage> usage() async => AiUsage(used: used, limit: limit);

  @override
  Future<String> generateDeck({
    required String userId,
    required String materialId,
    required String title,
    String? subjectId,
  }) async {
    if (failure != null) throw failure!;
    generated.add(materialId);
    return 'deck-$materialId';
  }

  @override
  Future<void> generateSummary({
    required String userId,
    required String materialId,
  }) async {
    if (failure != null) throw failure!;
    generated.add(materialId);
  }

  @override
  Future<String> generateQuiz({
    required String userId,
    required String materialId,
    required String title,
  }) async {
    if (failure != null) throw failure!;
    generated.add(materialId);
    return 'quiz-$materialId';
  }
}

class FakeChatRepository implements ChatRepository {
  /// Transcripts keyed by thread id — **one per document**, which is the whole
  /// point of the real `currentThreadId`. A single shared list would let a
  /// test pass while the app leaked one document's conversation into another.
  /// Every thread starts empty, as a real one does.
  final _byThread = <String, List<ChatMessage>>{};

  /// The thread id for a document, or `general` when none is held.
  @override
  Future<String> currentThreadId(String userId, {String? materialId}) async =>
      materialId == null ? 'general' : 'thread-$materialId';

  @override
  Future<List<ChatMessage>> messages(String threadId) async =>
      List.of(_byThread[threadId] ?? const []);

  @override
  Future<void> append({
    required String threadId,
    required String userId,
    required ChatMessage message,
  }) async =>
      (_byThread[threadId] ??= []).add(message);
}

class FakeStorageRepository implements StorageRepository {
  @override
  Future<String> uploadMaterial({
    required String userId,
    required dynamic file,
    required String fileName,
    String? contentType,
    void Function(double sent)? onProgress,
  }) async {
    // Drive the readout the way a real transfer would, so a test can assert on
    // a partial percentage rather than only on 0 and 100.
    onProgress?.call(0.5);
    return '$userId/$fileName';
  }

  /// What was written as a text material, so a test can check the note's body
  /// actually reached storage rather than only that the screen navigated.
  final texts = <String, String>{};

  @override
  Future<String> uploadText({
    required String userId,
    required String fileName,
    required String text,
  }) async {
    texts[fileName] = text;
    return '$userId/$fileName';
  }

  /// A tiny UTF-8 body, so the text viewer has something to render and the
  /// image/PDF branches get bytes rather than null.
  @override
  Future<Uint8List> download(String path) async =>
      Uint8List.fromList(utf8.encode('Fake document body for $path'));

  @override
  Future<String> signedUrl(String path, {Duration ttl = const Duration(hours: 1)}) async =>
      'https://example.test/$path';

  @override
  Future<void> delete(String path) async {}
}
