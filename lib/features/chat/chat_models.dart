// lib/features/chat/chat_models.dart
//
// The Model half of the chat feature: what a message is.
//
// There is no scripted content here any more. Every message in a transcript is
// now something the user actually typed or something a model actually said —
// nothing is invented to make the screen look busy.

/// Which accent a highlighted phrase is tinted with, resolved at build time.
enum SfAccent { brand, coral, emerald }

class ChatMessage {
  const ChatMessage.fromUser(this.text)
      : fromFlow = false,
        sources = const [],
        highlightSpecs = const [];

  const ChatMessage.fromFlow(
    this.text, {
    this.sources = const [],
    this.highlightSpecs = const [],
  }) : fromFlow = true;

  final String text;
  final bool fromFlow;
  final List<String> sources;

  /// Phrase → which accent to tint it with.
  final List<({String phrase, SfAccent accent})> highlightSpecs;
}

class ChatSession {
  const ChatSession({
    required this.messages,
    this.typing = false,
    this.notice,
  });

  final List<ChatMessage> messages;
  final bool typing;

  /// A line from the *app* rather than from Flow — currently only "no model
  /// yet". Deliberately not a [ChatMessage]: it is never persisted, so it
  /// cannot end up in the history a real model is later handed as context.
  final String? notice;

  ChatSession copyWith({
    List<ChatMessage>? messages,
    bool? typing,
    String? notice,
    bool clearNotice = false,
  }) =>
      ChatSession(
        messages: messages ?? this.messages,
        typing: typing ?? this.typing,
        // Clearable: the last failure must not outlive the next question.
        notice: clearNotice ? null : (notice ?? this.notice),
      );
}

/// Shown when the day's questions are gone. Not a message from Flow: it is
/// the app's own rule, and putting it in the transcript would leave it there
/// tomorrow when it is no longer true.
const kDailyLimitNotice =
    'That is all of your questions for today. Flow is back tomorrow.';

/// Shown when nothing is held. Flow can still answer general questions, but it
/// cannot answer *about* a document it has not been given.
const kNoDocumentNotice =
    'No document selected — pick one from the header and Flow will answer '
    'from it.';

/// Openers offered above the composer.
///
/// Every one is a *question about the held document* and document-agnostic
/// with it: a chip naming a chapter would be a promise about content the app
/// has not read, and a chip like "Make flashcards" would promise an action
/// nothing performs. The rail scrolls, so the list can grow.
const chatPrompts = [
  'Summarize it',
  "Explain like I'm 5",
  'Key takeaways',
  'Give me an example',
  'What might I be asked?',
];
