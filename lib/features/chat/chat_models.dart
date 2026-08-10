// lib/features/chat/chat_models.dart
//
// The Model half of the chat feature: what a message is, and the scripted
// content the view model serves.

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
  const ChatSession({required this.messages, this.typing = false});

  final List<ChatMessage> messages;
  final bool typing;

  ChatSession copyWith({List<ChatMessage>? messages, bool? typing}) =>
      ChatSession(
        messages: messages ?? this.messages,
        typing: typing ?? this.typing,
      );
}

/// The transcript the screen opens on.
const openingTranscript = <ChatMessage>[
  ChatMessage.fromFlow(
    "Hi Alex — I've read your Stereochemistry chapter. Ask me anything "
    'about it.',
    sources: ['Stereochem.pdf · p.1'],
  ),
  ChatMessage.fromUser(
    "What's the difference between enantiomers and diastereomers?",
  ),
  ChatMessage.fromFlow(
    'Enantiomers are non-superimposable mirror images — they share all '
    'properties except how they rotate plane-polarized light. Diastereomers '
    "are stereoisomers that aren't mirror images, so they have distinct "
    'physical properties (melting point, solubility, etc.).',
    sources: ['Stereochem.pdf · p.4', 'Stereochem.pdf · p.7'],
    highlightSpecs: [
      (phrase: 'non-superimposable mirror images', accent: SfAccent.brand),
      (phrase: "aren't mirror images", accent: SfAccent.coral),
    ],
  ),
];

/// Scripted answers. Matched on a lowercase substring of the prompt; the last
/// entry is the fallback. No model is called — see the note in main.dart.
const chatScript = <({String match, String reply, List<String> sources})>[
  (
    match: 'quiz',
    reply: "Sure — I'll pull 10 questions from chapter 4, weighted toward R/S "
        'assignment since that is where you lost marks last time.',
    sources: ['Stereochem.pdf · p.4-9'],
  ),
  (
    match: 'summar',
    reply: 'Chapter 4 in one line: chirality comes from a carbon with four '
        'different groups; R/S encodes its arrangement; enantiomers differ '
        'only in optical rotation, diastereomers differ in everything else.',
    sources: ['Stereochem.pdf · p.1-14'],
  ),
  (
    match: 'flashcard',
    reply: 'Made you 12 cards from this chapter. The four you failed last week '
        'are queued first.',
    sources: ['Stereochem.pdf · p.4'],
  ),
  (
    match: '5',
    reply: 'Your left hand and right hand are mirror images, but you cannot lay '
        'one exactly on the other. Molecules can be like that too — those '
        'are enantiomers.',
    sources: ['Stereochem.pdf · p.2'],
  ),
  (
    match: '',
    reply: 'A racemic mixture is a 50:50 mix of two enantiomers — optically '
        'inactive because their rotations cancel.',
    sources: ['Stereochem.pdf · p.6'],
  ),
];

const chatPrompts = [
  'Quiz me on this',
  'Summarize ch.4',
  'Make flashcards',
  "Explain like I'm 5",
];
