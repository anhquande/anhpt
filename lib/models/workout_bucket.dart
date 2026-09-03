class WorkoutBucketSource {
  final String id;
  final String name;
  final String catalogUrl;
  final bool enabled;
  final DateTime? lastRefreshedAt;
  final String? lastError;
  final String? cachedCatalogJson;

  const WorkoutBucketSource({
    required this.id,
    required this.name,
    required this.catalogUrl,
    this.enabled = true,
    this.lastRefreshedAt,
    this.lastError,
    this.cachedCatalogJson,
  });

  Uri get catalogUri => requirePublicHttpsUri(catalogUrl, field: 'catalogUrl');

  WorkoutBucketSource copyWith({
    String? name,
    String? catalogUrl,
    bool? enabled,
    DateTime? lastRefreshedAt,
    bool clearLastRefreshedAt = false,
    String? lastError,
    bool clearLastError = false,
    String? cachedCatalogJson,
    bool clearCachedCatalogJson = false,
  }) => WorkoutBucketSource(
    id: id,
    name: name ?? this.name,
    catalogUrl: catalogUrl ?? this.catalogUrl,
    enabled: enabled ?? this.enabled,
    lastRefreshedAt: clearLastRefreshedAt
        ? null
        : lastRefreshedAt ?? this.lastRefreshedAt,
    lastError: clearLastError ? null : lastError ?? this.lastError,
    cachedCatalogJson: clearCachedCatalogJson
        ? null
        : cachedCatalogJson ?? this.cachedCatalogJson,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'catalogUrl': catalogUrl,
    'enabled': enabled,
    'lastRefreshedAt': lastRefreshedAt?.toIso8601String(),
    'lastError': lastError,
    'cachedCatalogJson': cachedCatalogJson,
  };

  static WorkoutBucketSource fromJson(Map<String, dynamic> json) {
    final id = _requiredString(json, 'id');
    final name = _requiredString(json, 'name');
    final catalogUrl = _requiredString(json, 'catalogUrl');
    requirePublicHttpsUri(catalogUrl, field: 'catalogUrl');
    return WorkoutBucketSource(
      id: id,
      name: name,
      catalogUrl: catalogUrl,
      enabled: _optionalBool(json, 'enabled') ?? true,
      lastRefreshedAt: _optionalDateTime(json, 'lastRefreshedAt'),
      lastError: _optionalString(json, 'lastError'),
      cachedCatalogJson: _optionalString(json, 'cachedCatalogJson'),
    );
  }
}

class WorkoutBucketCatalog {
  final int schemaVersion;
  final String name;
  final String? description;
  final List<WorkoutBucketEntry> entries;

  const WorkoutBucketCatalog({
    required this.schemaVersion,
    required this.name,
    this.description,
    required this.entries,
  });

  Map<String, dynamic> toJson() => {
    'schemaVersion': schemaVersion,
    'name': name,
    if (description != null) 'description': description,
    'workouts': entries.map((entry) => entry.toJson()).toList(),
  };

  static WorkoutBucketCatalog fromJson(Map<String, dynamic> json) {
    final schemaVersion = _requiredIntAlias(json, ['schemaVersion', 'version']);
    if (schemaVersion != 2) {
      throw FormatException(
        'Unsupported bucket schema version: $schemaVersion',
      );
    }
    final rawEntries = json['workouts'] ?? json['entries'];
    if (rawEntries is! List) {
      throw const FormatException('workouts must be a list');
    }
    final entries = rawEntries
        .map((value) {
          if (value is! Map) {
            throw const FormatException('Each workout must be an object');
          }
          return WorkoutBucketEntry.fromJson(Map<String, dynamic>.from(value));
        })
        .toList(growable: false);
    final ids = <String>{};
    for (final entry in entries) {
      if (!ids.add(entry.id)) {
        throw FormatException('Duplicate workout id: ${entry.id}');
      }
    }
    return WorkoutBucketCatalog(
      schemaVersion: schemaVersion,
      name: _requiredString(json, 'name'),
      description: _optionalString(json, 'description'),
      entries: entries,
    );
  }
}

enum BucketInstallConflictResolution { keepLocal, installCopy, replace }

String uniqueLocalWorkoutName(String desiredName, Iterable<String> existing) {
  final base = desiredName.trim();
  final used = existing.map((name) => name.trim().toLowerCase()).toSet();
  if (!used.contains(base.toLowerCase())) return base;
  var suffix = 2;
  while (used.contains('$base $suffix'.toLowerCase())) {
    suffix++;
  }
  return '$base $suffix';
}

