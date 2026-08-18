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
  FakeLibraryRepository({this.empty = false})
      : _materials = empty
            ? []
            : [
                _material('m1', kFakeMaterialTitle, 'Organic Chemistry',
                    SubjectAccent.indigo, 0.42),
                _material('m2', 'Monetary Policy Lecture', 'Macroeconomics',
                    SubjectAccent.emerald, 1),
              ];

  final bool empty;
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
  Future<List<SummarySection>> summaryFor(String materialId) async => const [
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
  FakePlannerRepository({this.empty = false});

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

  var _blocks = <StudyBlock>[
    const StudyBlock(
      id: 'b1',
      title: 'Stereochem · Read Ch 4',
      accent: SubjectAccent.indigo,
      icon: Icons.science_outlined,
      position: 0,
      done: false,
      startsAt: TimeOfDay(hour: 8, minute: 0),
      endsAt: TimeOfDay(hour: 9, minute: 30),
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

  /// Three days running, ending today, with 90 minutes on each — enough to
  /// tell a real streak from a hard-coded one.
  @override
  Future<List<CompletedBlock>> completedBlocks() async {
    if (empty) return const [];
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return [
      for (var i = 0; i < 3; i++)
        CompletedBlock(
          day: today.subtract(Duration(days: i)),
          minutes: 90,
        ),
    ];
  }

  @override
  Future<List<StudyBlock>> blocksOn(DateTime day) async => empty ? [] : _blocks;

  @override
  Future<void> saveOrder(List<StudyBlock> blocks) async => _blocks = blocks;

  @override
  Future<void> setBlockDone(String blockId, {required bool done}) async {}

  @override
  Future<void> createBlock({
    required String userId,
    required String title,
    required DateTime day,
    String? subjectId,
    int position = 0,
  }) async {}

  @override
  Future<List<Exam>> upcomingExams() async => empty ? [] : [
        Exam(
          id: 'e1',
          title: 'Organic Chem Final',
          examDate: DateTime.now().add(const Duration(days: 9)),
          preparation: 0.62,
          accent: SubjectAccent.coral,
        ),
      ];
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

class FakeChatRepository implements ChatRepository {
  var _messages = <ChatMessage>[...openingTranscript];

  @override
  Future<String> currentThreadId(String userId) async => 't1';

  @override
  Future<List<ChatMessage>> messages(String threadId) async => _messages;

  @override
  Future<void> append({
    required String threadId,
    required String userId,
    required ChatMessage message,
  }) async =>
      _messages = [..._messages, message];

  @override
  Future<void> reset(String threadId, String userId) async =>
      _messages = [...openingTranscript];
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
