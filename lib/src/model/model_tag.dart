import 'package:rwkv_downloader/src/model/enums.dart';

class ModelTag {
  final String name;
  final String desc;
  final String color;
  final List<ModelPlatform> unsupported;

  ModelTag({
    required this.name,
    required this.desc,
    required this.color,
    this.unsupported = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'desc': desc,
      'color': color,
      'unsupported': unsupported.map((e) => e.name).toList(),
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

  factory ModelTag.fromMap(dynamic map) {
    return ModelTag(
      name: map['name'] as String,
      desc: map['desc'] ?? '',
      color: map['color'] ?? '',
      unsupported: (map['unsupported'] as Iterable? ?? [])
          .map((e) => ModelPlatform.fromString(e))
          .toList(),
    );
  }

  ModelTag copyWith({
    int? id,
    String? name,
    String? desc,
    String? color,
    List<ModelPlatform>? unsupported,
  }) {
    return ModelTag(
      name: name ?? this.name,
      desc: desc ?? this.desc,
      color: color ?? this.color,
      unsupported: unsupported ?? this.unsupported,
    );
  }
}
