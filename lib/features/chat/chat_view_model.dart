// lib/features/chat/chat_view_model.dart
//
// "Chat with your notes". Replies are picked from a fixed table after a short
// fake latency — no model is called.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'chat_models.dart';

class ChatViewModel extends Notifier<ChatSession> {
  Timer? _replyTimer;

  @override
  ChatSession build() {
    // The timer is owned by the view model, so it is cancelled when the
    // provider goes away rather than depending on a widget remembering to.
    ref.onDispose(() => _replyTimer?.cancel());
    return const ChatSession(messages: openingTranscript);
  }

  void send(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return;

    state = state.copyWith(
      messages: [...state.messages, ChatMessage.fromUser(text)],
      typing: true,
    );

    final entry = chatScript.firstWhere(
      (e) => e.match.isNotEmpty && text.toLowerCase().contains(e.match),
      orElse: () => chatScript.last,
    );

    _replyTimer?.cancel();
    _replyTimer = Timer(const Duration(milliseconds: 1400), () {
      state = state.copyWith(
        typing: false,
        messages: [
          ...state.messages,
          ChatMessage.fromFlow(entry.reply, sources: entry.sources),
        ],
      );
    });
  }

  /// Drops back to the opening transcript.
  void reset() {
    _replyTimer?.cancel();
    state = const ChatSession(messages: openingTranscript);
  }
}

/// autoDispose so reopening the chat starts a fresh conversation.
final chatProvider =
    NotifierProvider.autoDispose<ChatViewModel, ChatSession>(ChatViewModel.new);
