// lib/features/upload/upload_screen.dart
//
// Presented as a modal over the shell. Picks a real file, uploads it to the
// private `materials` bucket, and records the row that makes it appear in the
// library.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/navigation.dart';
import '../../core/theme/theme.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models/study_material.dart';
import '../categories/category_screen.dart';
import '../documents/document_screen.dart';
import '../materials/history_screen.dart';
import '../materials/material_browser.dart';
import '../materials/materials_view_model.dart';
import 'paste_text_screen.dart';
import 'upload_view_model.dart';
import 'url_preview_screen.dart';
import 'url_view_model.dart';

/// How each [UploadSource] presents itself. Kept here rather than on the enum
/// because the colours are theme lookups, and the enum lives in the view model
/// where there is no BuildContext.
typedef SourceStyle = ({
  IconData icon,
  String title,
  String meta,
  Color color,
  Color background,
});

SourceStyle sourceStyle(BuildContext context, UploadSource source) {
  final sf = context.sf;
  return switch (source) {
    UploadSource.pdf => (
        icon: Icons.picture_as_pdf_outlined,
        title: 'PDF document',
        meta: 'Up to 50MB',
        color: sf.coralInk,
        background: sf.coralSoft,
      ),
    UploadSource.camera => (
        icon: Icons.photo_camera_outlined,
        title: 'Scan with camera',
        meta: 'Snap a page',
        color: sf.violetInk,
        background: sf.lavenderSoft,
      ),
    UploadSource.photos => (
        icon: Icons.image_outlined,
        title: 'Photo library',
        // Only what the bucket actually accepts. It used to advertise HEIC,
        // which the upload would then reject.
        meta: 'JPG & PNG',
        color: sf.emeraldInk,
        background: sf.emeraldSoft,
      ),
    UploadSource.text => (
        icon: Icons.description_outlined,
        title: 'Paste text',
        meta: 'Notes & quotes',
        color: context.scheme.primary,
        background: sf.indigoSoft,
      ),
    UploadSource.url => (
        icon: Icons.public_rounded,
        title: 'From URL',
        meta: 'Articles & web',
        color: sf.ink2,
        background: context.scheme.surfaceContainerHigh,
      ),
  };
}

class UploadScreen extends ConsumerWidget {
  const UploadScreen({super.key});

  /// Runs one source. Three of the five open a picker; the other two have
  /// their own screens and never touch `pickAndUpload`.
  Future<void> _pick(
    BuildContext context,
    WidgetRef ref,
    UploadSource source,
  ) async {
    switch (source) {
      case UploadSource.text:
        Navigator.of(context).push(
          sfModalRoute(builder: (_) => const PasteTextScreen()),
        );
        return;

      case UploadSource.url:
        final url = await showSfSheet<Uri>(context, (_) => const _UrlSheet());
        if (url == null || !context.mounted) return;
        Navigator.of(context).push(
          sfModalRoute(builder: (_) => UrlPreviewScreen(url: url)),
        );
        return;

      case UploadSource.pdf:
      case UploadSource.camera:
      case UploadSource.photos:
        break;
    }

    final material =
        await ref.read(uploadProvider.notifier).pickAndUpload(source);
    if (material == null || !context.mounted) return;

    // Straight into filing it, replacing this screen rather than stacking on
    // top: the upload is finished, and leaving it behind would give the
    // mandatory category screen something to fall back to.
    Navigator.of(context).pushReplacement(
      sfModalRoute(builder: (_) => CategoryScreen(material: material)),
    );
  }

