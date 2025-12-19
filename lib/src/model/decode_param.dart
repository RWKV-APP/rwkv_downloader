class DecodeParamConfig {
  final String id;
  final String name;
  final String backend;
  final num temperature;
  final num topK;
  final num topP;
  final num minP;
  final num repeatPenalty;
  final num penaltyAlpha;
  final num penaltyDecay;
  final num maxLength;

  DecodeParamConfig({
    required this.id,
    required this.name,
    required this.backend,
    required this.temperature,
    required this.topK,
    required this.topP,
    required this.minP,
    required this.repeatPenalty,
    required this.penaltyAlpha,
    required this.penaltyDecay,
    required this.maxLength,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'backend': backend,
      'temperature': temperature,
      'topK': topK,
      'topP': topP,
      'minP': minP,
      'repeatPenalty': repeatPenalty,
      'penaltyAlpha': penaltyAlpha,
      'penaltyDecay': penaltyDecay,
      'maxLength': maxLength,
    };
  }

  factory DecodeParamConfig.fromMap(Map<String, dynamic> map) {
    return DecodeParamConfig(
      id: map['id'] as String,
      name: map['name'] as String,
      temperature: map['temperature'] as num,
      backend: map['backend'] ?? '',
      topK: map['topK'] ?? -1,
      topP: map['topP'] ?? -1,
      minP: map['minP'] ?? -1,
      repeatPenalty: map['repeatPenalty'] ?? -1,
      penaltyAlpha: map['penaltyAlpha'] ?? -1,
      penaltyDecay: map['penaltyDecay'] ?? -1,
      maxLength: map['maxLength'] ?? -1,
    );
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

  DecodeParamConfig copyWith({
    String? id,
    String? name,
    String? backend,
    num? temperature,
    num? topK,
    num? topP,
    num? minP,
    num? repeatPenalty,
    num? penaltyAlpha,
    num? penaltyDecay,
    num? maxLength,
  }) {
    return DecodeParamConfig(
      id: id ?? this.id,
      name: name ?? this.name,
      backend: backend ?? this.backend,
      temperature: temperature ?? this.temperature,
      topK: topK ?? this.topK,
      topP: topP ?? this.topP,
      minP: minP ?? this.minP,
      repeatPenalty: repeatPenalty ?? this.repeatPenalty,
      penaltyAlpha: penaltyAlpha ?? this.penaltyAlpha,
      penaltyDecay: penaltyDecay ?? this.penaltyDecay,
      maxLength: maxLength ?? this.maxLength,
    );
  }
}
