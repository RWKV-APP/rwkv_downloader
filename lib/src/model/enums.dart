import 'dart:io';

enum ModelPlatform {
  macos,
  linux,
  android,
  windows,
  ios,
  web,
  unknown;

  static ModelPlatform get current {
    if (Platform.isMacOS) {
      return macos;
    } else if (Platform.isLinux) {
      return linux;
    } else if (Platform.isAndroid) {
      return android;
    } else if (Platform.isWindows) {
      return windows;
    } else if (Platform.isIOS) {
      return ios;
    } else {
      return unknown;
    }
  }

  static ModelPlatform fromString(String platform) {
    return ModelPlatform.values.where((e) => e.name == platform).firstOrNull ??
        ModelPlatform.unknown;
  }

  static List<ModelPlatform> fromJson(Iterable? json) {
    if (json == null) {
      return [];
    }
    return json.map((e) => fromString(e)).toList();
  }
}

class ModelBackend {
  final Set<String> aliases;
  final Set<ModelPlatform> platforms;
  final String name;
  final Set<String> extensions;

  const ModelBackend({
    this.aliases = const {},
    required this.platforms,
    required this.name,
    required this.extensions,
  });

  static final defaultBackends = [
    mnn,
    qnn,
    llama_cpp,
    albatross,
    mlx,
    web_rwkv,
    mtk_np7,
    albatross
  ];

  static const mnn = ModelBackend(
    platforms: {
      ModelPlatform.windows,
      ModelPlatform.android,
      ModelPlatform.ios,
      ModelPlatform.macos,
      ModelPlatform.linux,
    },
    name: 'mnn',
    extensions: {'mnn'},
  );

  static const unknown = ModelBackend(
    platforms: {...ModelPlatform.values},
    name: 'unknown',
    extensions: {},
  );

  static const qnn = ModelBackend(
    platforms: {ModelPlatform.android},
    name: 'qnn',
    extensions: {'rmpack'},
  );

  static const llama_cpp = ModelBackend(
    aliases: {'llama-cpp', 'llamacpp', 'llama_cpp', 'llama.cpp'},
    platforms: {
      ModelPlatform.windows,
      ModelPlatform.android,
      ModelPlatform.ios,
      ModelPlatform.macos,
      ModelPlatform.linux,
    },
    name: 'llama_cpp',
    extensions: {'gguf', 'ggml'},
  );

  static const albatross = ModelBackend(
    platforms: {ModelPlatform.windows, ModelPlatform.linux},
    name: 'albatross',
    extensions: {'pth'},
  );

  static const mlx = ModelBackend(
    platforms: {ModelPlatform.ios, ModelPlatform.macos},
    name: 'mlx',
    extensions: {'zip'},
  );

  static const web_rwkv = ModelBackend(
    aliases: {'webRwkv', 'web-rwkv'},
    platforms: {
      ModelPlatform.web,
      ModelPlatform.windows,
      ModelPlatform.macos,
      ModelPlatform.linux,
    },
    name: 'web_rwkv',
    extensions: {'prefab', 'st'},
  );

  static const mtk_np7 = ModelBackend(
    aliases: {'mtk-np7', 'mtk_np7'},
    platforms: {ModelPlatform.android},
    name: 'mtk_np7',
    extensions: {'np7'},
  );

  factory ModelBackend.fromString(String? backend) {
    if (backend == null) {
      return unknown;
    }
    for (final value in ModelBackend.defaultBackends) {
      if (value.name == backend || value.aliases.contains(backend)) {
        return value;
      }
    }
    return ModelBackend(
      platforms: {...ModelPlatform.values},
      name: backend,
      extensions: {},
    );
  }

  static List<ModelBackend> fromJson(Iterable? json) {
    if (json == null) {
      return [];
    }
    return json.map((e) => ModelBackend.fromString(e)).toList();
  }

  static ModelBackend? conjecture(String extension) {
    for (final value in ModelBackend.defaultBackends) {
      if (value.extensions.contains(extension)) {
        return value;
      }
    }
    return null;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ModelBackend &&
          runtimeType == other.runtimeType &&
          name == other.name;

  @override
  int get hashCode => name.hashCode;
}
