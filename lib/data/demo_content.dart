// lib/data/demo_content.dart
//
// Static sample content for the UI build. Everything here is hard-coded on
// purpose — there is no backend, no API, and no AI service behind this app
// yet. Swap these lists for repository calls when the data layer lands.

import 'package:flutter/material.dart';

import '../theme/theme.dart';

/// Which accent a subject is painted with. Resolved against the theme so the
/// same subject reads correctly in light and dark.
enum SubjectAccent { indigo, emerald, violet, coral, amber }

extension SubjectAccentColor on SubjectAccent {
  Color color(BuildContext context) {
    final sf = context.sf;
    return switch (this) {
      SubjectAccent.indigo => context.scheme.primary,
      SubjectAccent.emerald => sf.emerald,
      SubjectAccent.violet => sf.violet,
      SubjectAccent.coral => sf.coral,
      SubjectAccent.amber => sf.amber,
    };
  }
}

// ─── Materials ────────────────────────────────────────────────────────────

class StudyMaterial {
  const StudyMaterial({
    required this.title,
    required this.meta,
    required this.progress,
    required this.accent,
    required this.icon,
    required this.tag,
  });

  final String title;
  final String meta;
  final double progress;
  final SubjectAccent accent;
  final IconData icon;
  final String tag;
}

const demoMaterials = <StudyMaterial>[
  StudyMaterial(
    title: 'Stereochemistry & Chirality',
    meta: 'Organic Chem · 14 pages',
    progress: 0.42,
    accent: SubjectAccent.indigo,
    icon: Icons.science_outlined,
    tag: 'Chemistry',
  ),
  StudyMaterial(
    title: 'Monetary Policy Lecture',
    meta: 'Macro · 22 slides',
    progress: 1,
    accent: SubjectAccent.emerald,
    icon: Icons.show_chart_rounded,
    tag: 'Economics',
  ),
  StudyMaterial(
    title: 'Linear Algebra Notes',
    meta: 'Math · 38 pages',
    progress: 0.78,
    accent: SubjectAccent.violet,
    icon: Icons.menu_book_outlined,
    tag: 'Math',
  ),
  StudyMaterial(
    title: 'IELTS Reading Pack',
    meta: 'Test prep · 8 pages',
    progress: 0.15,
    accent: SubjectAccent.coral,
    icon: Icons.description_outlined,
    tag: 'IELTS',
  ),
  StudyMaterial(
    title: 'CRISPR Cas9 Mechanism',
    meta: 'Biology · 6 pages',
    progress: 0,
    accent: SubjectAccent.amber,
    icon: Icons.science_outlined,
    tag: 'Biology',
  ),
];

const demoLibraryFilters = <({String label, int count})>[
  (label: 'All', count: 12),
  (label: 'Chemistry', count: 3),
  (label: 'Biology', count: 2),
  (label: 'Math', count: 4),
  (label: 'IELTS', count: 3),
];

// ─── Planner ──────────────────────────────────────────────────────────────

class StudyBlock {
  const StudyBlock({
    required this.id,
    required this.title,
    required this.window,
    required this.duration,
    required this.accent,
    required this.icon,
  });

  final int id;
  final String title;
  final String window;
  final String duration;
  final SubjectAccent accent;
  final IconData icon;
}

const demoStudyBlocks = <StudyBlock>[
  StudyBlock(
    id: 1,
    title: 'Stereochem · Read Ch 4',
    window: '08:00 – 09:30',
    duration: '1h 30m',
    accent: SubjectAccent.indigo,
    icon: Icons.science_outlined,
  ),
  StudyBlock(
    id: 2,
    title: 'Macro · Lecture review',
    window: '10:00 – 10:45',
    duration: '45m',
    accent: SubjectAccent.emerald,
    icon: Icons.show_chart_rounded,
  ),
  StudyBlock(
    id: 3,
    title: 'Linear Alg · Practice set',
    window: '13:00 – 14:00',
    duration: '1h',
    accent: SubjectAccent.violet,
    icon: Icons.menu_book_outlined,
  ),
  StudyBlock(
    id: 4,
    title: 'IELTS · Reading mock',
    window: '16:00 – 17:00',
    duration: '1h',
    accent: SubjectAccent.coral,
    icon: Icons.description_outlined,
  ),
];

