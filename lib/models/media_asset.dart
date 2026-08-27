class MediaAsset {
  final String id;
  final String type;
  final String mimeType;
  final String fileName;
  final String relativePath;
  final int sizeBytes;
  final DateTime createdAt;

  const MediaAsset({
    required this.id,
    required this.type,
    required this.mimeType,
    required this.fileName,
    required this.relativePath,
    required this.sizeBytes,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'mimeType': mimeType,
        'fileName': fileName,
        'relativePath': relativePath,
        'sizeBytes': sizeBytes,
        'createdAt': createdAt.toIso8601String(),
      };

  factory MediaAsset.fromJson(Map<String, dynamic> json) => MediaAsset(
        id: json['id'] as String,
        type: json['type'] as String,
        mimeType: json['mimeType'] as String,
        fileName: json['fileName'] as String,
        relativePath: json['relativePath'] as String,
        sizeBytes: json['sizeBytes'] as int,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}
