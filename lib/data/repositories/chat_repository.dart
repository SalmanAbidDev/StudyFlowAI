// lib/data/repositories/chat_repository.dart
//
// The transcript is persisted; the *replies* are still the scripted table in
// chat_models.dart. No model is called — wiring an LLM is a separate job from
// wiring the backend, and this keeps the two changes independent.

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/chat/chat_models.dart';

class ChatRepository {
  const ChatRepository(this._client);

  final SupabaseClient _client;

  /// The most recent thread, or a fresh one seeded with the opening exchange.
  Future<String> currentThreadId(String userId) async {
    final existing = await _client
        .from('chat_threads')
        .select('id')
        .order('updated_at', ascending: false)
        .limit(1)
        .maybeSingle();
    if (existing != null) return existing['id'] as String;

    final created = await _client
        .from('chat_threads')
        .insert({'user_id': userId, 'title': 'Stereochemistry'})
        .select('id')
        .single();
    final threadId = created['id'] as String;

    await _client.from('chat_messages').insert([
      for (final message in openingTranscript)
        {
          'thread_id': threadId,
          'user_id': userId,
          'role': message.fromFlow ? 'flow' : 'user',
          'content': message.text,
          'sources': message.sources,
        },
    ]);
    return threadId;
  }

  Future<List<ChatMessage>> messages(String threadId) async {
    final rows = await _client
        .from('chat_messages')
        .select()
        .eq('thread_id', threadId)
        .order('created_at');

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
    // Bumps updated_at so `currentThreadId` keeps returning this one.
    await _client
        .from('chat_threads')
        .update({'title': 'Stereochemistry'}).eq('id', threadId);
  }

  /// Wipes the thread back to the opening exchange.
  Future<void> reset(String threadId, String userId) async {
    await _client.from('chat_messages').delete().eq('thread_id', threadId);
    await _client.from('chat_messages').insert([
      for (final message in openingTranscript)
        {
          'thread_id': threadId,
          'user_id': userId,
          'role': message.fromFlow ? 'flow' : 'user',
          'content': message.text,
          'sources': message.sources,
        },
    ]);
  }
}
