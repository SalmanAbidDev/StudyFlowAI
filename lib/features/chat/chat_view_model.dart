// lib/features/chat/chat_view_model.dart
//
// The transcript is persisted to Supabase and answered by Gemini, through the
// `ai` Edge Function — the app never holds the key (see `ai_config.dart`).
//
// Flow answers **from the held document**: the function sends the actual file
// (or the URL, for a link) alongside the question, so "reading Chapter 4" is
// something it is doing rather than something the header claims.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/view_models.dart';
import '../../data/models/study_material.dart';
import '../../data/repositories/ai_repository.dart';
import '../../data/supabase_providers.dart';
import '../materials/materials_view_model.dart';
import 'chat_models.dart';

/// The document Flow is holding — the only thing it will be given as context
/// once a model is wired up. Null is a real, named state ("No document
/// selected"), not a placeholder for one.
///
/// Set from the header's picker, and from Home's "Flow suggests" card, which
/// hands over the document it just named rather than making you find it again.
final chatDocumentProvider =
    NotifierProvider<ValueViewModel<String?>, String?>(
  () => ValueViewModel(null),
);

/// The held document resolved against the live library, so one deleted
/// elsewhere cannot go on being named in the header.
final chatMaterialProvider = Provider<StudyMaterial?>((ref) {
  final id = ref.watch(chatDocumentProvider);
  if (id == null) return null;
  final all = ref.watch(materialsProvider).value ?? const <StudyMaterial>[];
  return all.where((m) => m.id == id).firstOrNull;
});

/// The thread for the held document, created empty on first use. Switching
/// documents switches conversations — see `ChatRepository.currentThreadId`.
final chatThreadProvider = FutureProvider.autoDispose<String>(
  (ref) => ref.watch(chatRepositoryProvider).currentThreadId(
        ref.watch(currentUserIdProvider),
        materialId: ref.watch(chatDocumentProvider),
      ),
);

/// How many documents Flow could be pointed at. Null while the library is
/// still loading, so the empty state stays quiet rather than telling someone
/// with a full library to go and upload something.
final chatCorpusSizeProvider = Provider<int?>(
  (ref) => ref.watch(materialsProvider).value?.length,
);

/// How many of today's questions are left.
///
/// Counted **server-side**, from the user's own message rows: a client-side
/// tally would reset on reinstall and could be edited by anyone who wanted
/// more. This provider is only what the UI reads; the function enforces it.
final chatUsageProvider = FutureProvider<AiUsage>(
  (ref) => ref.watch(aiRepositoryProvider).usage(),
);

class ChatViewModel extends AsyncNotifier<ChatSession> {
  @override
  Future<ChatSession> build() async {
    final threadId = await ref.watch(chatThreadProvider.future);
    final messages = await ref.watch(chatRepositoryProvider).messages(threadId);
    return ChatSession(messages: messages);
  }

  Future<void> send(String raw) async {
    final text = raw.trim();
    final session = state.value;
    if (text.isEmpty || session == null || session.typing) return;

    final threadId = await ref.read(chatThreadProvider.future);
    final userId = ref.read(currentUserIdProvider);
    final repo = ref.read(chatRepositoryProvider);
    final outgoing = ChatMessage.fromUser(text);

    // Shown and saved before the answer is asked for: a chat that waits on a
    // round trip before echoing what you typed feels broken, and a question
    // that costs an allowance should be recorded whether or not the answer
    // arrives.
    state = AsyncData(
      session.copyWith(
        messages: [...session.messages, outgoing],
        typing: true,
        clearNotice: true,
      ),
    );
    await repo.append(threadId: threadId, userId: userId, message: outgoing);

    try {
      final result = await ref.read(aiRepositoryProvider).ask(
            question: text,
            materialId: ref.read(chatDocumentProvider),
            // The transcript so far, so a follow-up like "why?" has something
            // to refer to. The question just sent is passed separately.
            history: [
              for (final m in session.messages)
                (role: m.fromFlow ? 'flow' : 'user', text: m.text),
            ],
          );

      final reply = ChatMessage.fromFlow(result.answer);
      // Saved against the thread the question was asked in, always.
      await repo.append(threadId: threadId, userId: userId, message: reply);
      ref.invalidate(chatUsageProvider);

      // ...but only *shown* if that is still the conversation on screen.
      // Switching documents mid-answer would otherwise drop a reply about
      // Chapter 4 into the transcript for last week's lecture notes.
      if (!_stillOn(threadId)) return;
      final current = state.value;
      if (current == null) return;
      state = AsyncData(
        current.copyWith(
          typing: false,
          messages: [...current.messages, reply],
        ),
      );
    } on AiException catch (error) {
      ref.invalidate(chatUsageProvider);
      if (!_stillOn(threadId)) return;
      final current = state.value;
      if (current == null) return;
      // The failure is a notice, not a message from Flow. Persisting it would
      // leave "you are out of questions" in the transcript forever, and hand
      // it to the model as context tomorrow.
      state = AsyncData(
        current.copyWith(
          typing: false,
          notice: error.isDailyLimit ? kDailyLimitNotice : error.message,
        ),
      );
    }
  }

  /// Whether the conversation on screen is still the one [threadId] belongs
  /// to. `chatThreadProvider` is rebuilt when the held document changes, so
  /// this is the cheapest way to notice that it did.
  bool _stillOn(String threadId) =>
      ref.read(chatThreadProvider).value == threadId;
}

final chatProvider =
    AsyncNotifierProvider.autoDispose<ChatViewModel, ChatSession>(
  ChatViewModel.new,
);
