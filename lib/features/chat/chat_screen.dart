// lib/features/chat/chat_screen.dart
//
// "Chat with your notes". The transcript lives in chatProvider; what stays
// here is the text field, the scroll position, and the composer — controllers,
// not application state.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/theme.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models/study_material.dart';
import '../materials/material_browser.dart';
import '../materials/materials_view_model.dart';
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
    // Guarded here rather than by leaving the button's `onTap` null: the
    // enabled-ness depends on state the composer only learns about on the
    // *next* frame, and a tap arriving before that frame would be swallowed
    // with no feedback at all.
    if (ref.read(chatUsageProvider).value?.exhausted ?? false) return;
    if (ref.read(chatProvider).value?.typing ?? false) return;
    _input.clear();
    unawaited(ref.read(chatProvider.notifier).send(text));
  }

  /// Whether the end has been reached once already. Opening a chat that
  /// already overflows should *start* at the newest message; only later
  /// arrivals are worth animating to.
  bool _pinned = false;

  /// Keeps the newest message in view **without moving anything else**.
  ///
  /// The transcript is top-anchored, so a conversation shorter than the
  /// viewport simply sits under the header and there is nothing to scroll —
  /// `maxScrollExtent` is 0 and this returns immediately. Only once the
  /// content outgrows the viewport does the view follow the end.
  void _pinToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;

      final target = _scroll.position.maxScrollExtent;
      if (target - _scroll.offset < 1) {
        _pinned = true;
        return;
      }

      if (_pinned) {
        _scroll.animateTo(
          target,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOut,
        );
        return;
      }

      // First sight of an existing transcript. `maxScrollExtent` is only an
      // *estimate* while children are still being laid out lazily, so jumping
      // once can land short of the end; repeat until it stops growing. This
      // terminates because every jump forces more of the list to be measured.
      _scroll.jumpTo(target);
      _pinToEnd();
    });
  }

  @override
  Widget build(BuildContext context) {
    final sf = context.sf;
    final scheme = context.scheme;
    final session = ref.watch(chatProvider);
    final notice = session.value?.notice;
    final thinking = session.value?.typing ?? false;
    final usage = ref.watch(chatUsageProvider).value;
    final spent = usage?.exhausted ?? false;

    // Scrolling is a side effect of the transcript changing, not of the user
    // tapping send — a reply will one day land long after the tap. Listening to
    // the provider catches both cases in one place.
    ref.listen(chatProvider, (_, _) => _pinToEnd());

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
                        const _HeldDocumentLine(),
                      ],
                    ),
                  ),
                  // Which document Flow is reading. An icon rather than a
                  // label because the answer is already spelled out under the
                  // name, an inch to the left.
                  SfIconButton(
                    icon: Icons.description_outlined,
                    size: 36,
                    iconSize: 16,
                    onPressed: () => showSfSheet<void>(
                      context,
                      (_) => const _DocumentSheet(),
                    ),
                  ),
                ],
              ),
            ),

            // Transcript
            Expanded(
              child: session.when(
                loading: () => const SfLoadingList(
                  rows: 4,
                  height: 64,
                  padding: EdgeInsets.fromLTRB(18, 18, 18, 0),
                ),
                error: (error, _) => SfErrorView(
                  error: error,
                  onRetry: () => ref.invalidate(chatProvider),
                ),
                data: (data) => _Transcript(
                  session: data,
                  controller: _scroll,
                ),
              ),
            ),

            // Why nothing came back. Sits outside the transcript because it is
            // the app speaking about itself, not a turn in the conversation.
            if (notice != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline_rounded, size: 13, color: sf.ink3),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        notice,
                        style: TextStyle(
                          fontSize: 11,
                          height: 1.4,
                          fontWeight: FontWeight.w500,
                          color: sf.ink3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // What is left of today. Shown only once some has been used, so a
            // fresh day is not greeted with a quota.
            if (usage != null && usage.used > 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 2),
                child: Row(
                  children: [
                    Icon(
                      spent
                          ? Icons.hourglass_bottom_rounded
                          : Icons.bolt_rounded,
                      size: 13,
                      color: spent ? sf.coralInk : sf.ink3,
                    ),
                    const SizedBox(width: 6),
                    // Flexible: the line grows with the text scale, and a
                    // bare Row would run off the right edge.
                    Expanded(
                      child: Text(
                        spent
                            ? 'No questions left today'
                            : '${usage.remaining} of ${usage.limit} questions '
                                'left today',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: spent ? sf.coralInk : sf.ink3,
                        ),
                      ),
                    ),
                  ],
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
                        // Nothing to type into once the day's questions are
                        // gone; leaving it live would let you write a question
                        // that could not be sent.
                        enabled: !spent,
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
                          hintText: spent
                              ? 'No questions left today'
                              : thinking
                                  ? 'Flow is reading…'
                                  : 'Ask anything…',
                          hintStyle: TextStyle(fontSize: 14, color: sf.ink4),
                        ),
                      ),
                    ),
                    // Listening to the controller rather than rebuilding the
                    // whole screen on every keystroke, which is what the old
                    // `onChanged: setState` did.
                    ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _input,
                      builder: (context, value, _) {
                        final hasDraft =
                            value.text.trim().isNotEmpty && !spent && !thinking;
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

/// The messages, **top-anchored**: the conversation starts under the header
/// and grows downward, and a new message appears *below* the previous one.
///
/// This was briefly `reverse: true` — messages pinned to the bottom edge — on
/// the theory that chat apps anchor there. They do not, for a short thread:
/// bottom-anchoring makes every message already on screen climb upward each
/// time you send, which is exactly the "it moves to the top" that reversing
/// was meant to fix. Growing downward leaves what is on screen where it is;
/// `_pinToEnd` handles the case where the thread outgrows the viewport.
class _Transcript extends StatelessWidget {
  const _Transcript({required this.session, required this.controller});

  final ChatSession session;
  final ScrollController controller;

  @override
  Widget build(BuildContext context) {
    if (session.messages.isEmpty) return const _EmptyTranscript();

    final count = session.messages.length + (session.typing ? 1 : 0);
    return ListView.separated(
      controller: controller,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      itemCount: count,
      separatorBuilder: (_, _) => const SizedBox(height: 14),
      itemBuilder: (context, i) {
        // The typing indicator is the newest thing there is — one past the
        // last message.
        if (i == session.messages.length) return const _TypingBubble();
        return _Bubble(message: session.messages[i]);
      },
    );
  }
}

/// What Flow is actually holding, under its name in the header.
///
/// This used to read "Reading 3 docs" — hard-coded, then counted, and wrong
/// either way: Flow reads *one* document, the one you hand it. Naming it is
/// the only version that tells you what a question will be answered from.
class _HeldDocumentLine extends ConsumerWidget {
  const _HeldDocumentLine();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sf = context.sf;
    final material = ref.watch(chatMaterialProvider);
    final held = material != null;

    return Row(
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: held ? sf.emerald : sf.ink4,
          ),
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            material?.title ?? 'No document selected',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: held ? sf.emeraldInk : sf.ink3,
            ),
          ),
        ),
      ],
    );
  }
}

