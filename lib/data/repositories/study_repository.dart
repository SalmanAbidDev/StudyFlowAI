// lib/data/repositories/study_repository.dart
//
// Decks, flashcards and quizzes — the two "practice" surfaces.

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/flashcard.dart';
import '../models/quiz.dart';

class StudyRepository {
  const StudyRepository(this._client);

  final SupabaseClient _client;

  /// The newest deck, whatever it was built from. Only used when a practice
  /// screen is opened without a document selected.
  Future<Deck?> firstDeck() => _deck();

  /// The deck built from [materialId], or null when nothing has been generated
  /// for that document yet — the state the Generate button exists for.
  Future<Deck?> deckForMaterial(String materialId) => _deck(materialId);

  Future<Deck?> _deck([String? materialId]) async {
    var query = _client.from('decks').select('id, title');
    if (materialId != null) query = query.eq('material_id', materialId);

    final deck = await query
        // Newest deck. Explicit because postgrest-dart's `ascending` defaults
        // to false — every `.order` in this app states its direction so the
        // reader never has to know that.
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    if (deck == null) return null;

    final cards = await _client
        .from('flashcards')
        .select()
        .eq('deck_id', deck['id'] as String)
        .order('position', ascending: true);

    return Deck(
      id: deck['id'] as String,
      title: deck['title'] as String,
      cards: cards.map(Flashcard.fromRow).toList(),
    );
  }

  /// How much of each material's practice has actually been done.
  ///
  /// A card counts as done once it has been reviewed — `reviewCard` moves
  /// `interval_days` off zero, so "reviewed" is a fact in the table rather
  /// than a flag the app has to remember. A quiz counts once a run has been
  /// recorded in `quiz_attempts`; there is no per-question row to count, so a
  /// quiz is all-or-nothing by design rather than by accident.
  ///
  /// Three requests, not one per material: this feeds the library list, the
  /// day's tasks and every exam's preparation, so it has to be cheap.
  Future<Map<String, ({int done, int total})>> progressByMaterial() async {
    final decks = await _client
        .from('decks')
        .select('material_id, flashcards(interval_days)');
    final quizzes = await _client
        .from('quizzes')
        .select('id, material_id, quiz_questions(id)');
    final attempts = await _client.from('quiz_attempts').select('quiz_id');

    final attempted = {
      for (final row in attempts)
        if (row['quiz_id'] != null) row['quiz_id'] as String,
    };

    final out = <String, ({int done, int total})>{};
    void add(String? materialId, int done, int total) {
      if (materialId == null || total == 0) return;
      final prior = out[materialId] ?? (done: 0, total: 0);
      out[materialId] = (done: prior.done + done, total: prior.total + total);
    }

    for (final deck in decks) {
      final cards = ((deck['flashcards'] as List?) ?? const [])
          .cast<Map<String, dynamic>>();
      final reviewed = cards
          .where((c) => ((c['interval_days'] as num?) ?? 0) > 0)
          .length;
      add(deck['material_id'] as String?, reviewed, cards.length);
    }

    for (final quiz in quizzes) {
      final questions = ((quiz['quiz_questions'] as List?) ?? const []).length;
      final done = attempted.contains(quiz['id'] as String) ? questions : 0;
      add(quiz['material_id'] as String?, done, questions);
    }

    return out;
  }

  /// SM-2 style: a card you got right moves further out, a card you missed
  /// comes back tomorrow. The ease floor of 1.3 is what stops a repeatedly
  /// failed card from collapsing to an interval it can never climb out of.
  Future<void> reviewCard(
    Flashcard card, {
    required bool remembered,
    required double ease,
    required int intervalDays,
  }) {
    final nextEase =
        remembered ? ease + 0.1 : (ease - 0.2).clamp(1.3, double.infinity);
    final nextInterval = remembered ? (intervalDays == 0 ? 1 : (intervalDays * nextEase).round()) : 1;

    return _client.from('flashcards').update({
      'ease': nextEase,
      'interval_days': nextInterval,
      'due_at': DateTime.now().add(Duration(days: nextInterval)).toIso8601String(),
    }).eq('id', card.id);
  }

  /// The newest quiz, whatever it was built from.
  Future<Quiz?> firstQuiz() => _quiz();

  /// The quiz built from [materialId], or null when there is not one yet.
  Future<Quiz?> quizForMaterial(String materialId) => _quiz(materialId);

  /// Questions and options in one request: PostgREST nests the embedded rows.
  Future<Quiz?> _quiz([String? materialId]) async {
    var query = _client.from('quizzes').select(
          'id, title, quiz_questions(id, position, prompt, explanation, '
          'quiz_options(id, position, label, body, is_correct))',
        );
    if (materialId != null) query = query.eq('material_id', materialId);

    final row = await query
        // Newest quiz — see the note in `firstDeck`.
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    if (row == null) return null;

    final questions = ((row['quiz_questions'] as List?) ?? const [])
        .cast<Map<String, dynamic>>()
        .toList()
      ..sort((a, b) => (a['position'] as int).compareTo(b['position'] as int));

    return Quiz(
      id: row['id'] as String,
      title: row['title'] as String,
      questions: questions.map((q) {
        final options = ((q['quiz_options'] as List?) ?? const [])
            .cast<Map<String, dynamic>>()
            .toList()
          ..sort(
            (a, b) => (a['position'] as int).compareTo(b['position'] as int),
          );
        return QuizQuestion.fromRow({...q, 'quiz_options': options});
      }).toList(),
    );
  }

  /// The most recent completed run, which is what Home's suggestion card
  /// reasons from. Null until the user has finished a quiz.
  Future<QuizAttempt?> latestAttempt() async {
    final row = await _client
        .from('quiz_attempts')
        .select('correct, total, missed, quizzes(material_id)')
        .order('completed_at', ascending: false)
        .limit(1)
        .maybeSingle();
    return row == null ? null : QuizAttempt.fromRow(row);
  }

  Future<void> recordAttempt({
    required String userId,
    required String? quizId,
    required int correct,
    required int total,
    required int elapsedSeconds,
    required List<String> missed,
  }) {
    return _client.from('quiz_attempts').insert({
      'user_id': userId,
      'quiz_id': quizId,
      'correct': correct,
      'total': total,
      'elapsed_seconds': elapsedSeconds,
      'missed': missed,
    });
  }
}
