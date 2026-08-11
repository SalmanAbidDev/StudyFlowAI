// lib/features/upload/upload_view_model.dart
//
// File picking uses `file_selector` (flutter.dev) rather than `file_picker`.
// file_picker 11 skips applying the Kotlin Gradle Plugin on AGP 9 and relies
// on built-in Kotlin without opting into it, so its Kotlin sources never
// compile and the generated registrant fails to find FilePickerPlugin.
// file_selector_android is migrated properly.

import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/supabase_providers.dart';
import '../home/home_view_model.dart';
import '../materials/materials_view_model.dart';

enum UploadStage { idle, picking, uploading, done, failed }

class UploadState {
  const UploadState({
    this.stage = UploadStage.idle,
    this.fileName = '',
    this.byteSize = 0,
    this.error,
  });

  final UploadStage stage;
  final String fileName;
  final int byteSize;
  final String? error;

  bool get isBusy =>
      stage == UploadStage.picking || stage == UploadStage.uploading;

  /// "4.2 MB"
  String get sizeLabel {
    if (byteSize <= 0) return '';
    final mb = byteSize / (1024 * 1024);
    return mb >= 1
        ? '${mb.toStringAsFixed(1)} MB'
        : '${(byteSize / 1024).round()} KB';
  }

  UploadState copyWith({
    UploadStage? stage,
    String? fileName,
    int? byteSize,
    String? error,
    bool clearError = false,
  }) =>
      UploadState(
        stage: stage ?? this.stage,
        fileName: fileName ?? this.fileName,
        byteSize: byteSize ?? this.byteSize,
        error: clearError ? null : (error ?? this.error),
      );
}

class UploadViewModel extends Notifier<UploadState> {
  @override
  UploadState build() => const UploadState();

  /// Picks a document, uploads it to the private bucket, and records the
  /// material row. Returns true when the whole chain succeeded.
  Future<bool> pickAndUpload() async {
    state = const UploadState(stage: UploadStage.picking);

    // The bucket's allowed_mime_types is the real gate; this list only keeps
    // the picker from showing files the upload would then reject.
    const documents = XTypeGroup(
      label: 'Documents',
      extensions: ['pdf', 'txt', 'md', 'docx', 'pptx', 'png', 'jpg', 'jpeg'],
    );

    final XFile? picked;
    try {
      picked = await openFile(acceptedTypeGroups: const [documents]);
    } catch (error) {
      state = UploadState(stage: UploadStage.failed, error: '$error');
      return false;
    }

    if (picked == null) {
      // Cancelled — not an error, just back to where we started.
      state = const UploadState();
      return false;
    }

    final file = File(picked.path);
    final name = picked.name;
    final size = await picked.length();

    state = UploadState(
      stage: UploadStage.uploading,
      fileName: name,
      byteSize: size,
    );

    try {
      final userId = ref.read(currentUserIdProvider);
      final storagePath = await ref.read(storageRepositoryProvider).uploadMaterial(
            userId: userId,
            file: file,
            fileName: name,
          );

      await ref.read(libraryRepositoryProvider).createMaterial(
            userId: userId,
            // The extension is noise in a title; the mime type already records it.
            title: name.replaceAll(RegExp(r'\.[^.]+$'), ''),
            storagePath: storagePath,
            mimeType: picked.mimeType,
            byteSize: size,
          );

      // The library and Home's resume card both describe a world that just
      // changed.
      ref.invalidate(materialsProvider);
      ref.invalidate(resumeMaterialProvider);

      state = state.copyWith(stage: UploadStage.done, clearError: true);
      return true;
    } catch (error) {
      state = state.copyWith(stage: UploadStage.failed, error: '$error');
      return false;
    }
  }

  void reset() => state = const UploadState();
}

final uploadProvider =
    NotifierProvider.autoDispose<UploadViewModel, UploadState>(
  UploadViewModel.new,
);