// ─── Exams ────────────────────────────────────────────────────────────────

class Exam {
  const Exam({
    required this.title,
    required this.date,
    required this.daysLeft,
    required this.preparation,
    required this.accent,
  });

  final String title;
  final String date;
  final int daysLeft;
  final double preparation;
  final SubjectAccent accent;
}

const demoExams = <Exam>[
  Exam(
    title: 'Organic Chem Final',
    date: 'May 15',
    daysLeft: 9,
    preparation: 0.62,
    accent: SubjectAccent.coral,
  ),
  Exam(
    title: 'Macroeconomics',
    date: 'May 22',
    daysLeft: 16,
    preparation: 0.45,
    accent: SubjectAccent.amber,
  ),
  Exam(
    title: 'Linear Algebra',
    date: 'June 03',
    daysLeft: 28,
    preparation: 0.78,
    accent: SubjectAccent.indigo,
  ),
  Exam(
    title: 'IELTS Speaking',
    date: 'June 14',
    daysLeft: 39,
    preparation: 0.30,
    accent: SubjectAccent.violet,
  ),
];

// ─── Flashcards ───────────────────────────────────────────────────────────

class Flashcard {
  const Flashcard({
    required this.question,
    required this.answer,
    required this.tag,
    required this.source,
  });

  final String question;
  final String answer;
  final String tag;
  final String source;
}

const demoDeck = <Flashcard>[
  Flashcard(
    question: 'What defines a chiral molecule?',
    answer:
        'A molecule that cannot be superimposed on its mirror image. Most often '
        'arises when a carbon has 4 different substituents.',
    tag: 'Chemistry',
    source: 'Stereochem.pdf · p.4',
  ),
  Flashcard(
    question: 'R vs S configuration?',
    answer:
        'Assign CIP priorities; with lowest priority pointing away, clockwise = R, '
        'counterclockwise = S.',
    tag: 'Chemistry',
    source: 'Stereochem.pdf · p.5',
  ),
  Flashcard(
    question: 'What is a racemic mixture?',
    answer:
        'A 50:50 mix of two enantiomers — optically inactive because rotations '
        'cancel.',
    tag: 'Chemistry',
    source: 'Stereochem.pdf · p.6',
  ),
  Flashcard(
    question: 'Diastereomer vs enantiomer?',
    answer:
        "Enantiomers are mirror images; diastereomers are stereoisomers that "
        "aren't mirror images.",
    tag: 'Chemistry',
    source: 'Stereochem.pdf · p.7',
  ),
];

// ─── Summary ──────────────────────────────────────────────────────────────

class SummarySection {
  const SummarySection({
    required this.title,
    required this.read,
    required this.bullets,
  });

  final String title;
  final bool read;

  /// `**bold**` spans are rendered in the brand colour.
  final List<String> bullets;
}

const demoSummary = <SummarySection>[
  SummarySection(
    title: '4.1 Chirality & Stereocenters',
    read: true,
    bullets: [
      'A **chiral** molecule cannot be superimposed on its mirror image.',
      'A **stereocenter** is an atom (often carbon) bonded to four different groups.',
      'The simplest test: look for a tetrahedral C with four distinct substituents.',
    ],
  ),
  SummarySection(
    title: '4.2 R/S Configuration',
    read: true,
    bullets: [
      'Assign priorities by atomic number (Cahn–Ingold–Prelog rules).',
      'View with lowest priority away — **clockwise = R**, counterclockwise = S.',
    ],
  ),
  SummarySection(
    title: '4.3 Optical Activity',
    read: false,
    bullets: [
      'Enantiomers rotate plane-polarized light in opposite directions.',
      'Specific rotation is intrinsic; observed rotation depends on concentration.',
    ],
  ),
  SummarySection(
    title: '4.4 Diastereomers & Meso',
    read: false,
    bullets: [],
  ),
];

