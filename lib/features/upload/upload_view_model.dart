// lib/features/upload/upload_view_model.dart
//
// Two pickers, chosen by source:
//
// * Documents use `file_selector` (flutter.dev) rather than `file_picker`.
//   file_picker 11 skips applying the Kotlin Gradle Plugin on AGP 9 and relies
//   on built-in Kotlin without opting into it, so its Kotlin sources never
//   compile and the generated registrant fails to find FilePickerPlugin.
//   file_selector_android is migrated properly.
// * Camera and gallery use `image_picker` (also flutter.dev), which is the
//   only one of the two that can open the capture intent and the system photo
//   picker.
//
// Both hand back a `cross_file` XFile, so everything below the pick is shared.

import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart' show ImagePicker, ImageSource;
import 'package:path/path.dart' as p;

import '../../data/models/study_material.dart';
import '../../data/supabase_providers.dart';
import '../home/home_view_model.dart';
import '../materials/materials_view_model.dart';

/// Where a new material can come from. One list, so the sheet behind "Browse
/// files" and the "Or add from" grid cannot drift apart.
enum UploadSource {
  pdf,
  camera,
  photos,
  text,
  url;

  /// True for the three that open a system picker and run through
  /// [UploadViewModel.pickAndUpload]. `text` and `url` produce a material too,
  /// but from their own screens — there is no file on disk to pick.
  bool get usesPicker => this == pdf || this == camera || this == photos;
}

/// The mime types the `materials` bucket accepts, keyed by extension.
///
/// This mirrors the bucket's `allowed_mime_types` exactly (§2.1). It is
/// duplicated deliberately: without it the bucket rejects the upload after the
/// file has already been transferred, and the user gets a raw StorageException
/// instead of a sentence. **If you change one, change the other.**
const _mimeByExtension = <String, String>{
  'pdf': 'application/pdf',
  'txt': 'text/plain',
  'md': 'text/markdown',
  'png': 'image/png',
  'jpg': 'image/jpeg',
  'jpeg': 'image/jpeg',
  'docx':
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  'pptx':
      'application/vnd.openxmlformats-officedocument.presentationml.presentation',
};

/// The bucket's own 50 MB cap, checked before the transfer rather than after.
const _maxBytes = 50 * 1024 * 1024;

enum UploadStage { idle, picking, uploading, done, failed }

class UploadState {
  const UploadState({
    this.stage = UploadStage.idle,
    this.fileName = '',
    this.byteSize = 0,
    this.progress = 0,
    this.secondsLeft,
    this.error,
  });

  final UploadStage stage;
  final String fileName;
  final int byteSize;

  /// 0…1 of the file handed to the socket. Real, not a timer — see
  /// `StorageRepository._uploadStreamed`.
  final double progress;

  /// Estimated from the rate achieved so far. Null until there is enough of a
  /// sample to be worth showing.
  final int? secondsLeft;

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

  /// The line under the bar: "4.2 MB · 12s left" while it runs, and just the
  /// size once there is nothing left to wait for.
  String get transferLabel {
    final left = secondsLeft;
    if (stage != UploadStage.uploading || left == null) return sizeLabel;
    return '$sizeLabel · ${left}s left';
  }

  UploadState copyWith({
    UploadStage? stage,
    String? fileName,
    int? byteSize,
    double? progress,
    int? secondsLeft,
    bool clearSecondsLeft = false,
    String? error,
    bool clearError = false,
  }) =>
      UploadState(
        stage: stage ?? this.stage,
        fileName: fileName ?? this.fileName,
        byteSize: byteSize ?? this.byteSize,
        progress: progress ?? this.progress,
        secondsLeft: clearSecondsLeft ? null : (secondsLeft ?? this.secondsLeft),
        error: clearError ? null : (error ?? this.error),
      );
}

class UploadViewModel extends Notifier<UploadState> {
  @override
  UploadState build() => const UploadState();

