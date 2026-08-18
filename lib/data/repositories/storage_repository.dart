// lib/data/repositories/storage_repository.dart

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';

const materialsBucket = 'materials';

class StorageRepository {
  const StorageRepository(this._client);

  final SupabaseClient _client;

  /// Uploads under `<user-id>/<timestamp>-<name>`. The leading segment is not
  /// cosmetic: the bucket's RLS policies compare it to auth.uid(), so it is
  /// what stops one account reading another's files.
  ///
  /// [onProgress] receives 0…1 as bytes go out. Supplying it switches from
  /// `storage.upload()` to a streamed request — see [_uploadStreamed] for why
  /// and what that costs.
  Future<String> uploadMaterial({
    required String userId,
    required File file,
    required String fileName,
    String? contentType,
    void Function(double sent)? onProgress,
  }) async {
    final safeName = p.basename(fileName).replaceAll(RegExp(r'[^\w.\-]'), '_');
    final path = '$userId/${DateTime.now().millisecondsSinceEpoch}-$safeName';

    if (onProgress == null) {
      await _client.storage.from(materialsBucket).upload(
            path,
            file,
            // Stated rather than sniffed. The bucket matches uploads against
            // `allowed_mime_types`, and a camera capture arriving as
            // application/octet-stream is rejected on a file it should accept.
            fileOptions: FileOptions(upsert: false, contentType: contentType),
          );
      return path;
    }

    await _uploadStreamed(
      path: path,
      file: file,
      contentType: contentType,
      onProgress: onProgress,
    );
    return path;
  }

  /// Stores typed or pasted text as a `.txt` in the same bucket as every other
  /// material, so nothing downstream has to know it was not a file.
  ///
  /// No streaming and no progress: a thousand words is a few kilobytes, and a
  /// progress bar for something that finishes in one packet is theatre.
  Future<String> uploadText({
    required String userId,
    required String fileName,
    required String text,
  }) async {
    final safeName = p.basename(fileName).replaceAll(RegExp(r'[^\w.\-]'), '_');
    final path = '$userId/${DateTime.now().millisecondsSinceEpoch}-$safeName';

    await _client.storage.from(materialsBucket).uploadBinary(
          path,
          Uint8List.fromList(utf8.encode(text)),
          fileOptions: const FileOptions(
            upsert: false,
            contentType: 'text/plain',
          ),
        );
    return path;
  }

  /// The same POST `storage.upload()` makes, sent as a stream so the bytes can
  /// be counted on the way past.
  ///
  /// This exists because **the storage SDK exposes no progress callback** —
  /// `upload()` builds a MultipartRequest and hands the whole body over at
  /// once, so there is nothing to observe. The choice was a real percentage or
  /// an invented one.
  ///
  /// What it costs: the SDK's automatic retry/backoff does not apply here.
  /// Everything else — the endpoint, the auth headers, the response shape — is
  /// taken from the client rather than rebuilt, so a URL or token change
  /// follows automatically.
  ///
  /// What it measures: bytes handed to the socket, not bytes acknowledged by
  /// the server. The tail of a file can still be in flight when the count
  /// reaches the total, which is why the caller holds short of 100% until the
  /// response actually lands.
  Future<void> _uploadStreamed({
    required String path,
    required File file,
    required String? contentType,
    required void Function(double) onProgress,
  }) async {
    final total = await file.length();
    final uri = Uri.parse('${_client.storage.url}/object/$materialsBucket/$path');

    final headers = <String, String>{
      ..._client.storage.headers,
      'Authorization': ?_accessToken,
      'content-type': ?contentType,
      // Matches `FileOptions(upsert: false)` — a collision is an error, not a
      // silent overwrite of somebody's material.
      'x-upsert': 'false',
    };

    final request = _CountingRequest(
      'POST',
      uri,
      file.openRead(),
      total,
      onProgress,
    )..headers.addAll(headers);

    final response = await http.Response.fromStream(await request.send());
    if (response.statusCode >= 200 && response.statusCode < 300) return;

    // Surface the server's own message where there is one, so a rejected mime
    // type or a size cap reads as itself rather than as "500".
    String message;
    try {
      final body = jsonDecode(response.body);
      message = body is Map && body['message'] is String
          ? body['message'] as String
          : response.body;
    } catch (_) {
      message = response.body;
    }
    throw StorageException(message, statusCode: '${response.statusCode}');
  }

  /// The live session's token, which is what the bucket policies check. Taken
  /// per request rather than from the headers captured at construction, so a
  /// refresh mid-session is picked up.
  String? get _accessToken {
    final token = _client.auth.currentSession?.accessToken;
    return token == null ? null : 'Bearer $token';
  }

  /// The object's bytes. The bucket is private, so this goes through the
  /// authenticated client rather than a plain GET on a URL.
  Future<Uint8List> download(String path) {
    return _client.storage.from(materialsBucket).download(path);
  }

  /// The bucket is private, so a URL only works for as long as it is signed.
  Future<String> signedUrl(String path, {Duration ttl = const Duration(hours: 1)}) {
    return _client.storage
        .from(materialsBucket)
        .createSignedUrl(path, ttl.inSeconds);
  }

  Future<void> delete(String path) {
    return _client.storage.from(materialsBucket).remove([path]);
  }
}

/// A request whose body is counted as the client drains it.
///
/// Counting in `finalize()` rather than pushing into a `StreamedRequest` sink
/// is what keeps backpressure intact: the http client pulls chunks at the rate
/// the socket accepts them, so the count tracks the transfer instead of
/// racing ahead of it and buffering the whole file in memory.
class _CountingRequest extends http.BaseRequest {
  _CountingRequest(
    super.method,
    super.url,
    this._body,
    this._total,
    this._onProgress,
  ) {
    contentLength = _total;
  }

  final Stream<List<int>> _body;
  final int _total;
  final void Function(double) _onProgress;

  @override
  http.ByteStream finalize() {
    super.finalize();
    var sent = 0;
    return http.ByteStream(
      _body.map((chunk) {
        sent += chunk.length;
        if (_total > 0) _onProgress(sent / _total);
        return chunk;
      }),
    );
  }
}
