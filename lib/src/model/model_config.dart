import 'model_group.dart';
import 'model_info.dart';
import 'model_tag.dart';

class ModelConfig {
  final int version;
  final int timestamp;
  final List<ModelTag> tags;
  final List<ModelInfo> models;
  final List<ModelGroup> groups;

  ModelConfig({
    required this.version,
    required this.timestamp,
    required this.models,
    required this.tags,
    required this.groups,
  });

  factory ModelConfig.empty() {
    return ModelConfig(
      version: 1,
      timestamp: 0,
      models: [],
      tags: [],
      groups: [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'version': this.version,
      'timestamp': this.timestamp,
      'tags': this.tags.map((e) => e.toMapNonZero()).toList(),
      'groups': this.groups.map((e) => e.toMapNonZero()).toList(),
      'models': this.models.map((e) => e.toMapNonZero()).toList(),
    };
  }

  factory ModelConfig.fromMap(Map<String, dynamic> map) {
    return ModelConfig(
      version: map['version'] as int,
      timestamp: map['timestamp'] as int,
      models: (map['models'] as Iterable)
          .map((e) => ModelInfo.fromMap(e))
          .toList(),
      tags:
          (map['tags'] as Iterable?)
              ?.map((e) => ModelTag.fromMap(e))
              .toList() ??
          [],
      groups:
          (map['groups'] as Iterable?)
              ?.map((e) => ModelGroup.fromMap(e))
              .toList() ??
          [],
    );
  }
}
