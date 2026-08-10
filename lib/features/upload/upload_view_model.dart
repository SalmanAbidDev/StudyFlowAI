// lib/features/upload/upload_view_model.dart

import 'dart:io';

import 'package:file_picker/file_picker.dart';
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

    final FilePickerResult? picked;
    try {
      picked = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf', 'txt', 'md', 'docx', 'pptx', 'png', 'jpg'],
        withData: false,
      );
    } catch (error) {
      state = UploadState(stage: UploadStage.failed, error: '$error');
      return false;
    }

    final path = picked?.files.single.path;
    if (path == null) {
      // Cancelled — not an error, just back to where we started.
      state = const UploadState();
      return false;
    }

    final file = File(path);
    final name = picked!.files.single.name;
    final size = picked.files.single.size;

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
            mimeType: picked.files.single.extension,
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
