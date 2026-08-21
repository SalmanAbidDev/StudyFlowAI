// lib/data/repositories/chat_repository.dart
//
// Persistence for the chat transcript. A new thread starts *empty* — it used
// to be seeded with a scripted exchange about stereochemistry, which put words
// in the user's mouth and made a chapter they had never uploaded look read.

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/chat/chat_models.dart';

class ChatRepository {
  const ChatRepository(this._client);

  final SupabaseClient _client;

  /// The thread for [materialId], or a fresh empty one.
  ///
  /// **One conversation per document.** Asking about a chapter and asking about
  /// last week's lecture notes are different conversations, and interleaving
  /// them in a single transcript would also mean handing a model context from
  /// a document the question is not about. `null` is its own thread — the
  /// general one, held when no document is selected.
  Future<String> currentThreadId(String userId, {String? materialId}) async {
    final base = _client.from('chat_threads').select('id');
    // `.eq(column, null)` does not express IS NULL in PostgREST; the general
    // thread would never be found again and a new one would be created on
    // every open.
    final scoped = materialId == null
        ? base.isFilter('material_id', null)
        : base.eq('material_id', materialId);

    final existing = await scoped
        .order('updated_at', ascending: false)
        .limit(1)
        .maybeSingle();
    if (existing != null) return existing['id'] as String;

    // Title is left to the column default until there is something to name it
    // after — the first real question, once a model is answering them.
    final created = await _client
        .from('chat_threads')
        .insert({
          'user_id': userId,
          'material_id': ?materialId,
        })
        .select('id')
        .single();
    return created['id'] as String;
  }

  Future<List<ChatMessage>> messages(String threadId) async {
    final rows = await _client
        .from('chat_messages')
        .select()
        .eq('thread_id', threadId)
        // `ascending` is REQUIRED here. postgrest-dart defaults it to *false*,
        // so a bare `.order('created_at')` returns newest-first and the whole
        // conversation loads back to front — correct while you type, because
        // the message is appended locally, and reversed the moment you reopen
        // the screen and it is re-read.
        .order('created_at', ascending: true);

    return rows.map((row) {
      final sources =
          ((row['sources'] as List?) ?? const []).map((s) => s as String).toList();
      final text = row['content'] as String;
      return row['role'] == 'flow'
          ? ChatMessage.fromFlow(text, sources: sources)
          : ChatMessage.fromUser(text);
    }).toList();
  }

  Future<void> append({
    required String threadId,
    required String userId,
    required ChatMessage message,
  }) async {
    await _client.from('chat_messages').insert({
      'thread_id': threadId,
      'user_id': userId,
      'role': message.fromFlow ? 'flow' : 'user',
      'content': message.text,
      'sources': message.sources,
    });
    // Keeps `currentThreadId` returning this one. Written explicitly rather
    // than as a side effect of touching another column.
    await _client
        .from('chat_threads')
        .update({'updated_at': DateTime.now().toUtc().toIso8601String()}).eq(
            'id', threadId);
  }
}