class WorkoutBucketEntry {
  final String? sourceId;
  final String id;
  final String name;
  final String description;
  final String version;
  final String workoutUrl;
  final String workoutSha256;
  final int workoutSize;
  final String assetsUrl;
  final String assetsSha256;
  final int assetsSize;
  final List<String> tags;
  final String? author;
  final String? minAppVersion;

  const WorkoutBucketEntry({
    this.sourceId,
    required this.id,
    required this.name,
    this.description = '',
    required this.version,
    required this.workoutUrl,
    required this.workoutSha256,
    required this.workoutSize,
    this.assetsUrl = 'https://example.com/assets.zip',
    this.assetsSha256 =
        '0000000000000000000000000000000000000000000000000000000000000000',
    this.assetsSize = 1,
    this.tags = const [],
    this.author,
    this.minAppVersion,
  });

  Uri get workoutUri => requirePublicHttpsUri(workoutUrl, field: 'workoutUrl');
  Uri get assetsUri => requirePublicHttpsUri(assetsUrl, field: 'assetsUrl');
  int get totalSize => workoutSize + assetsSize;

  WorkoutBucketEntry copyWithSource(String sourceId) => WorkoutBucketEntry(
    sourceId: sourceId,
    id: id,
    name: name,
    description: description,
    version: version,
    workoutUrl: workoutUrl,
    workoutSha256: workoutSha256,
    workoutSize: workoutSize,
    assetsUrl: assetsUrl,
    assetsSha256: assetsSha256,
    assetsSize: assetsSize,
    tags: tags,
    author: author,
    minAppVersion: minAppVersion,
  );

  Map<String, dynamic> toJson() => {
    if (sourceId != null) 'sourceId': sourceId,
    'id': id,
    'name': name,
    'description': description,
    'version': version,
    'workoutUrl': workoutUrl,
    'workoutSha256': workoutSha256,
    'workoutSize': workoutSize,
    'assetsUrl': assetsUrl,
    'assetsSha256': assetsSha256,
    'assetsSize': assetsSize,
    'tags': tags,
    if (author != null) 'author': author,
    if (minAppVersion != null) 'minAppVersion': minAppVersion,
  };

  static WorkoutBucketEntry fromJson(Map<String, dynamic> json) {
    final workoutUrl = _requiredString(json, 'workoutUrl');
    final assetsUrl = _requiredString(json, 'assetsUrl');
    requirePublicHttpsUri(workoutUrl, field: 'workoutUrl');
    requirePublicHttpsUri(assetsUrl, field: 'assetsUrl');
    final workoutSha256 = _requiredString(json, 'workoutSha256').toLowerCase();
    final assetsSha256 = _requiredString(json, 'assetsSha256').toLowerCase();
    if (!isSha256Hex(workoutSha256) || !isSha256Hex(assetsSha256)) {
      throw const FormatException(
        'workoutSha256 and assetsSha256 must be 64 hexadecimal characters',
      );
    }
    final rawTags = json['tags'];
    if (rawTags != null && rawTags is! List) {
      throw const FormatException('tags must be a list');
    }
    final tags = (rawTags as List? ?? const [])
        .map((tag) {
          if (tag is! String || tag.trim().isEmpty) {
            throw const FormatException('Each tag must be a non-empty string');
          }
          return tag.trim();
        })
        .toList(growable: false);
    final workoutSize = json['workoutSize'];
    final assetsSize = json['assetsSize'];
    if (workoutSize is! int ||
        workoutSize <= 0 ||
        assetsSize is! int ||
        assetsSize <= 0) {
      throw const FormatException(
        'workoutSize and assetsSize must be positive integers',
      );
    }
    return WorkoutBucketEntry(
      sourceId: _optionalString(json, 'sourceId'),
      id: _requiredString(json, 'id'),
      name: _requiredString(json, 'name'),
      description: _optionalString(json, 'description') ?? '',
      version: _requiredString(json, 'version'),
      workoutUrl: workoutUrl,
      workoutSha256: workoutSha256,
      workoutSize: workoutSize,
      assetsUrl: assetsUrl,
      assetsSha256: assetsSha256,
      assetsSize: assetsSize,
      tags: tags,
      author: _optionalString(json, 'author'),
      minAppVersion: _optionalString(json, 'minAppVersion'),
    );
  }
}

