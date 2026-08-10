// lib/data/repositories/study_repository.dart
//
// Decks, flashcards and quizzes — the two "practice" surfaces.

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/flashcard.dart';
import '../models/quiz.dart';

class StudyRepository {
  const StudyRepository(this._client);

  final SupabaseClient _client;

  /// The first deck with its cards, which is what the Flashcards screen opens
  /// on. Returns null when the account has no decks yet.
  Future<Deck?> firstDeck() async {
    final deck = await _client
        .from('decks')
        .select('id, title')
        .order('created_at')
        .limit(1)
        .maybeSingle();
    if (deck == null) return null;

    final cards = await _client
        .from('flashcards')
        .select()
        .eq('deck_id', deck['id'] as String)
        .order('position');

    return Deck(
      id: deck['id'] as String,
      title: deck['title'] as String,
      cards: cards.map(Flashcard.fromRow).toList(),
    );
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

  /// The first quiz with its questions and options, ordered. One request:
  /// PostgREST nests the embedded rows.
  Future<Quiz?> firstQuiz() async {
    final row = await _client
        .from('quizzes')
        .select(
          'id, title, quiz_questions(id, position, prompt, explanation, '
          'quiz_options(id, position, label, body, is_correct))',
        )
        .order('created_at')
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
