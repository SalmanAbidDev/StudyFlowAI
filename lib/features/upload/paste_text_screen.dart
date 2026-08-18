// lib/features/upload/paste_text_screen.dart
//
// Type or paste notes and they become a material. Two gates, both stated on
// screen rather than discovered by a disabled button: at least 50 words to be
// worth studying, at most 1000 before it should have been a document upload.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/navigation.dart';
import '../../core/theme/theme.dart';
import '../../core/widgets/widgets.dart';
import '../categories/category_screen.dart';
import 'paste_text_view_model.dart';

class PasteTextScreen extends ConsumerStatefulWidget {
  const PasteTextScreen({super.key});

  @override
  ConsumerState<PasteTextScreen> createState() => _PasteTextScreenState();
}

class _PasteTextScreenState extends ConsumerState<PasteTextScreen> {
  final _title = TextEditingController();
  final _body = TextEditingController();

  /// True once the user has typed in the title themselves. Until then the
  /// title tracks the opening words — pre-filled, but never overwriting a
  /// choice the user has made.
  var _titleEdited = false;

  /// Guards the title controller's own listener against the writes this class
  /// makes, which would otherwise look like user edits.
  var _writingTitle = false;

  @override
  void initState() {
    super.initState();
    _body.addListener(_syncTitle);
    _title.addListener(_markTitleEdited);
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  void _syncTitle() {
    if (_titleEdited) return;
    final derived = titleFromBody(_body.text);
    if (derived == _title.text) return;
    _writingTitle = true;
    _title.value = TextEditingValue(
      text: derived,
      selection: TextSelection.collapsed(offset: derived.length),
    );
    _writingTitle = false;
  }

  void _markTitleEdited() {
    if (!_writingTitle) _titleEdited = true;
  }

  Future<void> _save() async {
    final material = await ref.read(pasteTextProvider.notifier).save(
          title: _title.text,
          body: _body.text,
        );
    if (material == null || !mounted) return;

    // Same landing as every other upload: filing it is mandatory (§5.4).
    Navigator.of(context).pushReplacement(
      sfModalRoute(builder: (_) => CategoryScreen(material: material)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sf = context.sf;
    final state = ref.watch(pasteTextProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SfModalHeader(
              title: 'Paste text',
              padding: EdgeInsets.fromLTRB(22, 12, 22, 12),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 0, 22, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SfField(
                      controller: _title,
                      hint: 'Title',
                      icon: Icons.title_rounded,
                    ),
                    const SizedBox(height: 10),
                    // Takes the rest of the screen: this is the field the
                    // screen exists for, and a short box for a thousand words
                    // makes people paste blind.
                    Expanded(child: _BodyField(controller: _body)),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 16),
              child: ValueListenableBuilder<TextEditingValue>(
                valueListenable: _body,
                builder: (context, value, _) {
                  final words = countWords(value.text);
                  final tooFew = words < kMinWords;
                  final tooMany = words > kMaxWords;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              // Says what is wrong, not just that something
                              // is. A dimmed button with no explanation is the
                              // thing this replaces.
                              switch (0) {
                                _ when state.error != null => state.error!,
                                _ when tooMany =>
                                  '$words / $kMaxWords words — too long',
                                _ when words == 0 =>
                                  'At least $kMinWords words',
                                _ when tooFew =>
                                  '$words words — $kMinWords needed',
                                _ => '$words words',
                              },
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: (tooMany || state.error != null)
                                    ? sf.coralInk
                                    : sf.ink3,
                              ),
                            ),
                          ),
                          if (!tooFew && !tooMany)
                            Icon(Icons.check_circle_rounded,
                                size: 16, color: sf.emerald),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SfButton(
                        'Continue',
                        size: SfButtonSize.lg,
                        expand: true,
                        busy: state.saving,
                        trailingIcon: Icons.arrow_forward_rounded,
                        onPressed:
                            (tooFew || tooMany || state.saving) ? null : _save,
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The multi-line note box. `SfField` is a fixed 54pt row built for one line,
/// so this is its tall sibling rather than a flag on it.
///
/// Stateful only to own a [FocusNode]; the rebuild goes through
/// `ListenableBuilder`, because a FocusNode *is* a Listenable and the app has
/// no `setState` in it (§4).
class _BodyField extends StatefulWidget {
  const _BodyField({required this.controller});

  final TextEditingController controller;

  @override
  State<_BodyField> createState() => _BodyFieldState();
}

class _BodyFieldState extends State<_BodyField> {
  final _focus = FocusNode();

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sf = context.sf;
    final scheme = context.scheme;

    return ListenableBuilder(
      listenable: _focus,
      builder: (context, _) {
        final focused = _focus.hasFocus;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          // The border thickens by a pixel on focus, and the padding gives
          // that pixel back — otherwise the text nudges sideways every time
          // the field is tapped.
          padding: EdgeInsets.symmetric(
            horizontal: focused ? 13 : 14,
            vertical: focused ? 11 : 12,
          ),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: AppRadius.brMd,
            border: Border.all(
              color: focused ? scheme.primary : scheme.outline,
              width: focused ? 2 : 1,
            ),
          ),
          child: TextField(
            controller: widget.controller,
            focusNode: _focus,
            expands: true,
            maxLines: null,
            minLines: null,
            textAlignVertical: TextAlignVertical.top,
            keyboardType: TextInputType.multiline,
            textCapitalization: TextCapitalization.sentences,
            style: TextStyle(
              fontFamily: AppTextStyles.fontUi,
              fontSize: 15,
              height: 1.45,
              color: sf.ink,
            ),
            decoration: InputDecoration(
              // Every border, not just `border`. `AppTheme` sets an
              // `inputDecorationTheme` with a filled surface and a primary
              // `focusedBorder`, and overriding only `border` leaves the rest
              // of it in place — which drew a second, inner box that lit up on
              // focus while the real container stayed dim.
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              focusedErrorBorder: InputBorder.none,
              filled: false,
              isDense: true,
              contentPadding: EdgeInsets.zero,
              hintText: 'Paste your notes here, or start typing…',
              hintStyle: TextStyle(
                fontFamily: AppTextStyles.fontUi,
                fontSize: 15,
                color: sf.ink4,
              ),
            ),
          ),
        );
      },
    );
  }
}