  /// "Browse files" no longer jumps straight into the document picker — it
  /// asks where the material is coming from first, because three of the five
  /// answers are not files on disk.
  Future<void> _chooseSource(BuildContext context, WidgetRef ref) async {
    final source = await showSfSheet<UploadSource>(
      context,
      (_) => const _SourceSheet(),
    );
    if (source == null || !context.mounted) return;
    await _pick(context, ref, source);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sf = context.sf;
    final upload = ref.watch(uploadProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const SfModalHeader(title: 'Add material'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(22, 0, 22, 28),
                children: [
                  _DropZone(
                    busy: upload.isBusy,
                    onBrowse: () => _chooseSource(context, ref),
                  ),
                  // Above "Or add from", not below it. A transfer in flight is
                  // the most important thing on the screen while it runs, and
                  // it used to sit under two rows of tiles where a phone-sized
                  // viewport cut it off entirely.
                  //
                  // Only present once there is something to report. A permanent
                  // "Uploading" section with nothing in it was fine as a
                  // mockup; with a real transfer it would be a lie.
                  if (upload.stage != UploadStage.idle) ...[
                    const SizedBox(height: 20),
                    SfEyebrow(
                      switch (upload.stage) {
                        UploadStage.failed => 'Failed',
                        UploadStage.done => 'Added',
                        _ => 'Uploading',
                      },
                      color: sf.ink3,
                    ),
                    const SizedBox(height: 10),
                    _UploadCard(
                      upload: upload,
                      onDismiss: ref.read(uploadProvider.notifier).reset,
                    ),
                  ],
                  const SizedBox(height: 20),
                  SfEyebrow('Or add from', color: sf.ink3),
                  const SizedBox(height: 10),
                  // Two per row, derived from the enum rather than a hand-kept
                  // list — an odd count leaves the last cell empty instead of
                  // stretching one tile to full width.
                  for (var row = 0;
                      row < (UploadSource.values.length + 1) ~/ 2;
                      row++) ...[
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
                              child: row * 2 + col < UploadSource.values.length
                                  ? _SourceTile(
                                      source: UploadSource
                                          .values[row * 2 + col],
                                      onTap: () => _pick(
                                        context,
                                        ref,
                                        UploadSource.values[row * 2 + col],
                                      ),
                                    )
                                  : const SizedBox.shrink(),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                  const _History(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The last few uploads, so this screen can answer "did that one go through?"
/// without a trip to the Materials tab. Absent on an empty library — a
/// "History" heading over nothing is furniture.
class _History extends ConsumerWidget {
  const _History();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all = ref.watch(materialsProvider).value ?? const <StudyMaterial>[];
    if (all.isEmpty) return const SizedBox.shrink();

    // `materialsProvider` is already newest-first, so this is the most recent
    // handful without a second sort.
    final recent = all.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),
        SectionHeader(
          'History',
          // Always offered, even when all three fit here: the History screen
          // carries the search box, which is the reason to go there once the
          // library is bigger than a glance.
          action: 'View all',
          onAction: () => Navigator.of(context).push(
            sfRoute(builder: (_) => const HistoryScreen()),
          ),
        ),
        for (var i = 0; i < recent.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          MaterialRow(
            material: recent[i],
            // The percentage belongs where you go to read; here the question
            // is only whether the file arrived.
            showProgress: false,
            onTap: () {
              ref.read(selectedMaterialProvider.notifier).update(recent[i].id);
              Navigator.of(context).push(
                sfRoute(builder: (_) => const DocumentScreen()),
              );
            },
          ),
        ],
      ],
    );
  }
}

/// The transfer readout: name, live percentage, gradient bar, and what is left
/// to wait for. Every number in it is measured — see `UploadState.progress`.
class _UploadCard extends StatelessWidget {
  const _UploadCard({required this.upload, required this.onDismiss});

  final UploadState upload;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final sf = context.sf;
    final scheme = context.scheme;
    final done = upload.stage == UploadStage.done;
    final failed = upload.stage == UploadStage.failed;

    return SfCard(
      child: Row(
        children: [
          SoftIconTile(
            icon: switch (upload.stage) {
              UploadStage.failed => Icons.error_outline_rounded,
              UploadStage.done => Icons.check_rounded,
              _ => Icons.picture_as_pdf_outlined,
            },
            color: done ? sf.emeraldInk : sf.coralInk,
            background: done ? sf.emeraldSoft : sf.coralSoft,
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
                Row(
                  children: [
                    Expanded(
                      child: Text(
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
                    ),
                    if (upload.stage == UploadStage.uploading) ...[
                      const SizedBox(width: 8),
                      SfMono(
                        '${(upload.progress * 100).round()}%',
                        color: sf.ink3,
                      ),
                    ],
                  ],
                ),
                if (upload.stage == UploadStage.uploading) ...[
                  const SizedBox(height: 6),
                  SfProgress(value: upload.progress, animated: true),
                  const SizedBox(height: 4),
                  Text(
                    upload.transferLabel,
                    style: TextStyle(fontSize: 11, color: sf.ink3),
                  ),
                ] else if (upload.stage == UploadStage.picking) ...[
                  const SizedBox(height: 6),
                  // Genuinely unknown: nothing has been chosen yet, so there
                  // is no total to be a fraction of.
                  const SfProgress(value: null),
                ] else ...[
                  const SizedBox(height: 4),
                  Text(
                    upload.error ??
                        'Ready in your library · ${upload.sizeLabel}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: failed ? sf.coralInk : sf.ink3,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (!upload.isBusy)
            GestureDetector(
              onTap: onDismiss,
              child: Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.close_rounded, size: 14, color: sf.ink2),
              ),
            ),
        ],
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
  const _SourceTile({required this.source, required this.onTap});

  final UploadSource source;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final sf = context.sf;
    final style = sourceStyle(context, source);

    return SfCard(
      padding: const EdgeInsets.all(14),
      radius: AppRadius.md + 2,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          SoftIconTile(
            icon: style.icon,
            color: style.color,
            background: style.background,
            width: 38,
            height: 38,
          ),
          const SizedBox(height: 10),
          Text(
            style.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.1,
              color: sf.ink,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            style.meta,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, color: sf.ink3),
          ),
        ],
      ),
    );
  }
}

/// Where is this material coming from? Pops the chosen [UploadSource]; the
/// caller runs it, so this sheet knows nothing about pickers or uploads.
class _SourceSheet extends StatelessWidget {
  const _SourceSheet();

  @override
  Widget build(BuildContext context) {
    final sf = context.sf;

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
                  'Add material',
                  style: AppTextStyles.heading.copyWith(
                    fontSize: 20,
                    letterSpacing: -0.5,
                    color: sf.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Where is it coming from?',
                  style: TextStyle(fontSize: 13, color: sf.ink3),
                ),
              ],
            ),
          ),
          for (final source in UploadSource.values) ...[
            if (source != UploadSource.values.first)
              const SizedBox(height: 8),
            _SourceRow(source: source),
          ],
        ],
      ),
    );
  }
}