// ─── Quiz ─────────────────────────────────────────────────────────────────

class QuizOption {
  const QuizOption(this.id, this.text, {this.correct = false});

  final String id;
  final String text;
  final bool correct;
}

class QuizQuestion {
  const QuizQuestion({
    required this.prompt,
    required this.options,
    required this.explanation,
  });

  final String prompt;
  final List<QuizOption> options;
  final String explanation;
}

const demoQuiz = <QuizQuestion>[
  QuizQuestion(
    prompt: 'Which statement about diastereomers is correct?',
    options: [
      QuizOption('a', 'They are non-superimposable mirror images of each other'),
      QuizOption('b', 'They have identical physical properties'),
      QuizOption('c', 'They are stereoisomers that are not mirror images',
          correct: true),
      QuizOption('d', 'They cannot have stereocenters'),
    ],
    explanation:
        "Diastereomers are stereoisomers that aren't mirror images, so they have "
        '**distinct physical properties** (mp, solubility). Mirror-image pairs '
        'are enantiomers.',
  ),
  QuizQuestion(
    prompt: 'A carbon bonded to four different groups is called a…',
    options: [
      QuizOption('a', 'Stereocenter', correct: true),
      QuizOption('b', 'Meso carbon'),
      QuizOption('c', 'Racemic carbon'),
      QuizOption('d', 'Prochiral centre'),
    ],
    explanation:
        'Four distinct substituents on a tetrahedral carbon make it a '
        '**stereocenter** — the usual origin of chirality in organic molecules.',
  ),
  QuizQuestion(
    prompt: 'A racemic mixture is optically inactive because…',
    options: [
      QuizOption('a', 'Neither enantiomer rotates light'),
      QuizOption('b', 'The two rotations cancel out', correct: true),
      QuizOption('c', 'It contains only meso compounds'),
      QuizOption('d', 'The sample is too dilute to measure'),
    ],
    explanation:
        'Equal amounts of two enantiomers rotate plane-polarized light by equal '
        'and **opposite** amounts, so the net rotation is zero.',
  ),
];

// ─── Analytics ────────────────────────────────────────────────────────────

const demoWeeklyHours = <double>[3, 4.5, 2, 5, 3.5, 1.5, 4];

const demoSubjectBreakdown = <({String label, String hours, double share, SubjectAccent accent})>[
  (label: 'Organic Chemistry', hours: '8.5h', share: 0.80, accent: SubjectAccent.indigo),
  (label: 'Macroeconomics', hours: '5.2h', share: 0.55, accent: SubjectAccent.emerald),
  (label: 'Linear Algebra', hours: '4.8h', share: 0.50, accent: SubjectAccent.violet),
  (label: 'IELTS Prep', hours: '5.0h', share: 0.52, accent: SubjectAccent.coral),
];

// ─── Premium ──────────────────────────────────────────────────────────────

/// `null` means "not included"; `true` means a plain check; a string is shown
/// verbatim.
const demoPlanMatrix = <({String label, Object? free, Object? pro})>[
  (label: 'Unlimited AI summaries', free: null, pro: true),
  (label: 'Unlimited Flow chats', free: null, pro: true),
  (label: 'Advanced flashcard decks', free: '3 decks', pro: 'Unlimited'),
  (label: 'Quiz explanations', free: 'Basic', pro: 'Detailed'),
  (label: 'Study plans', free: null, pro: true),
  (label: 'Analytics & focus score', free: null, pro: true),
  (label: 'Priority model', free: null, pro: true),
];
