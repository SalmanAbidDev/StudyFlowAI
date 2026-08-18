// lib/features/upload/url_view_model.dart
//
// Adding a page from the web. Nothing is downloaded — the material stores the
// link, for the AI to fetch once there is an AI (§9).

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../data/models/study_material.dart';
import '../../data/supabase_providers.dart';
import '../home/home_view_model.dart';
import '../materials/materials_view_model.dart';

enum UrlCheck { empty, invalid, checking, reachable, unreachable }

class UrlState {
  const UrlState({this.check = UrlCheck.empty, this.url});

  final UrlCheck check;

  /// The normalised URL — what gets saved, not what was typed.
  final Uri? url;

  bool get ready => check == UrlCheck.reachable && url != null;
}

/// Turns what someone types into a URL, or null if it cannot be one.
///
/// A bare `example.com` gets https:// — nobody types the scheme, and rejecting
/// them for it would be pedantry. Anything without a dot in the host is a typo
/// rather than a site.
Uri? normaliseUrl(String input) {
  var text = input.trim();
  if (text.isEmpty) return null;
  if (!text.contains('://')) text = 'https://$text';

  final uri = Uri.tryParse(text);
  if (uri == null || !uri.hasAuthority) return null;
  if (uri.scheme != 'http' && uri.scheme != 'https') return null;
  if (!uri.host.contains('.') || uri.host.endsWith('.')) return null;
  return uri;
}

class UrlViewModel extends Notifier<UrlState> {
  Timer? _debounce;
  var _generation = 0;

  @override
  UrlState build() {
    // The notifier outlives individual keystrokes; a pending timer must not
    // outlive the notifier.
    ref.onDispose(() => _debounce?.cancel());
    return const UrlState();
  }

  /// Called on every keystroke. The request is debounced — checking on each
  /// character would fire a dozen requests to type one hostname.
  void onChanged(String input) {
    _debounce?.cancel();
    final generation = ++_generation;

    final uri = normaliseUrl(input);
    if (input.trim().isEmpty) {
      state = const UrlState();
      return;
    }
    if (uri == null) {
      state = const UrlState(check: UrlCheck.invalid);
      return;
    }

    state = UrlState(check: UrlCheck.checking, url: uri);
    _debounce = Timer(const Duration(milliseconds: 600), () async {
      final reachable = await _reach(uri);
      // A slower earlier request must not overwrite a newer answer.
      if (generation != _generation) return;
      state = UrlState(
        check: reachable ? UrlCheck.reachable : UrlCheck.unreachable,
        url: uri,
      );
    });
  }

  /// Does something answer at this address?
  ///
  /// HEAD first because it is cheap, then GET: plenty of sites answer 405 or
  /// 403 to HEAD while serving the page perfectly well. Any HTTP response
  /// below 400 counts — a 401 or 403 means the site exists but will not talk
  /// to us, which is not the same as "does not exist", but it is not something
  /// we can hand to a reader either.
  Future<bool> _reach(Uri uri) async {
    final client = http.Client();
    try {
      final head = await client
          .head(uri)
          .timeout(const Duration(seconds: 8));
      if (head.statusCode < 400) return true;

      final get = await client.get(uri).timeout(const Duration(seconds: 8));
      return get.statusCode < 400;
    } catch (_) {
      // DNS failure, timeout, refused connection, bad certificate.
      return false;
    } finally {
      client.close();
    }
  }
}

final urlProvider =
    NotifierProvider.autoDispose<UrlViewModel, UrlState>(UrlViewModel.new);

/// Saves the link as a material. [title] is the page's own title when the
/// preview managed to read one; the host is a decent fallback and better than
/// the full URL, which is unreadable in a list.
final saveUrlMaterialProvider =
    Provider<Future<StudyMaterial?> Function(Uri, String?)>((ref) {
  return (uri, title) async {
    try {
      final material =
          await ref.read(libraryRepositoryProvider).createMaterial(
                userId: ref.read(currentUserIdProvider),
                title: (title == null || title.trim().isEmpty)
                    ? uri.host.replaceFirst('www.', '')
                    : title.trim(),
                sourceUrl: uri.toString(),
                mimeType: 'text/html',
              );

      ref.invalidate(materialsProvider);
      ref.invalidate(resumeMaterialProvider);
      return material;
    } catch (_) {
      return null;
    }
  };
});
