// test/fakes/fake_repositories.dart
//
// In-memory stand-ins for the Supabase-backed repositories. Overriding at the
// repository seam keeps the suite hermetic — no Supabase singleton, no URL, no
// HTTP — while still exercising the real view models, providers and widgets
// above them.

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
  final _materials = [
    _material('m1', kFakeMaterialTitle, 'Organic Chemistry',
        SubjectAccent.indigo, 0.42),
    _material('m2', 'Monetary Policy Lecture', 'Macroeconomics',
        SubjectAccent.emerald, 1),
  ];

  @override
  Future<List<StudyMaterial>> materials() async => _materials;

  @override
  Future<StudyMaterial?> latestMaterial() async => _materials.first;

  @override
  Future<List<Subject>> subjects() async => const [];

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
    String? mimeType,
    int? byteSize,
    int? pageCount,
  }) async =>
      _material('new', title, 'Unfiled', SubjectAccent.indigo, 0);

  @override
  Future<void> deleteMaterial(String materialId) async {}
}

class FakePlannerRepository implements PlannerRepository {
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

  @override
  Future<List<StudyBlock>> blocksOn(DateTime day) async => _blocks;

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
  Future<List<Exam>> upcomingExams() async => [
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
  @override
  Future<Deck?> firstDeck() async => const Deck(
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
  Future<Quiz?> firstQuiz() async => const Quiz(
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

  @override
  Future<List<Achievement>> achievements() async => const [
        Achievement(
          code: 'hot_streak',
          name: 'Hot streak',
          detail: '10 days',
          earned: true,
        ),
      ];

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
  }) async =>
      '$userId/$fileName';

  @override
  Future<String> signedUrl(String path, {Duration ttl = const Duration(hours: 1)}) async =>
      'https://example.test/$path';

  @override
  Future<void> delete(String path) async {}
}
