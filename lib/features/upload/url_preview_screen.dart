// lib/features/upload/url_preview_screen.dart
//
// The page, loaded in-app, so you can see what you are about to save before
// you save it. Proceed keeps the *link* — nothing is downloaded (§9: the AI
// that would read it does not exist yet).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/navigation.dart';
import '../../core/theme/theme.dart';
import '../../core/widgets/widgets.dart';
import '../categories/category_screen.dart';
import 'url_view_model.dart';

/// Loading progress of the embedded page, 0…1. Local to this screen, but a
/// provider rather than State because the whole app is setState-free (§4).
final _loadProgress = NotifierProvider.autoDispose<_Progress, double>(
  _Progress.new,
);

class _Progress extends Notifier<double> {
  @override
  double build() => 0;
  void set(double value) => state = value;
}

final _saving = NotifierProvider.autoDispose<_Saving, bool>(_Saving.new);

class _Saving extends Notifier<bool> {
  @override
  bool build() => false;
  void set(bool value) => state = value;
}

class UrlPreviewScreen extends ConsumerStatefulWidget {
  const UrlPreviewScreen({super.key, required this.url});

  final Uri url;

  @override
  ConsumerState<UrlPreviewScreen> createState() => _UrlPreviewScreenState();
}

class _UrlPreviewScreenState extends ConsumerState<UrlPreviewScreen> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (progress) =>
              ref.read(_loadProgress.notifier).set(progress / 100),
          onPageFinished: (_) => ref.read(_loadProgress.notifier).set(1),
        ),
      )
      ..loadRequest(widget.url);
  }

  Future<void> _proceed() async {
    ref.read(_saving.notifier).set(true);

    // The page's own <title> makes a far better library entry than the URL,
    // which is unreadable in a list. Null is fine — the saver falls back to
    // the host.
    String? title;
    try {
      title = await _controller.getTitle();
    } catch (_) {
      title = null;
    }

    final material =
        await ref.read(saveUrlMaterialProvider)(widget.url, title);
    if (!mounted) return;
    ref.read(_saving.notifier).set(false);

    if (material == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't save that link. Try again.")),
      );
      return;
    }

    Navigator.of(context).pushReplacement(
      sfModalRoute(builder: (_) => CategoryScreen(material: material)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sf = context.sf;
    final progress = ref.watch(_loadProgress);
    final saving = ref.watch(_saving);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            SfModalHeader(
              title: widget.url.host.replaceFirst('www.', ''),
              padding: const EdgeInsets.fromLTRB(22, 12, 22, 10),
            ),
            // Only while it is loading. A full bar left on screen after the
            // page arrives says the wait is still happening.
            if (progress < 1)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: SfProgress(value: progress, height: 3, animated: true),
              ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 12, 22, 0),
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
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 12, 22, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    // States plainly what Proceed does. "Save" over a rendered
                    // page reads as "save this page", which is not what
                    // happens.
                    'Only the link is saved. Flow will read the page when the '
                        'AI is connected.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, height: 1.4, color: sf.ink3),
                  ),
                  const SizedBox(height: 10),
                  SfButton(
                    'Proceed',
                    size: SfButtonSize.lg,
                    expand: true,
                    busy: saving,
                    trailingIcon: Icons.arrow_forward_rounded,
                    onPressed: saving ? null : _proceed,
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