/// Asks for a web address and checks it before letting you past. Pops the
/// normalised [Uri]; the caller opens the preview.
class _UrlSheet extends ConsumerStatefulWidget {
  const _UrlSheet();

  @override
  ConsumerState<_UrlSheet> createState() => _UrlSheetState();
}

class _UrlSheetState extends ConsumerState<_UrlSheet> {
  final _field = TextEditingController();

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sf = context.sf;
    final state = ref.watch(urlProvider);

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
                  'From URL',
                  style: AppTextStyles.heading.copyWith(
                    fontSize: 20,
                    letterSpacing: -0.5,
                    color: sf.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Paste a link and we will check it is reachable.',
                  style: TextStyle(fontSize: 13, color: sf.ink3),
                ),
              ],
            ),
          ),
          SfField(
            controller: _field,
            hint: 'example.com/article',
            icon: Icons.public_rounded,
            keyboardType: TextInputType.url,
            onChanged: ref.read(urlProvider.notifier).onChanged,
            // The verdict sits inside the field, next to what it judges.
            trailing: switch (state.check) {
              UrlCheck.checking => SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: sf.ink3,
                  ),
                ),
              UrlCheck.reachable => Icon(Icons.check_circle_rounded,
                  size: 20, color: sf.emerald),
              UrlCheck.invalid || UrlCheck.unreachable => Icon(
                  Icons.error_outline_rounded,
                  size: 20,
                  color: sf.coralInk,
                ),
              UrlCheck.empty => null,
            },
          ),
          // Only ever says something once there is something to say, and says
          // which of the two problems it is: a typo is not an outage.
          if (state.check == UrlCheck.invalid ||
              state.check == UrlCheck.unreachable) ...[
            const SizedBox(height: 8),
            Text(
              state.check == UrlCheck.invalid
                  ? "That doesn't look like a web address."
                  : "Couldn't reach that site. Check the link or your "
                      'connection.',
              style: TextStyle(fontSize: 12, height: 1.4, color: sf.coralInk),
            ),
          ],
          const SizedBox(height: 18),
          SfButton(
            'Continue',
            size: SfButtonSize.lg,
            expand: true,
            trailingIcon: Icons.arrow_forward_rounded,
            onPressed: state.ready
                ? () => Navigator.of(context).pop(state.url)
                : null,
          ),
        ],
      ),
    );
  }
}

class _SourceRow extends StatelessWidget {
  const _SourceRow({required this.source});

  final UploadSource source;

  @override
  Widget build(BuildContext context) {
    final sf = context.sf;
    final scheme = context.scheme;
    final style = sourceStyle(context, source);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: AppRadius.brLg,
        border: Border.all(color: scheme.outline),
      ),
      child: Material(
          color: Colors.transparent,
          borderRadius: AppRadius.brLg,
          child: InkWell(
            onTap: () => Navigator.of(context).pop(source),
            borderRadius: AppRadius.brLg,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  SoftIconTile(
                    icon: style.icon,
                    color: style.color,
                    background: style.background,
                    width: 40,
                    height: 40,
                    radius: 12,
                    iconSize: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          style.title,
                          style: TextStyle(
                            fontFamily: AppTextStyles.fontUi,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.2,
                            color: sf.ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          style.meta,
                          style: TextStyle(fontSize: 12, color: sf.ink3),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.chevron_right_rounded, size: 18, color: sf.ink4),
                ],
              ),
            ),
          ),
        ),
    );
  }
}
