// lib/features/documents/document_screen.dart
//
// What a material actually is, shown rather than described. This replaced a
// screen that called every document "Summary" and rendered a list of AI
// sections in place of the thing the user had uploaded — the summary now lives
// one tap away, behind the Summarize button.

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/navigation.dart';
import '../../core/theme/theme.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models/study_material.dart';
import '../chat/chat_screen.dart';
import '../chat/chat_view_model.dart';
import '../flashcards/flashcards_screen.dart';
import '../quiz/quiz_screen.dart';
import '../summaries/summaries_screen.dart';
import '../materials/materials_view_model.dart';
import 'document_view_model.dart';

class DocumentScreen extends ConsumerWidget {
  const DocumentScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sf = context.sf;
    final material = ref.watch(currentMaterialProvider).value;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 12, 22, 14),
              child: Row(
                children: [
                  SfIconButton(
                    icon: Icons.arrow_back_rounded,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // The type, not the word "Summary". Every material used
                        // to be labelled the same thing regardless of what it
                        // was.
                        SfEyebrow(
                          material?.kind.label ?? 'Document',
                          tracking: 1,
                        ),
                        Text(
                          material?.title ?? 'Loading…',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: AppTextStyles.fontUi,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                            color: sf.ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Exactly the button the bookmark was, with the summarize
                  // glyph in its place. Tinted brand rather than ink, because
                  // it is the one control here that invokes Flow.
                  SfIconButton(
                    icon: Icons.auto_awesome_rounded,
                    iconSize: 16,
                    color: context.scheme.primary,
                    onPressed: () => Navigator.of(context).push(
                      sfRoute(builder: (_) => const SummariesScreen()),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 0, 22, 0),
                child: _DocumentBody(material: material),
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(22, 12, 22, 16),
              child: Row(
                children: [
                  Expanded(
                    child: SfButton(
                      'Flashcards',
                      variant: SfButtonVariant.secondary,
                      icon: Icons.style_outlined,
                      expand: true,
                      onPressed: () => Navigator.of(context).push(
                        sfModalRoute(builder: (_) => const FlashcardsScreen()),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SfButton(
                      'Quiz me',
                      icon: Icons.help_outline_rounded,
                      expand: true,
                      onPressed: () => Navigator.of(context).push(
                        sfModalRoute(builder: (_) => const QuizScreen()),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // The orb alone, where the dead Share button used to be.
                  // Painted rather than a glyph, so it goes in `leading`.
                  SfButton.iconOnly(
                    leading: const FlowOrb(size: 18),
                    // Hands Flow the document you are reading. Opening the
                    // chat from here and being told "No document selected"
                    // asked you to go and find the thing already on screen.
                    onPressed: material == null
                        ? null
                        : () {
                            ref
                                .read(chatDocumentProvider.notifier)
                                .update(material.id);
                            Navigator.of(context).push(
                              sfRoute(builder: (_) => const ChatScreen()),
                            );
                          },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Picks the renderer from the material's own kind.
class _DocumentBody extends ConsumerWidget {
  const _DocumentBody({required this.material});

  final StudyMaterial? material;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (material == null) {
      return const SfLoadingList(rows: 1, height: 400, padding: EdgeInsets.zero);
    }

    // A link has nothing in the bucket, so it never waits on a download.
    if (material!.kind == MaterialKind.link) {
      return _LinkBody(material: material!);
    }

    final bytes = ref.watch(documentBytesProvider);

    return bytes.when(
      loading: () =>
          const SfLoadingList(rows: 1, height: 400, padding: EdgeInsets.zero),
      error: (error, _) => SfErrorView(
        error: error,
        onRetry: () => ref.invalidate(documentBytesProvider),
      ),
      data: (data) {
        if (data == null || data.isEmpty) {
          return const SfEmptyView(
            icon: Icons.description_outlined,
            title: 'Nothing to show',
            body: 'This material has no file attached to it.',
          );
        }

        return switch (material!.kind) {
          MaterialKind.pdf => _PdfBody(bytes: data, id: material!.id),
          MaterialKind.image => _ImageBody(bytes: data),
          MaterialKind.text => const _TextBody(),
          MaterialKind.link => _LinkBody(material: material!),
        };
      },
    );
  }
}

class _PdfBody extends StatelessWidget {
  const _PdfBody({required this.bytes, required this.id});

  final Uint8List bytes;

  /// pdfrx caches by source name, so two materials must not share one.
  final String id;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: AppRadius.brLg,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: AppRadius.brLg,
          border: Border.all(color: context.scheme.outline),
        ),
        // pdfrx brings its own pinch-zoom and page scrolling, so this is not
        // wrapped in an InteractiveViewer — two zoom handlers on one surface
        // fight each other.
        child: PdfViewer.data(
          bytes,
          sourceName: id,
          params: PdfViewerParams(
            margin: 8,
            // `maxScale` on PdfViewerParams is deprecated in favour of a size
            // delegate; 8x is enough to read the small print on a scan.
            sizeDelegateProvider:
                PdfViewerSizeDelegateProviderLegacy(maxScale: 8),
          ),
        ),
      ),
    );
  }
}

class _ImageBody extends StatelessWidget {
  const _ImageBody({required this.bytes});

  final Uint8List bytes;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: AppRadius.brLg,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: AppRadius.brLg,
          border: Border.all(color: context.scheme.outline),
        ),
        child: InteractiveViewer(
          minScale: 1,
          maxScale: 8,
          child: Center(child: Image.memory(bytes, fit: BoxFit.contain)),
        ),
      ),
    );
  }
}

class _TextBody extends ConsumerWidget {
  const _TextBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sf = context.sf;
    final text = ref.watch(documentTextProvider).value ?? '';

    return ClipRRect(
      borderRadius: AppRadius.brLg,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: context.scheme.surface,
          borderRadius: AppRadius.brLg,
          border: Border.all(color: context.scheme.outline),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          // Selectable: a note you typed is text you may want to copy back
          // out, and there is no other way to get it off this screen.
          child: SelectableText(
            text,
            style: TextStyle(
              fontFamily: AppTextStyles.fontUi,
              fontSize: 15,
              height: 1.55,
              color: sf.ink,
            ),
          ),
        ),
      ),
    );
  }
}

/// A link has no file to render, so the address itself is the content. Centred
/// as a card, and tappable — a URL you cannot open is a dead end.
class _LinkBody extends StatelessWidget {
  const _LinkBody({required this.material});

  final StudyMaterial material;

  @override
  Widget build(BuildContext context) {
    final sf = context.sf;
    final url = material.sourceUrl ?? '';
    final uri = Uri.tryParse(url);
    final host = uri?.host.replaceFirst('www.', '') ?? url;

    return Center(
      child: SfCard(
        padding: const EdgeInsets.all(22),
        onTap: uri == null
            ? null
            : () => Navigator.of(context).push(
                  sfModalRoute(builder: (_) => _LinkViewer(url: uri)),
                ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SoftIconTile(
              icon: Icons.public_rounded,
              color: context.scheme.primary,
              background: sf.indigoSoft,
              width: 56,
              height: 56,
              radius: 18,
              iconSize: 26,
            ),
            const SizedBox(height: 14),
            Text(
              host,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppTextStyles.fontUi,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
                color: sf.ink,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              url,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, height: 1.4, color: sf.ink3),
            ),
            const SizedBox(height: 16),
            const SfChip(
              'Tap to open',
              icon: Icons.open_in_new_rounded,
              small: true,
            ),
          ],
        ),
      ),
    );
  }
}

/// The saved page, read-only. `UrlPreviewScreen` looks the same but ends in
/// "Proceed" and creates a material — offering that on something already in
/// the library would file it twice.
class _LinkViewer extends StatefulWidget {
  const _LinkViewer({required this.url});

  final Uri url;

  @override
  State<_LinkViewer> createState() => _LinkViewerState();
}

class _LinkViewerState extends State<_LinkViewer> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadRequest(widget.url);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            SfModalHeader(
              title: widget.url.host.replaceFirst('www.', ''),
              padding: const EdgeInsets.fromLTRB(22, 12, 22, 10),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 0, 22, 16),
                child: ClipRRect(
                  borderRadius: AppRadius.brLg,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: AppRadius.brLg,
                      border: Border.all(color: context.scheme.outline),
                    ),
                    child: WebViewWidget(controller: _controller),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
