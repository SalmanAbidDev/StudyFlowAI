// lib/screens/chat_screen.dart
//
// "Chat with your notes". The conversation is entirely scripted — replies are
// picked from a fixed table after a short fake latency. No model is called.

import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/theme.dart';
import '../widgets/widgets.dart';

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

  /// Phrase → which accent to tint it with, resolved at build time.
  final List<({String phrase, SfAccent accent})> highlightSpecs;
}

enum SfAccent { brand, coral, emerald }

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  Timer? _replyTimer;
  bool _typing = false;

  final _messages = <ChatMessage>[
    const ChatMessage.fromFlow(
      "Hi Alex — I've read your Stereochemistry chapter. Ask me anything "
      'about it.',
      sources: ['Stereochem.pdf · p.1'],
    ),
    const ChatMessage.fromUser(
      "What's the difference between enantiomers and diastereomers?",
    ),
    const ChatMessage.fromFlow(
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

  /// Scripted answers. Matched on a lowercase substring of the prompt; the
  /// last entry is the fallback.
  static const _script = <({String match, String reply, List<String> sources})>[
    (
      match: 'quiz',
      reply:
          "Sure — I'll pull 10 questions from chapter 4, weighted toward R/S "
          'assignment since that is where you lost marks last time.',
      sources: ['Stereochem.pdf · p.4-9'],
    ),
    (
      match: 'summar',
      reply:
          'Chapter 4 in one line: chirality comes from a carbon with four '
          'different groups; R/S encodes its arrangement; enantiomers differ '
          'only in optical rotation, diastereomers differ in everything else.',
      sources: ['Stereochem.pdf · p.1-14'],
    ),
    (
      match: 'flashcard',
      reply:
          'Made you 12 cards from this chapter. The four you failed last week '
          'are queued first.',
      sources: ['Stereochem.pdf · p.4'],
    ),
    (
      match: '5',
      reply:
          'Your left hand and right hand are mirror images, but you cannot lay '
          'one exactly on the other. Molecules can be like that too — those '
          'are enantiomers.',
      sources: ['Stereochem.pdf · p.2'],
    ),
    (
      match: '',
      reply:
          'A racemic mixture is a 50:50 mix of two enantiomers — optically '
          'inactive because their rotations cancel.',
      sources: ['Stereochem.pdf · p.6'],
    ),
  ];

  static const _prompts = [
    'Quiz me on this',
    'Summarize ch.4',
    'Make flashcards',
    "Explain like I'm 5",
  ];

  @override
  void dispose() {
    _replyTimer?.cancel();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send([String? preset]) {
    final text = (preset ?? _input.text).trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add(ChatMessage.fromUser(text));
      _input.clear();
      _typing = true;
    });
    _scrollToEnd();

    final entry = _script.firstWhere(
      (e) => e.match.isNotEmpty && text.toLowerCase().contains(e.match),
      orElse: () => _script.last,
    );

    _replyTimer?.cancel();
    _replyTimer = Timer(const Duration(milliseconds: 1400), () {
      if (!mounted) return;
      setState(() {
        _typing = false;
        _messages.add(
          ChatMessage.fromFlow(entry.reply, sources: entry.sources),
        );
      });
      _scrollToEnd();
    });
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final sf = context.sf;
    final scheme = context.scheme;
    final hasDraft = _input.text.trim().isNotEmpty;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 14),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: scheme.outline)),
              ),
              child: Row(
                children: [
                  SfIconButton(
                    icon: Icons.arrow_back_rounded,
                    size: 36,
                    iconSize: 16,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 10),
                  const FlowOrb(size: 28),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Flow',
                          style: TextStyle(
                            fontFamily: AppTextStyles.fontUi,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                            color: sf.ink,
                          ),
                        ),
                        Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: sf.emerald,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Reading 3 docs',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: sf.emeraldInk,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  SfIconButton(
                    icon: Icons.refresh_rounded,
                    size: 36,
                    iconSize: 16,
                    onPressed: () => setState(() {
                      _messages.removeRange(3, _messages.length);
                      _typing = false;
                      _replyTimer?.cancel();
                    }),
                  ),
                ],
              ),
            ),

            // Transcript
            Expanded(
              child: ListView.separated(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
                itemCount: _messages.length + (_typing ? 1 : 0),
                separatorBuilder: (_, _) => const SizedBox(height: 14),
                itemBuilder: (context, i) {
                  if (i == _messages.length) return const _TypingBubble();
                  return _Bubble(message: _messages[i]);
                },
              ),
            ),

            // Suggested prompts — content-sized so the chips grow with the
            // text instead of overflowing a fixed rail height.
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Row(
                  children: [
                    for (var i = 0; i < _prompts.length; i++)
                      GestureDetector(
                        onTap: () => _send(_prompts[i]),
                        child: Container(
                          margin: EdgeInsets.only(
                              right: i == _prompts.length - 1 ? 0 : 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: scheme.surface,
                            borderRadius: AppRadius.brPill,
                            border: Border.all(color: scheme.outline),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const FlowOrb(size: 11, animate: false),
                              const SizedBox(width: 6),
                              Text(
                                _prompts[i],
                                maxLines: 1,
                                style: TextStyle(
                                  fontFamily: AppTextStyles.fontUi,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: sf.ink,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Composer
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 14),
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
                decoration: BoxDecoration(
                  color: scheme.surface,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: scheme.outline),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _input,
                        onChanged: (_) => setState(() {}),
                        onSubmitted: (_) => _send(),
                        textInputAction: TextInputAction.send,
                        style: TextStyle(
                          fontFamily: AppTextStyles.fontUi,
                          fontSize: 14,
                          color: sf.ink,
                        ),
                        decoration: InputDecoration(
                          isDense: true,
                          filled: false,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                              vertical: 10),
                          hintText: 'Ask anything…',
                          hintStyle: TextStyle(fontSize: 14, color: sf.ink4),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () {},
                      icon: Icon(Icons.mic_none_rounded,
                          size: 20, color: sf.ink3),
                    ),
                    GestureDetector(
                      onTap: _send,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 38,
                        height: 38,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: hasDraft
                              ? scheme.primary
                              : scheme.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.send_rounded,
                          size: 16,
                          color: hasDraft
                              ? (context.isDark
                                  ? AppColors.textPrimary
                                  : Colors.white)
                              : sf.ink3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final sf = context.sf;
    final scheme = context.scheme;

    if (!message.fromFlow) {
      return Align(
        alignment: Alignment.centerRight,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 280),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: scheme.primary,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(4),
              ),
            ),
            child: Text(
              message.text,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                height: 1.4,
                color: context.isDark ? AppColors.textPrimary : Colors.white,
              ),
            ),
          ),
        ),
      );
    }

    Color accentFor(SfAccent a) => switch (a) {
          SfAccent.brand => scheme.primary,
          SfAccent.coral => sf.coralInk,
          SfAccent.emerald => sf.emeraldInk,
        };

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const FlowOrb(size: 24),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: scheme.surface,
                  border: Border.all(color: scheme.outline),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                    bottomLeft: Radius.circular(4),
                    bottomRight: Radius.circular(16),
                  ),
                ),
                child: HighlightedText(
                  message.text,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    height: 1.5,
                    color: sf.ink,
                  ),
                  highlights: [
                    for (final h in message.highlightSpecs)
                      (phrase: h.phrase, color: accentFor(h.accent)),
                  ],
                ),
              ),
              if (message.sources.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final s in message.sources)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: sf.indigoSoft,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.picture_as_pdf_outlined,
                                size: 11, color: scheme.primary),
                            const SizedBox(width: 4),
                            SfMono(s, size: 10, color: scheme.primary),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _TypingBubble extends StatefulWidget {
  const _TypingBubble();

  @override
  State<_TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<_TypingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sf = context.sf;
    final scheme = context.scheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const FlowOrb(size: 24),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: scheme.surface,
            border: Border.all(color: scheme.outline),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
              bottomLeft: Radius.circular(4),
              bottomRight: Radius.circular(16),
            ),
          ),
          child: AnimatedBuilder(
            animation: _c,
            builder: (context, _) => Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) {
                // Each dot lifts a beat after the one before it.
                final phase = (_c.value - i * 0.15) % 1.0;
                final lift = phase < 0.3
                    ? Curves.easeOut.transform(phase / 0.3)
                    : phase < 0.6
                        ? 1 - Curves.easeIn.transform((phase - 0.3) / 0.3)
                        : 0.0;
                return Padding(
                  padding: EdgeInsets.only(right: i == 2 ? 0 : 4),
                  child: Transform.translate(
                    offset: Offset(0, -3 * lift),
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: sf.ink3.withValues(alpha: 0.3 + 0.7 * lift),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ],
    );
  }
}
