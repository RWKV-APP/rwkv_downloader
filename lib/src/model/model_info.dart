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
  final ModelBackend backend;
  final List<String> tags;
  final List<String> groups;
  final List<String> decodeParams;
  final bool isDebug;
  final int updatedAt;
  final String description;
  final int contextLength;
  final String vocabUrl;
  final String vocabId;

  final String localPath;

  String get fileName =>
      url.split('/').lastOrNull?.split('?').firstOrNull ?? '';

  ModelInfo({
    required this.id,
    required this.name,
    required this.modelSize,
    required this.url,
    required this.vocabUrl,
    required this.vocabId,
    required this.decodeParams,
    required this.sha256,
    required this.md5,
    required this.fileSize,
    required this.quantization,
    required this.backend,
    required this.tags,
    required this.groups,
    required this.isDebug,
    required this.updatedAt,
    required this.description,
    this.contextLength = -1,
    this.localPath = '',
  });

  ModelInfo.base({
    required this.id,
    required this.name,
    required this.url,
    this.modelSize = -1,
    this.vocabUrl = '',
    this.vocabId = '',
    this.decodeParams = const [],
    this.sha256 = '',
    this.md5 = '',
    this.fileSize = -1,
    this.quantization = '',
    this.backend = ModelBackend.unknown,
    this.tags = const [],
    this.groups = const [],
    this.isDebug = false,
    this.updatedAt = -1,
    this.description = '',
    this.localPath = '',
    this.contextLength = -1,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'modelSize': modelSize,
      'url': url,
      'vocabUrl': vocabUrl,
      'vocabId': vocabId,
      'decodeParams': decodeParams,
      'md5': md5,
      'sha256': sha256,
      'fileSize': fileSize,
      'quantization': quantization,
      'backend': backend.name,
      'tags': tags,
      'groups': groups,
      'isDebug': isDebug,
      'updatedAt': updatedAt,
      'description': description,
      'contextLength': contextLength,
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
      vocabUrl: map['vocabUrl'] ?? '',
      vocabId: map['vocabId'] ?? '',
      modelSize: map['modelSize'] ?? -1,
      fileSize: map['fileSize'] ?? -1,
      quantization: map['quantization'] ?? '',
      backend: ModelBackend.fromString(map['backend']),
      tags: List<String>.from(map['tags'] ?? []),
      groups: List<String>.from(map['groups'] ?? []),
      decodeParams: List<String>.from(map['decodeParams'] ?? []),
      isDebug: map['isDebug'] ?? false,
      sha256: map['sha256'] ?? '',
      md5: map['md5'] ?? '',
      updatedAt: map['updatedAt'] ?? 0,
      description: map['description'] ?? '',
      contextLength: map['contextLength'] ?? -1,
    );
  }

  ModelInfo copyWith({
    String? id,
    String? name,
    num? modelSize,
    String? url,
    String? vocabUrl,
    String? vocabId,
    List<String>? decodeParams,
    num? fileSize,
    String? md5,
    String? sha256,
    String? quantization,
    ModelBackend? backend,
    List<String>? tags,
    List<String>? groups,
    bool? isDebug,
    String? localPath,
    int? updatedAt,
    String? description,
    int? contextLength,
  }) {
    return ModelInfo(
      id: id ?? this.id,
      name: name ?? this.name,
      modelSize: modelSize ?? this.modelSize,
      url: url ?? this.url,
      vocabUrl: vocabUrl ?? this.vocabUrl,
      vocabId: vocabId ?? this.vocabId,
      decodeParams: decodeParams ?? this.decodeParams,
      fileSize: fileSize ?? this.fileSize,
      md5: md5 ?? this.md5,
      sha256: sha256 ?? this.sha256,
      quantization: quantization ?? this.quantization,
      backend: backend ?? this.backend,
      tags: tags ?? this.tags,
      groups: groups ?? this.groups,
      isDebug: isDebug ?? this.isDebug,
      localPath: localPath ?? this.localPath,
      updatedAt: updatedAt ?? this.updatedAt,
      description: description ?? this.description,
      contextLength: contextLength ?? this.contextLength,
    );
  }
}
