import 'package:rwkv_downloader/src/model/decode_param.dart';

import 'model_group.dart';
import 'model_info.dart';
import 'model_tag.dart';
import 'vocab_info.dart';

class ModelConfig {
  final int version;
  final int timestamp;
  final List<ModelTag> tags;
  final List<ModelInfo> models;
  final List<ModelGroup> groups;
  final List<VocabInfo> vocabList;
  final List<DecodeParamConfig> decodeParams;

  ModelConfig({
    required this.version,
    required this.timestamp,
    required this.models,
    required this.tags,
    required this.groups,
    required this.vocabList,
    required this.decodeParams,
  });

  factory ModelConfig.empty() {
    return ModelConfig(
      version: 1,
      timestamp: 0,
      models: [],
      tags: [],
      groups: [],
      vocabList: [],
      decodeParams: [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'version': this.version,
      'timestamp': this.timestamp,
      'tags': this.tags.map((e) => e.toMapNonZero()).toList(),
      'groups': this.groups.map((e) => e.toMapNonZero()).toList(),
      'models': this.models.map((e) => e.toMapNonZero()).toList(),
      'vocabList': this.vocabList.map((e) => e.toMapNonZero()).toList(),
      'decodeParams': this.decodeParams.map((e) => e.toMapNonZero()).toList(),
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
      vocabList:
          (map['vocabList'] as Iterable?)
              ?.map((e) => VocabInfo.fromMap(e))
              .toList() ??
          [],
      decodeParams: (map['decodeParams'] as Iterable)
          .map((e) => DecodeParamConfig.fromMap(e))
          .toList(),
    );
  }

  ModelConfig copyWith({
    int? version,
    int? timestamp,
    List<ModelTag>? tags,
    List<ModelInfo>? models,
    List<ModelGroup>? groups,
    List<VocabInfo>? vocabList,
    List<DecodeParamConfig>? decodeParams,
  }) {
    return ModelConfig(
      version: version ?? this.version,
      timestamp: timestamp ?? this.timestamp,
      tags: tags ?? this.tags,
      models: models ?? this.models,
      groups: groups ?? this.groups,
      vocabList: vocabList ?? this.vocabList,
      decodeParams: decodeParams ?? this.decodeParams,
    );
  }
}
