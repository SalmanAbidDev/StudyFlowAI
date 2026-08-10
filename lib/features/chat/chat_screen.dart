// lib/features/chat/chat_screen.dart
//
// "Chat with your notes". The transcript and the scripted reply table live in
// chatProvider; what stays here is the text field, the scroll position, and
// the composer — controllers, not application state.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/theme.dart';
import '../../core/widgets/widgets.dart';
import 'chat_models.dart';
import 'chat_view_model.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send([String? preset]) {
    final text = (preset ?? _input.text).trim();
    if (text.isEmpty) return;
    _input.clear();
    ref.read(chatProvider.notifier).send(text);
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
    final session = ref.watch(chatProvider);

    // Scrolling is a side effect of the transcript changing, not of the user
    // tapping send — the scripted reply arrives on a timer long after the tap.
    // Listening to the provider catches both cases in one place.
    ref.listen(chatProvider, (_, _) => _scrollToEnd());

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
                    onPressed: ref.read(chatProvider.notifier).reset,
                  ),
                ],
              ),
            ),

            // Transcript
            Expanded(
              child: ListView.separated(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
                itemCount: session.messages.length + (session.typing ? 1 : 0),
                separatorBuilder: (_, _) => const SizedBox(height: 14),
                itemBuilder: (context, i) {
                  if (i == session.messages.length) {
                    return const _TypingBubble();
                  }
                  return _Bubble(message: session.messages[i]);
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
                    for (var i = 0; i < chatPrompts.length; i++)
                      GestureDetector(
                        onTap: () => _send(chatPrompts[i]),
                        child: Container(
                          margin: EdgeInsets.only(
                              right: i == chatPrompts.length - 1 ? 0 : 8),
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
                                chatPrompts[i],
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
                    // Listening to the controller rather than rebuilding the
                    // whole screen on every keystroke, which is what the old
                    // `onChanged: setState` did.
                    ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _input,
                      builder: (context, value, _) {
                        final hasDraft = value.text.trim().isNotEmpty;
                        return GestureDetector(
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
                        );
                      },
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
