// lib/features/categories/category_view_model.dart
//
// Filing a freshly uploaded material. The screen above this is mandatory, so
// the only thing that matters here is whether there is a name to file under
// and whether the write succeeded.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/subject.dart';
import '../../data/supabase_providers.dart';
import '../home/home_view_model.dart';
import '../materials/materials_view_model.dart';

/// The categories this user already has. Offered above the suggestions so the
/// second upload files itself next to the first instead of inventing a
/// near-duplicate.
final subjectsProvider = FutureProvider<List<Subject>>(
  (ref) => ref.watch(libraryRepositoryProvider).subjects(),
);

/// Suggestions minus anything the user already has, matched case-insensitively
/// — offering "Physics" as new to someone who owns a Physics category invites
/// exactly the duplicate `ensureSubject` then has to collapse.
final categoryOptionsProvider = Provider<List<CategorySuggestion>>((ref) {
  final owned = (ref.watch(subjectsProvider).value ?? const <Subject>[])
      .map((s) => s.name.toLowerCase())
      .toSet();
  return categorySuggestions
      .where((s) => !owned.contains(s.name.toLowerCase()))
      .toList();
});

class CategoryState {
  const CategoryState({
    this.subject,
    this.suggestion,
    this.custom = '',
    this.saving = false,
    this.error,
  });

  /// One of the user's existing categories.
  final Subject? subject;

  /// One of the app's suggestions, not yet a row anywhere.
  final CategorySuggestion? suggestion;

  /// Whatever is in the text field. Wins over a chip when non-empty, because
  /// typing is the more deliberate act — and the screen clears the other one
  /// either way, so both being set is a transient state, not a conflict.
  final String custom;

  final bool saving;
  final String? error;

  /// What the material will actually be filed under, or null if the user has
  /// not chosen yet. This is the whole gate on the Continue button.
  String? get chosenName {
    final typed = custom.trim();
    if (typed.isNotEmpty) return typed;
    return subject?.name ?? suggestion?.name;
  }

  bool get canContinue => !saving && chosenName != null;

  CategoryState copyWith({
    Subject? subject,
    CategorySuggestion? suggestion,
    String? custom,
    bool? saving,
    String? error,
    bool clearChoice = false,
    bool clearError = false,
  }) =>
      CategoryState(
        subject: clearChoice ? null : (subject ?? this.subject),
        suggestion: clearChoice ? null : (suggestion ?? this.suggestion),
        custom: custom ?? this.custom,
        saving: saving ?? this.saving,
        error: clearError ? null : (error ?? this.error),
      );
}

class CategoryViewModel extends Notifier<CategoryState> {
  @override
  CategoryState build() => const CategoryState();

  void pickSubject(Subject subject) => state = CategoryState(subject: subject);

  void pickSuggestion(CategorySuggestion suggestion) =>
      state = CategoryState(suggestion: suggestion);

  /// Typing deselects the chips. Two highlighted answers to one question is a
  /// worse problem than losing a tap.
  void setCustom(String value) => state = CategoryState(custom: value);

  /// Files [materialId] under the chosen name, creating the category if it is
  /// new. Returns the name on success so the caller can name it in a message.
  Future<String?> save(String materialId) async {
    final name = state.chosenName;
    if (name == null || state.saving) return null;

    state = state.copyWith(saving: true, clearError: true);
    try {
      final library = ref.read(libraryRepositoryProvider);

      // An existing category is already a row; only a suggestion or a typed
      // name needs `ensureSubject` to find-or-create.
      final subjectId = switch (state) {
        CategoryState(subject: final s?) when state.custom.trim().isEmpty =>
          s.id,
        _ => (await library.ensureSubject(
            userId: ref.read(currentUserIdProvider),
            name: name,
            accent: state.suggestion?.accent ?? SubjectAccent.indigo,
            iconKey: state.suggestion?.iconKey ?? 'book',
          ))
              .id,
      };

      await library.setMaterialSubject(materialId, subjectId);

      // Everything that renders a subject name, an accent, or a filter pill is
      // now out of date.
      ref.invalidate(materialsProvider);
      ref.invalidate(subjectsProvider);
      ref.invalidate(resumeMaterialProvider);

      return name;
    } catch (_) {
      state = state.copyWith(
        saving: false,
        error: "Couldn't save that category. Check your connection and try "
            'again.',
      );
      return null;
    }
  }
}

final categoryProvider =
    NotifierProvider.autoDispose<CategoryViewModel, CategoryState>(
  CategoryViewModel.new,
);
