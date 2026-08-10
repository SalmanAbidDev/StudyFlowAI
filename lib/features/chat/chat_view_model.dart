// lib/features/chat/chat_view_model.dart
//
// The transcript is persisted to Supabase; the *replies* are still the
// scripted table in chat_models.dart. No model is called — wiring an LLM is a
// separate job from wiring the backend.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/supabase_providers.dart';
import 'chat_models.dart';

/// The thread the screen reads and writes. Created with the opening exchange
/// on first use.
final chatThreadProvider = FutureProvider.autoDispose<String>(
  (ref) => ref
      .watch(chatRepositoryProvider)
      .currentThreadId(ref.watch(currentUserIdProvider)),
);

class ChatViewModel extends AsyncNotifier<ChatSession> {
  Timer? _replyTimer;

  @override
  Future<ChatSession> build() async {
    ref.onDispose(() => _replyTimer?.cancel());
    final threadId = await ref.watch(chatThreadProvider.future);
    final messages = await ref.watch(chatRepositoryProvider).messages(threadId);
    return ChatSession(messages: messages);
  }

  Future<void> send(String raw) async {
    final text = raw.trim();
    final session = state.value;
    if (text.isEmpty || session == null) return;

    final threadId = await ref.read(chatThreadProvider.future);
    final userId = ref.read(currentUserIdProvider);
    final repo = ref.read(chatRepositoryProvider);
    final outgoing = ChatMessage.fromUser(text);

    // Show it immediately, persist behind it: a chat that waits on a round
    // trip before echoing what you typed feels broken.
    state = AsyncData(
      session.copyWith(
        messages: [...session.messages, outgoing],
        typing: true,
      ),
    );
    await repo.append(threadId: threadId, userId: userId, message: outgoing);

    final entry = chatScript.firstWhere(
      (e) => e.match.isNotEmpty && text.toLowerCase().contains(e.match),
      orElse: () => chatScript.last,
    );
    final reply = ChatMessage.fromFlow(entry.reply, sources: entry.sources);

    _replyTimer?.cancel();
    _replyTimer = Timer(const Duration(milliseconds: 1400), () async {
      final current = state.value;
      if (current == null) return;
      state = AsyncData(
        current.copyWith(
          typing: false,
          messages: [...current.messages, reply],
        ),
      );
      await repo.append(threadId: threadId, userId: userId, message: reply);
    });
  }

  /// Drops the thread back to the opening exchange.
  Future<void> reset() async {
    _replyTimer?.cancel();
    final threadId = await ref.read(chatThreadProvider.future);
    await ref
        .read(chatRepositoryProvider)
        .reset(threadId, ref.read(currentUserIdProvider));
    ref.invalidateSelf();
  }
}

final chatProvider =
    AsyncNotifierProvider.autoDispose<ChatViewModel, ChatSession>(
  ChatViewModel.new,
);
