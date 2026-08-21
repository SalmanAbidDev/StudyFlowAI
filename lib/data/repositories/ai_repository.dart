// lib/data/repositories/ai_repository.dart
//
// The app's half of the AI. It invokes the `ai` Edge Function and writes what
// comes back; the function is what talks to Gemini and holds the key.
//
// **Generated content is written by the app, not by the function.** The rows
// go in under the user's own session, so Row Level Security applies to them
// exactly as it does to everything else — a function writing on the user's
// behalf would need elevated rights and would be one bug away from writing
// into someone else's library.

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/ai_config.dart';

/// Raised when the AI could not do what was asked. Carries a message written
/// for a person, because it goes straight onto the screen.
class AiException implements Exception {
  const AiException(this.message, {this.isDailyLimit = false});

  final String message;

  /// The daily allowance is a normal outcome, not a failure — the screen says
  /// so differently.
  final bool isDailyLimit;

  @override
  String toString() => message;
}

/// How many of Flow's daily questions are gone.
class AiUsage {
  const AiUsage({required this.used, required this.limit});

  final int used;
  final int limit;

  int get remaining => (limit - used).clamp(0, limit);
  bool get exhausted => remaining == 0;
}

class AiRepository {
  const AiRepository(this._client);

  final SupabaseClient _client;

