// lib/features/documents/document_view_model.dart
//
// Fetching the thing a material actually is, so the document screen can show
// it rather than describe it.

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/study_material.dart';
import '../../data/supabase_providers.dart';
import '../materials/materials_view_model.dart';

/// The bytes of the open material, or null when there is no file to fetch —
/// a link has nothing in the bucket.
///
/// autoDispose: a PDF is megabytes, and holding the last one you opened for
/// the rest of the session is a memory leak with a nicer name.
final documentBytesProvider = FutureProvider.autoDispose<Uint8List?>((ref) async {
  final material = await ref.watch(currentMaterialProvider.future);
  final path = material?.storagePath;
  if (material == null || path == null) return null;
  if (material.kind == MaterialKind.link) return null;

  return ref.watch(storageRepositoryProvider).download(path);
});

/// The same bytes decoded, for a text material.
///
/// `allowMalformed` because the file came from a user's clipboard and a single
/// bad byte should not turn the whole note into an error screen.
final documentTextProvider = FutureProvider.autoDispose<String>((ref) async {
  final bytes = await ref.watch(documentBytesProvider.future);
  if (bytes == null) return '';
  return utf8.decode(bytes, allowMalformed: true);
});
