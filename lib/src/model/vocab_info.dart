class VocabInfo {
  final String id;
  final int size;
  final String url;
  final String specialTokens;
  final int eos;
  final int bos;

  VocabInfo({
    required this.id,
    required this.size,
    required this.url,
    required this.specialTokens,
    required this.eos,
    required this.bos,
  });

  factory VocabInfo.fromMap(Map<String, dynamic> map) {
    return VocabInfo(
      id: map['id'] as String,
      url: map['url'] as String,
      size: map['size'] ?? -1,
      specialTokens: map['specialTokens'] ?? '',
      eos: map['eos'] ?? -1,
      bos: map['bos'] ?? -1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': this.id,
      'size': this.size,
      'url': this.url,
      'specialTokens': this.specialTokens,
      'eos': this.eos,
      'bos': this.bos,
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

  VocabInfo copyWith({
    String? id,
    int? size,
    String? url,
    String? specialTokens,
    int? eos,
    int? bos,
  }) {
    return VocabInfo(
      id: id ?? this.id,
      size: size ?? this.size,
      url: url ?? this.url,
      specialTokens: specialTokens ?? this.specialTokens,
      eos: eos ?? this.eos,
      bos: bos ?? this.bos,
    );
  }
}
