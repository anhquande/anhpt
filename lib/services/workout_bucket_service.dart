import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import '../models/workout_bucket.dart';

typedef BucketDownloadProgress =
    void Function(int receivedBytes, int? totalBytes);

class BucketPackageProgressEvent {
  final String entryId;
  final String artifact;
  final int receivedBytes;
  final int? totalBytes;

  const BucketPackageProgressEvent({
    required this.entryId,
    required this.artifact,
    required this.receivedBytes,
    required this.totalBytes,
  });
}

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
  static const maxThumbnailBytes = 2 * 1024 * 1024;
  static const maxFeatureImageBytes = 8 * 1024 * 1024;
  static final _packageProgressController =
      StreamController<BucketPackageProgressEvent>.broadcast();

  static Stream<BucketPackageProgressEvent> get packageProgress =>
      _packageProgressController.stream;

  final http.Client _client;
  final Map<String, Future<Uint8List>> _artworkDownloads = {};

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

  Future<Uint8List> downloadWorkout(
    WorkoutBucketEntry entry, {
    BucketDownloadProgress? onProgress,
  }) async {
    return _downloadEntryArtifact(
      entry,
      artifact: 'workout',
      uri: entry.workoutUri,
      expectedSha256: entry.workoutSha256,
      expectedBytes: entry.workoutSize,
      maxBytes: maxCatalogBytes,
      onProgress: onProgress,
    );
  }

  Future<Uint8List> downloadAssets(
    WorkoutBucketEntry entry, {
    BucketDownloadProgress? onProgress,
  }) async {
    return _downloadEntryArtifact(
      entry,
      artifact: 'assets',
      uri: entry.assetsUri,
      expectedSha256: entry.assetsSha256,
      expectedBytes: entry.assetsSize,
      maxBytes: maxPackageBytes,
      onProgress: onProgress,
    );
  }

  Future<Uint8List?> downloadThumbnail(WorkoutBucketEntry entry) {
    final uri = entry.thumbnailUri;
    final checksum = entry.thumbnailSha256;
    final size = entry.thumbnailSize;
    if (uri == null || checksum == null || size == null) return Future.value();
    return _cachedArtwork(
      uri: uri,
      expectedSha256: checksum,
      expectedBytes: size,
      maxBytes: maxThumbnailBytes,
    );
  }

  Future<Uint8List?> downloadFeatureImage(WorkoutBucketEntry entry) {
    final uri = entry.featureImageUri;
    final checksum = entry.featureImageSha256;
    final size = entry.featureImageSize;
    if (uri == null || checksum == null || size == null) return Future.value();
    return _cachedArtwork(
      uri: uri,
      expectedSha256: checksum,
      expectedBytes: size,
      maxBytes: maxFeatureImageBytes,
    );
  }

  Future<Uint8List> _cachedArtwork({
    required Uri uri,
    required String expectedSha256,
    required int expectedBytes,
    required int maxBytes,
  }) {
    final key = '$uri#$expectedSha256';
    return _artworkDownloads.putIfAbsent(key, () async {
      final bytes = await _download(
        uri,
        maxBytes: maxBytes,
        expectedBytes: expectedBytes,
      );
      final actual = sha256.convert(bytes).toString();
      if (actual.toLowerCase() != expectedSha256.toLowerCase()) {
        throw StateError('Artwork checksum does not match the catalog.');
      }
      return bytes;
    });
  }

  Future<Uint8List> _downloadEntryArtifact(
    WorkoutBucketEntry entry, {
    required String artifact,
    required Uri uri,
    required String expectedSha256,
    required int expectedBytes,
    required int maxBytes,
    BucketDownloadProgress? onProgress,
  }) async {
    if (expectedBytes > maxBytes) {
      throw StateError('$artifact exceeds the marketplace size limit.');
    }

    void report(int received, int? total) {
      onProgress?.call(received, total);
      _packageProgressController.add(
        BucketPackageProgressEvent(
          entryId: entry.id,
          artifact: artifact,
          receivedBytes: received,
          totalBytes: total,
        ),
      );
    }

    final bytes = await _download(
      uri,
      maxBytes: maxBytes,
      expectedBytes: expectedBytes,
      onProgress: report,
    );
    final actual = sha256.convert(bytes).toString();
    if (actual.toLowerCase() != expectedSha256.toLowerCase()) {
      throw StateError('$artifact checksum does not match the catalog.');
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
    final response = await _client
        .send(request)
        .timeout(const Duration(seconds: 20));
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
    await for (final chunk in response.stream.timeout(
      const Duration(seconds: 30),
    )) {
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