  /// Picks from [source], uploads to the private bucket, and records the
  /// material row. Returns the created material on success, null otherwise —
  /// the caller needs it to file the document into a category.
  Future<StudyMaterial?> pickAndUpload(UploadSource source) async {
    state = const UploadState(stage: UploadStage.picking);

    final XFile? picked;
    try {
      picked = await _pick(source);
    } catch (error) {
      // Most often a denied camera permission or no camera app to handle the
      // intent. Either way the user needs a sentence, not the exception.
      state = UploadState(
        stage: UploadStage.failed,
        error: source == UploadSource.camera
            ? "Couldn't open the camera. Check the app's permissions."
            : "Couldn't open the picker.",
      );
      return null;
    }

    if (picked == null) {
      // Cancelled — not an error, just back to where we started.
      state = const UploadState();
      return null;
    }

    final name = _fileName(source, picked);
    final mimeType = _mimeByExtension[_extension(name)];
    final size = await picked.length();

    state = UploadState(
      stage: UploadStage.uploading,
      fileName: name,
      byteSize: size,
    );

    // Both checks mirror a bucket constraint, so failing here says the same
    // thing the server would have — only before spending the transfer on it.
    if (mimeType == null) {
      state = state.copyWith(
        stage: UploadStage.failed,
        error: "StudyFlow can't read that kind of file yet.",
      );
      return null;
    }
    if (size > _maxBytes) {
      state = state.copyWith(
        stage: UploadStage.failed,
        error: 'That file is over the 50 MB limit.',
      );
      return null;
    }

    try {
      final userId = ref.read(currentUserIdProvider);
      final startedAt = DateTime.now();

      final storagePath =
          await ref.read(storageRepositoryProvider).uploadMaterial(
                userId: userId,
                file: File(picked.path),
                fileName: name,
                contentType: mimeType,
                onProgress: (sent) => _onProgress(sent, startedAt),
              );

      // Only now is it really 100%: the count above tracks bytes given to the
      // socket, and the last of them are still in flight until the response
      // lands. Snapping to 1.0 here is the one moment it is true.
      state = state.copyWith(progress: 1, clearSecondsLeft: true);

      final material =
          await ref.read(libraryRepositoryProvider).createMaterial(
                userId: userId,
                title: _title(source, name),
                storagePath: storagePath,
                mimeType: mimeType,
                byteSize: size,
              );

      // The library and Home's resume card both describe a world that just
      // changed.
      ref.invalidate(materialsProvider);
      ref.invalidate(resumeMaterialProvider);

      state = state.copyWith(stage: UploadStage.done, clearError: true);
      return material;
    } catch (error) {
      state = state.copyWith(stage: UploadStage.failed, error: '$error');
      return null;
    }
  }

  /// Folds one progress tick into the state, with an ETA from the rate so far.
  ///
  /// Capped at 99%: the bytes are on the socket, not acknowledged, so a bar
  /// sitting full while the request is still open would be the one part of
  /// this readout that lied.
  void _onProgress(double sent, DateTime startedAt) {
    if (state.stage != UploadStage.uploading) return;

    final elapsed = DateTime.now().difference(startedAt).inMilliseconds / 1000;
    // Below a second the rate is noise and the estimate swings wildly, so
    // there simply is no estimate yet.
    final left = (elapsed > 1 && sent > 0.02)
        ? ((elapsed / sent) - elapsed).ceil().clamp(1, 3600)
        : null;

    state = state.copyWith(
      progress: sent.clamp(0.0, 0.99),
      secondsLeft: left,
      clearSecondsLeft: left == null,
    );
  }

  Future<XFile?> _pick(UploadSource source) {
    switch (source) {
      case UploadSource.pdf:
        // Narrowed to PDF: this entry says "PDF", so offering .docx behind it
        // would be a different promise than the one on the button.
        return openFile(
          acceptedTypeGroups: const [
            XTypeGroup(
              label: 'PDF',
              extensions: ['pdf'],
              mimeTypes: ['application/pdf'],
            ),
          ],
        );

      case UploadSource.camera:
        return ImagePicker().pickImage(
          source: ImageSource.camera,
          // Full-page scans are legible well under the original sensor size,
          // and a 12 MP capture is a slow upload on a phone connection.
          maxWidth: 2400,
          imageQuality: 85,
        );

      case UploadSource.photos:
        return ImagePicker().pickImage(source: ImageSource.gallery);

      case UploadSource.text:
      case UploadSource.url:
        // Guarded by `usesPicker`; reaching here is a bug in the caller.
        throw UnsupportedError('$source has no picker yet');
    }
  }

  /// image_picker hands back a cache name like `image_picker_1234.jpg`, which
  /// would end up as the material's title. Documents keep their own name.
  String _fileName(UploadSource source, XFile picked) {
    final extension = _extension(picked.path);
    return switch (source) {
      UploadSource.camera => 'scan-${DateTime.now().millisecondsSinceEpoch}'
          '.${extension.isEmpty ? 'jpg' : extension}',
      _ => picked.name,
    };
  }

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  /// A camera capture has no name worth showing, so it gets a dated one. The
  /// time is part of it because two scans in a day are the normal case.
  String _title(UploadSource source, String fileName) {
    if (source != UploadSource.camera) {
      // The extension is noise in a title; mime_type already records it.
      return fileName.replaceAll(RegExp(r'\.[^.]+$'), '');
    }
    final now = DateTime.now();
    final hh = now.hour.toString().padLeft(2, '0');
    final mm = now.minute.toString().padLeft(2, '0');
    return 'Scan · ${_months[now.month - 1]} ${now.day}, $hh:$mm';
  }

  String _extension(String path) =>
      p.extension(path).replaceFirst('.', '').toLowerCase();

  void reset() => state = const UploadState();
}

final uploadProvider =
    NotifierProvider.autoDispose<UploadViewModel, UploadState>(
  UploadViewModel.new,
);