class InstalledWorkoutProvenance {
  final String workoutId;
  final String sourceId;
  final String? sourceName;
  final String entryId;
  final String? originalName;
  final String version;
  final String packageUrl;
  final String sha256;
  final DateTime installedAt;

  const InstalledWorkoutProvenance({
    required this.workoutId,
    required this.sourceId,
    this.sourceName,
    required this.entryId,
    this.originalName,
    required this.version,
    required this.packageUrl,
    required this.sha256,
    required this.installedAt,
  });

  Map<String, dynamic> toJson() => {
    'workoutId': workoutId,
    'sourceId': sourceId,
    if (sourceName != null) 'sourceName': sourceName,
    'entryId': entryId,
    if (originalName != null) 'originalName': originalName,
    'version': version,
    'packageUrl': packageUrl,
    'sha256': sha256,
    'installedAt': installedAt.toIso8601String(),
  };

  static InstalledWorkoutProvenance fromJson(Map<String, dynamic> json) {
    final packageUrl = _requiredString(json, 'packageUrl');
    requirePublicHttpsUri(packageUrl, field: 'packageUrl');
    final sha256 = _requiredString(json, 'sha256').toLowerCase();
    if (!isSha256Hex(sha256)) {
      throw const FormatException('sha256 must be 64 hexadecimal characters');
    }
    return InstalledWorkoutProvenance(
      workoutId: _requiredString(json, 'workoutId'),
      sourceId: _requiredString(json, 'sourceId'),
      sourceName: _optionalString(json, 'sourceName'),
      entryId: _requiredString(json, 'entryId'),
      originalName: _optionalString(json, 'originalName'),
      version: _requiredString(json, 'version'),
      packageUrl: packageUrl,
      sha256: sha256,
      installedAt: _requiredDateTime(json, 'installedAt'),
    );
  }
}

bool isSha256Hex(String value) => RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(value);

Uri requirePublicHttpsUri(String value, {String field = 'url'}) {
  final uri = Uri.tryParse(value);
  if (uri == null ||
      uri.scheme.toLowerCase() != 'https' ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      uri.fragment.isNotEmpty ||
      _isLocalHost(uri.host)) {
    throw FormatException('$field must be a public HTTPS URL');
  }
  return uri;
}

bool _isLocalHost(String host) {
  final normalized = host.toLowerCase();
  if (normalized == 'localhost' ||
      normalized.endsWith('.localhost') ||
      normalized.endsWith('.local')) {
    return true;
  }
  final parts = normalized.split('.');
  if (parts.length == 4 && parts.every((part) => int.tryParse(part) != null)) {
    final octets = parts.map(int.parse).toList();
    return octets[0] == 10 ||
        octets[0] == 127 ||
        (octets[0] == 169 && octets[1] == 254) ||
        (octets[0] == 172 && octets[1] >= 16 && octets[1] <= 31) ||
        (octets[0] == 192 && octets[1] == 168) ||
        octets[0] == 0;
  }
  if (!normalized.contains(':')) return false;
  return normalized == '::1' ||
      normalized.startsWith('fc') ||
      normalized.startsWith('fd') ||
      normalized.startsWith('fe8') ||
      normalized.startsWith('fe9') ||
      normalized.startsWith('fea') ||
      normalized.startsWith('feb');
}

String _requiredString(Map<String, dynamic> json, String key) =>
    _requiredStringAlias(json, [key]);

String _requiredStringAlias(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value is String && value.trim().isNotEmpty) return value.trim();
  }
  throw FormatException('${keys.first} must be a non-empty string');
}

String? _optionalString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is! String) throw FormatException('$key must be a string');
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

bool? _optionalBool(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is! bool) throw FormatException('$key must be a boolean');
  return value;
}

int _requiredIntAlias(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value is int) return value;
  }
  throw FormatException('${keys.first} must be an integer');
}

DateTime _requiredDateTime(Map<String, dynamic> json, String key) {
  final value = _requiredString(json, key);
  final parsed = DateTime.tryParse(value);
  if (parsed == null) throw FormatException('$key must be an ISO-8601 date');
  return parsed;
}

DateTime? _optionalDateTime(Map<String, dynamic> json, String key) {
  final value = _optionalString(json, key);
  if (value == null) return null;
  final parsed = DateTime.tryParse(value);
  if (parsed == null) throw FormatException('$key must be an ISO-8601 date');
  return parsed;
}
