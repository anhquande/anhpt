import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import '../models/workout_bucket.dart';

typedef BucketDownloadProgress = void Function(
  int receivedBytes,
  int? totalBytes,
);

class BucketRefreshResult {
  final WorkoutBucketCatalog catalog;
  final String rawJson;
  final bool fromCache;

  const BucketRefreshResult({
    required this.catalog,
    required this.rawJson,
    this.fromCache = false,
  });
}

class WorkoutBucketService {
  static const maxCatalogBytes = 2 * 1024 * 1024;
  static const maxPackageBytes = 100 * 1024 * 1024;
  final http.Client _client;

  WorkoutBucketService({http.Client? client})
      : _client = client ?? http.Client();

  Future<BucketRefreshResult> refresh(WorkoutBucketSource source) async {
    final uri = source.catalogUri;
    try {
      final bytes = await _download(
        uri,
        maxBytes: maxCatalogBytes,
        expectedBytes: null,
      );
      final raw = utf8.decode(bytes);
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        throw const FormatException('Bucket must be an object');
      }
      return BucketRefreshResult(
        catalog: WorkoutBucketCatalog.fromJson(
          Map<String, dynamic>.from(decoded),
        ),
        rawJson: raw,
      );
    } catch (_) {
      final cached = source.cachedCatalogJson;
      if (cached == null) rethrow;
      final decoded = jsonDecode(cached);
      if (decoded is! Map) rethrow;
      return BucketRefreshResult(
        catalog: WorkoutBucketCatalog.fromJson(
          Map<String, dynamic>.from(decoded),
        ),
        rawJson: cached,
        fromCache: true,
      );
    }
  }

  Future<Uint8List> downloadPackage(
    WorkoutBucketEntry entry, {
    BucketDownloadProgress? onProgress,
  }) async {
    if (entry.size != null && entry.size! > maxPackageBytes) {
      throw StateError('Workout package exceeds the 100 MB marketplace limit.');
    }
    final bytes = await _download(
      entry.packageUri,
      maxBytes: maxPackageBytes,
      expectedBytes: entry.size,
      onProgress: onProgress,
    );
    final actual = sha256.convert(bytes).toString();
    if (actual.toLowerCase() != entry.sha256.toLowerCase()) {
      throw StateError('Workout package checksum does not match the catalog.');
    }
    return bytes;
  }

  Future<Uint8List> _download(
    Uri uri, {
    required int maxBytes,
    required int? expectedBytes,
    BucketDownloadProgress? onProgress,
  }) async {
    requirePublicHttpsUri(uri.toString());
    final request = http.Request('GET', uri)
      ..followRedirects = true
      ..maxRedirects = 3;
    final response =
        await _client.send(request).timeout(const Duration(seconds: 20));
    final finalUri = response.request?.url ?? uri;
    requirePublicHttpsUri(finalUri.toString());
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('Download failed with HTTP ${response.statusCode}.');
    }
    final declared = response.contentLength;
    if (declared != null && declared > maxBytes) {
      throw StateError('Download exceeds the allowed size.');
    }
    if (expectedBytes != null &&
        declared != null &&
        declared != expectedBytes) {
      throw StateError('Download size does not match the catalog.');
    }
    final builder = BytesBuilder(copy: false);
    var total = 0;
    final progressTotal = expectedBytes ?? declared;
    onProgress?.call(0, progressTotal);
    await for (final chunk
        in response.stream.timeout(const Duration(seconds: 30))) {
      total += chunk.length;
      if (total > maxBytes) {
        throw StateError('Download exceeds the allowed size.');
      }
      builder.add(chunk);
      onProgress?.call(total, progressTotal);
    }
    if (expectedBytes != null && total != expectedBytes) {
      throw StateError('Download size does not match the catalog.');
    }
    return builder.takeBytes();
  }

  void dispose() => _client.close();
}
