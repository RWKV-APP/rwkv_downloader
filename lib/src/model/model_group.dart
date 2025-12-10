import 'enums.dart';

class ModelGroup {
  final String name;
  final String desc;
  final List<ModelBackend> backends;
  final List<ModelPlatform> platforms;
  final List<int> tags;

  ModelGroup({
    required this.name,
    required this.desc,
    required this.backends,
    required this.platforms,
    required this.tags,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': this.name,
      'desc': this.desc,
      'backends': this.backends.map((e) => e.name).toList(),
      'platforms': this.platforms.map((e) => e.name).toList(),
      'tags': this.tags,
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

  factory ModelGroup.fromMap(Map<String, dynamic> map) {
    return ModelGroup(
      name: map['name'] as String,
      desc: map['desc'] ?? '',
      backends: ModelBackend.fromJson(map['backends'] ?? []),
      platforms: ModelPlatform.fromJson(map['platforms'] ?? []),
      tags: List<int>.from(map['tags'] ?? []),
    );
  }
}
