// lib/features/categories/category_screen.dart
//
// Where a freshly uploaded document gets filed. Mandatory by design: there is
// no back arrow, no close button, and `PopScope` refuses the system gesture,
// so "Unfiled" never becomes a real category anyone accumulates.
//
// The upload is already in storage by the time this appears — this screen
// finishes the job rather than guarding the start of it.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/theme.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models/study_material.dart';
import '../../data/models/subject.dart';
import 'category_view_model.dart';

class CategoryScreen extends ConsumerStatefulWidget {
  const CategoryScreen({super.key, required this.material});

  final StudyMaterial material;

  @override
  ConsumerState<CategoryScreen> createState() => _CategoryScreenState();
}

/// Stateful for the text controller alone; the selection itself lives in
/// [categoryProvider], because the save needs it too.
class _CategoryScreenState extends ConsumerState<CategoryScreen> {
  final _custom = TextEditingController();

  @override
  void dispose() {
    _custom.dispose();
    super.dispose();
  }

  /// Picking a chip empties the field, so the screen never shows two answers
  /// to the same question.
  void _pickSubject(Subject subject) {
    _custom.clear();
    ref.read(categoryProvider.notifier).pickSubject(subject);
  }

  void _pickSuggestion(CategorySuggestion suggestion) {
    _custom.clear();
    ref.read(categoryProvider.notifier).pickSuggestion(suggestion);
  }

  Future<void> _save() async {
    final name = await ref.read(categoryProvider.notifier).save(
          widget.material.id,
        );
    if (name == null || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger.showSnackBar(
      SnackBar(content: Text('Added to your library under "$name".')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sf = context.sf;
    final state = ref.watch(categoryProvider);
    final mine = ref.watch(subjectsProvider).value ?? const <Subject>[];
    final suggestions = ref.watch(categoryOptionsProvider);

    return PopScope(
      // The one screen in the app that refuses to be dismissed. Everything
      // else uses maybePop; here there is nothing to pop back to that would
      // leave the material in a valid state.
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 16, 22, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Category',
                      style: AppTextStyles.displayL
                          .copyWith(fontSize: 28, color: sf.ink),
                    ),
                    const SizedBox(height: 4),
                    // Names the document. Filing something you cannot see the
                    // name of is guesswork.
                    Text.rich(
                      TextSpan(
                        text: 'Where does ',
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          color: sf.ink3,
                        ),
                        children: [
                          TextSpan(
                            text: widget.material.title,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: sf.ink,
                            ),
                          ),
                          const TextSpan(text: ' belong?'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(22, 18, 22, 8),
                  children: [
                    if (mine.isNotEmpty) ...[
                      SfEyebrow('Your categories', color: sf.ink3),
                      const SizedBox(height: 10),
                      _ChipWrap(
                        children: [
                          for (final subject in mine)
                            SfSelectChip(
                              label: subject.name,
                              icon: subject.icon,
                              accent: subject.accent.color(context),
                              selected: state.subject?.id == subject.id,
                              onTap: () => _pickSubject(subject),
                            ),
                        ],
                      ),
                      const SizedBox(height: 22),
                    ],
                    if (suggestions.isNotEmpty) ...[
                      SfEyebrow(
                        mine.isEmpty ? 'Common categories' : 'Suggested',
                        color: sf.ink3,
                      ),
                      const SizedBox(height: 10),
                      _ChipWrap(
                        children: [
                          for (final suggestion in suggestions)
                            SfSelectChip(
                              label: suggestion.name,
                              icon: suggestion.icon,
                              accent: suggestion.accent.color(context),
                              selected: state.suggestion?.name ==
                                  suggestion.name,
                              onTap: () => _pickSuggestion(suggestion),
                            ),
                        ],
                      ),
                      const SizedBox(height: 22),
                    ],
                    SfEyebrow('Or name your own', color: sf.ink3),
                    const SizedBox(height: 10),
                    SfField(
                      controller: _custom,
                      hint: 'e.g. Organic Chemistry',
                      icon: Icons.create_outlined,
                    ),
                    if (state.error case final error?) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(Icons.error_outline_rounded,
                              size: 16, color: sf.coralInk),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              error,
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.4,
                                color: sf.coralInk,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 8, 22, 16),
                // Rebuilt on every keystroke so Continue unlocks as soon as
                // there is a name, without the field's text living in the
                // provider.
                child: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _custom,
                  builder: (context, value, _) {
                    final typed = value.text.trim();
                    final ready = state.saving
                        ? false
                        : typed.isNotEmpty ||
                            state.subject != null ||
                            state.suggestion != null;

                    return SfButton(
                      'Continue',
                      size: SfButtonSize.lg,
                      expand: true,
                      busy: state.saving,
                      trailingIcon: Icons.arrow_forward_rounded,
                      onPressed: ready
                          ? () {
                              // Push the typed name into the view model at the
                              // moment of use rather than on every keystroke.
                              if (typed.isNotEmpty) {
                                ref
                                    .read(categoryProvider.notifier)
                                    .setCustom(typed);
                              }
                              _save();
                            }
                          : null,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Chips wrap rather than sit in a fixed grid: category names vary from
/// "Physics" to "Computer Science", and a grid cell sized for one clips the
/// other at a large text scale.
class _ChipWrap extends StatelessWidget {
  const _ChipWrap({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Wrap(spacing: 8, runSpacing: 8, children: children);
  }
}

/// The category chips are `SfSelectChip` now — the exam editor needed the same
/// control for subjects, so it moved to core/widgets rather than being copied.
