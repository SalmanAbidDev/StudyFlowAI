// lib/data/repositories/storage_repository.dart

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';

const materialsBucket = 'materials';

class StorageRepository {
  const StorageRepository(this._client);

  final SupabaseClient _client;

  /// Uploads under `<user-id>/<timestamp>-<name>`. The leading segment is not
  /// cosmetic: the bucket's RLS policies compare it to auth.uid(), so it is
  /// what stops one account reading another's files.
  Future<String> uploadMaterial({
    required String userId,
    required File file,
    required String fileName,
  }) async {
    final safeName = p.basename(fileName).replaceAll(RegExp(r'[^\w.\-]'), '_');
    final path = '$userId/${DateTime.now().millisecondsSinceEpoch}-$safeName';

    await _client.storage.from(materialsBucket).upload(
          path,
          file,
          fileOptions: const FileOptions(upsert: false),
        );
    return path;
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