  /// One call, one place to turn a failure into something readable.
  Future<Map<String, dynamic>> _invoke(Map<String, dynamic> body) async {
    late final FunctionResponse response;
    try {
      response = await _client.functions.invoke(
        AiConfig.functionName,
        body: body,
      );
    } on FunctionException catch (error) {
      // The function's own error body, which names the real cause — a missing
      // key, a file too large, Gemini's own complaint.
      final detail = error.details;
      final message = detail is Map && detail['error'] is String
          ? detail['error'] as String
          : 'The AI service could not be reached.';
      if (detail is Map && detail['error'] == 'limit') {
        throw AiException(
          "You have used all ${AiConfig.dailyChatLimit} of today's questions. "
          'Flow is back tomorrow.',
          isDailyLimit: true,
        );
      }
      throw AiException(message);
    } catch (_) {
      throw const AiException(
        'Could not reach the AI service. Check your connection and try again.',
      );
    }

    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw const AiException('The AI service returned something unexpected.');
    }
    if (data['error'] is String) throw AiException(data['error'] as String);
    return data;
  }

  /// The device's offset, so "today" means the user's today rather than UTC's.
  static int get _tzOffsetMinutes => DateTime.now().timeZoneOffset.inMinutes;

  // ─── Generation ────────────────────────────────────────────────────────

  /// Builds a deck from [materialId] and returns its id.
  Future<String> generateDeck({
    required String userId,
    required String materialId,
    required String title,
    String? subjectId,
  }) async {
    final data = await _invoke({
      'action': 'generate_flashcards',
      'materialId': materialId,
    });

    final items = (data['items'] as List?) ?? const [];
    if (items.isEmpty) {
      throw const AiException(
        'Flow could not find enough in this material to make cards from.',
      );
    }

    // Replaces rather than appends: "Generate" on an empty deck screen means
    // "make me a deck", and leaving an older one behind would silently double
    // the card count on a second attempt.
    await _client.from('decks').delete().eq('material_id', materialId);

    final deck = await _client
        .from('decks')
        .insert({
          'user_id': userId,
          'material_id': materialId,
          'subject_id': ?subjectId,
          'title': title,
        })
        .select('id')
        .single();
    final deckId = deck['id'] as String;

    await _client.from('flashcards').insert([
      for (var i = 0; i < items.length; i++)
        {
          'deck_id': deckId,
          'user_id': userId,
          'position': i,
          'question': (items[i] as Map)['question'] as String? ?? '',
          'answer': (items[i] as Map)['answer'] as String? ?? '',
          'source': (items[i] as Map)['source'] as String?,
          // Clamped rather than trusted: the schema says integer, not 1..5,
          // and a 7 would fail the column's check constraint and lose the
          // whole deck.
          'difficulty': switch ((items[i] as Map)['difficulty']) {
            final num d => d.toInt().clamp(1, 5),
            _ => null,
          },
        },
    ]);
    return deckId;
  }

  /// Writes a summary of [materialId], replacing any existing one.
  Future<void> generateSummary({
    required String userId,
    required String materialId,
  }) async {
    final data = await _invoke({
      'action': 'generate_summary',
      'materialId': materialId,
    });

    final items = (data['items'] as List?) ?? const [];
    if (items.isEmpty) {
      throw const AiException(
        'Flow could not find enough in this material to summarise.',
      );
    }

    await _client
        .from('summary_sections')
        .delete()
        .eq('material_id', materialId);

    await _client.from('summary_sections').insert([
      for (var i = 0; i < items.length; i++)
        {
          'material_id': materialId,
          'user_id': userId,
          'position': i,
          'title': (items[i] as Map)['title'] as String? ?? '',
          'bullets': [
            for (final b in ((items[i] as Map)['bullets'] as List?) ?? const [])
              b as String,
          ],
        },
    ]);
  }

  /// Builds a quiz from [materialId] and returns its id.
  Future<String> generateQuiz({
    required String userId,
    required String materialId,
    required String title,
  }) async {
    final data = await _invoke({
      'action': 'generate_quiz',
      'materialId': materialId,
    });

    final items = (data['items'] as List?) ?? const [];
    if (items.isEmpty) {
      throw const AiException(
        'Flow could not find enough in this material to write questions from.',
      );
    }

    await _client.from('quizzes').delete().eq('material_id', materialId);

    final quiz = await _client
        .from('quizzes')
        .insert({
          'user_id': userId,
          'material_id': materialId,
          'title': title,
        })
        .select('id')
        .single();
    final quizId = quiz['id'] as String;

    // Questions first, then their options — the options need the ids back, so
    // this cannot be one insert.
    final questions = await _client
        .from('quiz_questions')
        .insert([
          for (var i = 0; i < items.length; i++)
            {
              'quiz_id': quizId,
              'user_id': userId,
              'position': i,
              'prompt': (items[i] as Map)['prompt'] as String? ?? '',
              'explanation': (items[i] as Map)['explanation'] as String? ?? '',
            },
        ])
        .select('id, position');

    // Insert order is not return order; key by position rather than index.
    final idByPosition = {
      for (final q in questions) q['position'] as int: q['id'] as String,
    };

    const labels = ['A', 'B', 'C', 'D', 'E', 'F'];
    final options = <Map<String, dynamic>>[];
    for (var i = 0; i < items.length; i++) {
      final questionId = idByPosition[i];
      if (questionId == null) continue;
      final raw = ((items[i] as Map)['options'] as List?) ?? const [];
      for (var j = 0; j < raw.length && j < labels.length; j++) {
        options.add({
          'question_id': questionId,
          'user_id': userId,
          'position': j,
          'label': labels[j],
          'body': (raw[j] as Map)['body'] as String? ?? '',
          'is_correct': (raw[j] as Map)['correct'] as bool? ?? false,
        });
      }
    }
    if (options.isNotEmpty) {
      await _client.from('quiz_options').insert(options);
    }
    return quizId;
  }

  // ─── Chat ──────────────────────────────────────────────────────────────

  /// Asks Flow a question about [materialId], if one is held.
  ///
  /// [history] is the transcript so far, oldest first, so the answer follows
  /// the conversation rather than treating every question as the first.
  Future<({String answer, AiUsage usage})> ask({
    required String question,
    String? materialId,
    List<({String role, String text})> history = const [],
  }) async {
    final data = await _invoke({
      'action': 'chat',
      'question': question,
      'materialId': materialId,
      'tzOffsetMinutes': _tzOffsetMinutes,
      'history': [
        for (final m in history) {'role': m.role, 'text': m.text},
      ],
    });

    return (
      answer: data['answer'] as String? ?? '',
      usage: AiUsage(
        used: (data['used'] as num?)?.toInt() ?? 0,
        limit: (data['limit'] as num?)?.toInt() ?? AiConfig.dailyChatLimit,
      ),
    );
  }

  /// How many questions are left today. Counted server-side from rows the user
  /// cannot edit, so it survives a reinstall.
  Future<AiUsage> usage() async {
    final data = await _invoke({
      'action': 'usage',
      'tzOffsetMinutes': _tzOffsetMinutes,
    });
    return AiUsage(
      used: (data['used'] as num?)?.toInt() ?? 0,
      limit: (data['limit'] as num?)?.toInt() ?? AiConfig.dailyChatLimit,
    );
  }
}
