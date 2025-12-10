class ModelTag {
  final String name;
  final String desc;
  final String color;

  ModelTag({required this.name, required this.desc, required this.color});

  Map<String, dynamic> toMap() {
    return {'name': name, 'desc': desc, 'color': color};
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
    );
  }

  ModelTag copyWith({int? id, String? name, String? desc, String? color}) {
    return ModelTag(
      name: name ?? this.name,
      desc: desc ?? this.desc,
      color: color ?? this.color,
    );
  }
}
