import 'enums.dart';

class ModelInfo {
  final String id;
  final String name;
  final num modelSize;
  final num fileSize;
  final String url;
  final String md5;
  final String sha256;
  final String quantization;
  final List<ModelPlatform> platforms;
  final ModelBackend backend;
  final List<String> tags;
  final List<String> groups;
  final List<String> socLimitations;
  final bool isDebug;
  final int updatedAt;
  final String description;

  final String localPath;

  String get fileName =>
      url.split('/').lastOrNull?.split('?').firstOrNull ?? '';

  ModelInfo({
    required this.id,
    required this.name,
    required this.modelSize,
    required this.url,
    required this.sha256,
    required this.md5,
    required this.fileSize,
    required this.quantization,
    required this.platforms,
    required this.backend,
    required this.tags,
    required this.groups,
    required this.socLimitations,
    required this.isDebug,
    required this.updatedAt,
    required this.description,
    this.localPath = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'modelSize': modelSize,
      'url': url,
      'md5': md5,
      'sha256': sha256,
      'fileSize': fileSize,
      'quantization': quantization,
      'platforms': platforms.map((e) => e.name).toList(),
      'backend': backend.name,
      'tags': tags,
      'groups': groups,
      'socLimitations': socLimitations,
      'isDebug': isDebug,
      'updatedAt': updatedAt,
      'description': description,
    };
  }

  Map<String, dynamic> toMapNonZero() {
    final map = toMap();
    map.removeWhere(
      (key, value) =>
          value == null ||
          value == '' ||
          value == 0 ||
          value == false ||
          (value is Iterable && value.isEmpty),
    );
    return map;
  }

  factory ModelInfo.fromMap(dynamic map) {
    return ModelInfo(
      id: map['id'] as String,
      name: map['name'] as String,
      url: map['url'] as String,
      modelSize: map['modelSize'] ?? -1,
      fileSize: map['fileSize'] ?? -1,
      quantization: map['quantization'] ?? '',
      platforms: ModelPlatform.fromJson(map['platforms']),
      backend: ModelBackend.fromString(map['backend']),
      tags: List<String>.from(map['tags'] ?? []),
      groups: List<String>.from(map['groups'] ?? []),
      socLimitations: List<String>.from(map['socLimitations'] ?? []),
      isDebug: map['isDebug'] ?? false,
      sha256: map['sha256'] ?? '',
      md5: map['md5'] ?? '',
      updatedAt: map['updatedAt'] ?? 0,
      description: map['description'] ?? '',
    );
  }

  ModelInfo copyWith({
    String? id,
    String? name,
    num? modelSize,
    String? url,
    num? fileSize,
    String? md5,
    String? sha256,
    String? quantization,
    List<ModelPlatform>? platforms,
    ModelBackend? backend,
    List<String>? tags,
    List<String>? groups,
    List<String>? socLimitations,
    bool? isDebug,
    String? localPath,
    int? updatedAt,
    String? description,
  }) {
    return ModelInfo(
      id: id ?? this.id,
      name: name ?? this.name,
      modelSize: modelSize ?? this.modelSize,
      url: url ?? this.url,
      fileSize: fileSize ?? this.fileSize,
      md5: md5 ?? this.md5,
      sha256: sha256 ?? this.sha256,
      quantization: quantization ?? this.quantization,
      platforms: platforms ?? this.platforms,
      backend: backend ?? this.backend,
      tags: tags ?? this.tags,
      groups: groups ?? this.groups,
      socLimitations: socLimitations ?? this.socLimitations,
      isDebug: isDebug ?? this.isDebug,
      localPath: localPath ?? this.localPath,
      updatedAt: updatedAt ?? this.updatedAt,
      description: description ?? this.description,
    );
  }
}
