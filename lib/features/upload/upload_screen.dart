// lib/features/upload/upload_screen.dart
//
// Presented as a modal over the shell. Picks a real file, uploads it to the
// private `materials` bucket, and records the row that makes it appear in the
// library.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/theme.dart';
import '../../core/widgets/widgets.dart';
import 'upload_view_model.dart';

class UploadScreen extends ConsumerWidget {
  const UploadScreen({super.key});

  Future<void> _pick(BuildContext context, WidgetRef ref) async {
    final ok = await ref.read(uploadProvider.notifier).pickAndUpload();
    if (!ok || !context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Added to your library.')),
    );
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sf = context.sf;
    final scheme = context.scheme;
    final upload = ref.watch(uploadProvider);

    final sources = <({
      IconData icon,
      String title,
      String meta,
      Color color,
      Color background
    })>[
      (
        icon: Icons.photo_camera_outlined,
        title: 'Scan with camera',
        meta: 'OCR-ready',
        color: sf.coralInk,
        background: sf.coralSoft
      ),
      (
        icon: Icons.image_outlined,
        title: 'Photo library',
        meta: 'JPG, PNG, HEIC',
        color: sf.violetInk,
        background: sf.lavenderSoft
      ),
      (
        icon: Icons.description_outlined,
        title: 'Paste text',
        meta: 'Notes & quotes',
        color: scheme.primary,
        background: sf.indigoSoft
      ),
      (
        icon: Icons.public_rounded,
        title: 'From URL',
        meta: 'Articles & web',
        color: sf.emeraldInk,
        background: sf.emeraldSoft
      ),
    ];

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 12, 22, 18),
              child: Row(
                children: [
                  SfIconButton(
                    icon: Icons.close_rounded,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Expanded(
                    child: Text(
                      'Add material',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: AppTextStyles.fontUi,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                        color: sf.ink,
                      ),
                    ),
                  ),
                  const SizedBox(width: 38),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(22, 0, 22, 28),
                children: [
                  _DropZone(
                    busy: upload.isBusy,
                    onBrowse: () => _pick(context, ref),
                  ),
                  const SizedBox(height: 20),
                  SfEyebrow('Or add from', color: sf.ink3),
                  const SizedBox(height: 10),
                  for (var row = 0; row < 2; row++) ...[
                    if (row > 0) const SizedBox(height: 10),
                    // IntrinsicHeight so both tiles in a row match height;
                    // a bare `stretch` Row would inherit the ListView's
                    // unbounded height.
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (var col = 0; col < 2; col++) ...[
                            if (col > 0) const SizedBox(width: 10),
                            Expanded(
                              child: _SourceTile(
                                source: sources[row * 2 + col],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                  // Only present once there is something to report. A
                  // permanent "Uploading" section with nothing in it was fine
                  // as a mockup; with a real transfer it would be a lie.
                  if (upload.stage != UploadStage.idle) ...[
                    const SizedBox(height: 22),
                    SfEyebrow(
                      switch (upload.stage) {
                        UploadStage.failed => 'Failed',
                        UploadStage.done => 'Added',
                        _ => 'Uploading',
                      },
                      color: sf.ink3,
                    ),
                    const SizedBox(height: 10),
                    SfCard(
                      child: Row(
                        children: [
                          SoftIconTile(
                            icon: switch (upload.stage) {
                              UploadStage.failed => Icons.error_outline_rounded,
                              UploadStage.done => Icons.check_rounded,
                              _ => Icons.picture_as_pdf_outlined,
                            },
                            color: upload.stage == UploadStage.done
                                ? sf.emeraldInk
                                : sf.coralInk,
                            background: upload.stage == UploadStage.done
                                ? sf.emeraldSoft
                                : sf.coralSoft,
                            width: 36,
                            height: 44,
                            radius: 8,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  upload.fileName.isEmpty
                                      ? 'Choosing a file…'
                                      : upload.fileName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: sf.ink,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                // The SDK reports no byte-level progress for a
                                // single upload, so this is indeterminate
                                // rather than a percentage invented to look
                                // busy.
                                if (upload.isBusy)
                                  const SfProgress(value: null)
                                else
                                  Text(
                                    upload.error ??
                                        'Ready in your library · '
                                            '${upload.sizeLabel}',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: upload.stage == UploadStage.failed
                                          ? sf.coralInk
                                          : sf.ink3,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (!upload.isBusy)
                            GestureDetector(
                              onTap: ref.read(uploadProvider.notifier).reset,
                              child: Container(
                                width: 28,
                                height: 28,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: scheme.surfaceContainerHigh,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(Icons.close_rounded,
                                    size: 14, color: sf.ink2),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DropZone extends StatelessWidget {
  const _DropZone({required this.onBrowse, this.busy = false});

  final VoidCallback onBrowse;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final sf = context.sf;
    final scheme = context.scheme;

    return DashedBorderBox(
      color: scheme.primary.withValues(alpha: 0.3),
      radius: 22,
      strokeWidth: 2,
      dash: 8,
      gap: 6,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
        decoration: BoxDecoration(
          color: sf.indigoSoft,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(18),
                boxShadow: AppShadows.resolve(
                    AppShadows.md, Theme.of(context).brightness),
              ),
              child: Icon(Icons.file_upload_outlined,
                  size: 28, color: scheme.primary),
            ),
            const SizedBox(height: 14),
            Text(
              'Drop your study material',
              style: TextStyle(
                fontFamily: AppTextStyles.fontUi,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
                color: sf.ink,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'PDFs, slides, notes, or images.\nUp to 50MB per file.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, height: 1.4, color: sf.ink2),
            ),
            const SizedBox(height: 14),
            SfButton(
              'Browse files',
              icon: Icons.add_rounded,
              busy: busy,
              onPressed: onBrowse,
            ),
          ],
        ),
      ),
    );
  }
}

class _SourceTile extends StatelessWidget {
  const _SourceTile({required this.source});

  final ({
    IconData icon,
    String title,
    String meta,
    Color color,
    Color background
  }) source;

  @override
  Widget build(BuildContext context) {
    final sf = context.sf;

    return SfCard(
      padding: const EdgeInsets.all(14),
      radius: AppRadius.md + 2,
      onTap: () => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${source.title} — UI only for now')),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          SoftIconTile(
            icon: source.icon,
            color: source.color,
            background: source.background,
            width: 38,
            height: 38,
          ),
          const SizedBox(height: 10),
          Text(
            source.title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.1,
              color: sf.ink,
            ),
          ),
          const SizedBox(height: 2),
          Text(source.meta, style: TextStyle(fontSize: 11, color: sf.ink3)),
        ],
      ),
    );
  }
}
