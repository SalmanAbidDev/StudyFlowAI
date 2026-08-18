// lib/features/upload/paste_text_view_model.dart
//
// Typed or pasted notes become a material like any other: a text/plain object
// in the same private bucket, and a row pointing at it. Nothing downstream has
// to know it never was a file.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/study_material.dart';
import '../../data/supabase_providers.dart';
import '../home/home_view_model.dart';
import '../materials/materials_view_model.dart';

/// Below this there is not enough to summarise or build a deck from; above it
/// the paste stops being "a note" and should be a document upload.
const kMinWords = 50;
const kMaxWords = 1000;

/// Words as a person counts them: runs of non-whitespace. Punctuation and
/// newlines do not create or destroy words, and a trailing space does not add
/// one — which a naive `split(' ').length` gets wrong in both directions.
int countWords(String text) =>
    text.trim().isEmpty ? 0 : text.trim().split(RegExp(r'\s+')).length;

/// The first few words, for pre-filling the title field.
String titleFromBody(String text) {
  final words = text.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
  if (words.isEmpty) return '';
  final head = words.take(7).join(' ');
  // Strip trailing punctuation so a sentence fragment does not become
  // "Mitochondria are the powerhouse,".
  final trimmed = head.replaceAll(RegExp(r'[\s,;:.\-–—]+$'), '');
  return words.length > 7 ? '$trimmed…' : trimmed;
}

class PasteTextState {
  const PasteTextState({this.saving = false, this.error});

  final bool saving;
  final String? error;
}

class PasteTextViewModel extends Notifier<PasteTextState> {
  @override
  PasteTextState build() => const PasteTextState();

  /// Uploads [body] and records the material. Returns it so the caller can
  /// send the user on to file it into a category.
  Future<StudyMaterial?> save({
    required String title,
    required String body,
  }) async {
    final words = countWords(body);
    if (state.saving || words < kMinWords || words > kMaxWords) return null;

    state = const PasteTextState(saving: true);
    try {
      final userId = ref.read(currentUserIdProvider);
      final name = titleFromBody(body);

      final storagePath = await ref.read(storageRepositoryProvider).uploadText(
            userId: userId,
            // The stored object gets a stable machine name; the *material*
            // carries the readable one.
            fileName: 'note-${DateTime.now().millisecondsSinceEpoch}.txt',
            text: body,
          );

      final material =
          await ref.read(libraryRepositoryProvider).createMaterial(
                userId: userId,
                title: title.trim().isEmpty ? name : title.trim(),
                storagePath: storagePath,
                mimeType: 'text/plain',
                byteSize: body.length,
              );

      ref.invalidate(materialsProvider);
      ref.invalidate(resumeMaterialProvider);

      state = const PasteTextState();
      return material;
    } catch (_) {
      state = const PasteTextState(
        error: "Couldn't save that. Check your connection and try again.",
      );
      return null;
    }
  }
}

final pasteTextProvider =
    NotifierProvider.autoDispose<PasteTextViewModel, PasteTextState>(
  PasteTextViewModel.new,
);