/// Picks the one document Flow reads from. Includes an explicit "No document"
/// row: holding nothing is a state you can choose, not only one you start in.
class _DocumentSheet extends ConsumerWidget {
  const _DocumentSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sf = context.sf;
    final all = ref.watch(materialsProvider).value ?? const <StudyMaterial>[];
    final heldId = ref.watch(chatDocumentProvider);

    void hold(String? id) {
      ref.read(chatDocumentProvider.notifier).update(id);
      Navigator.of(context).pop();
    }

    return SfSheetShell(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Read from',
                  style: AppTextStyles.heading.copyWith(
                    fontSize: 20,
                    letterSpacing: -0.5,
                    color: sf.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Flow answers from the one document you pick. Each gets its '
                  'own conversation.',
                  style: TextStyle(fontSize: 13, height: 1.35, color: sf.ink3),
                ),
              ],
            ),
          ),
          _NoDocumentRow(selected: heldId == null, onTap: () => hold(null)),
          if (all.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 14, left: 2),
              child: Text(
                'Nothing in your library yet.',
                style: TextStyle(fontSize: 13, color: sf.ink3),
              ),
            ),
          // A Column, not a ListView: the sheet already scrolls, and nesting a
          // second scrollable inside it fights the first.
          for (final material in all) ...[
            const SizedBox(height: 8),
            MaterialRow(
              material: material,
              showProgress: false,
              selected: material.id == heldId,
              onTap: () => hold(material.id),
              trailing: material.id == heldId
                  ? Icon(Icons.check_circle_rounded,
                      size: 20, color: context.scheme.primary)
                  : const SizedBox.shrink(),
            ),
          ],
        ],
      ),
    );
  }
}

class _NoDocumentRow extends StatelessWidget {
  const _NoDocumentRow({required this.selected, required this.onTap});

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final sf = context.sf;
    final scheme = context.scheme;

    return SfCard(
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      color: selected ? sf.indigoSoft : null,
      borderColor: selected ? scheme.primary : null,
      child: Row(
        children: [
          SoftIconTile(
            icon: Icons.block_rounded,
            color: sf.ink3,
            background: scheme.surfaceContainerHigh,
            width: 44,
            height: 44,
            radius: 10,
            iconSize: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'No document',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.1,
                color: sf.ink,
              ),
            ),
          ),
          if (selected)
            Icon(Icons.check_circle_rounded, size: 20, color: scheme.primary),
        ],
      ),
    );
  }
}

class _EmptyTranscript extends ConsumerWidget {
  const _EmptyTranscript();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasDocs = (ref.watch(chatCorpusSizeProvider) ?? 0) > 0;
    return SfEmptyView(
      icon: Icons.chat_bubble_outline_rounded,
      title: 'Ask Flow anything',
      body: hasDocs
          ? 'Questions about your materials go here.'
          : 'Upload something to your library first — Flow answers from what '
              'you have read, not from thin air.',
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
