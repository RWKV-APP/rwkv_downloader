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

enum ModelBackend {
  mnn(
    platforms: {
      ModelPlatform.windows,
      ModelPlatform.android,
      ModelPlatform.ios,
      ModelPlatform.macos,
      ModelPlatform.linux,
    },
  ),
  qnn(platforms: {ModelPlatform.android}),
  llama_cpp(
    aliases: {'llama-cpp', 'llamacpp'},
    platforms: {
      ModelPlatform.windows,
      ModelPlatform.android,
      ModelPlatform.ios,
      ModelPlatform.macos,
      ModelPlatform.linux,
    },
  ),
  albatross(platforms: {ModelPlatform.windows, ModelPlatform.linux}),
  mlx(platforms: {ModelPlatform.ios, ModelPlatform.macos}),
  web_rwkv(
    aliases: {'webRwkv', 'web-rwkv'},
    platforms: {
      ModelPlatform.web,
      ModelPlatform.windows,
      ModelPlatform.macos,
      ModelPlatform.linux,
    },
  ),
  unknown(platforms: {...ModelPlatform.values});

  final Set<String> aliases;
  final Set<ModelPlatform> platforms;

  const ModelBackend({this.aliases = const {}, this.platforms = const {}});

  static ModelBackend fromString(String? backend) {
    if (backend == null) {
      return unknown;
    }
    for (final value in ModelBackend.values) {
      if (value.name == backend || value.aliases.contains(backend)) {
        return value;
      }
    }
    return unknown;
  }

  static ModelBackend? conjecture(String extension) {
    switch (extension) {
      case 'rmpack':
        return qnn;
      case 'gguf':
      case 'ggml':
        return llama_cpp;
      case 'pth':
        return albatross;
      case 'zip':
        return mlx;
      case 'prefab':
      case 'st':
        return web_rwkv;
      default:
        return null;
    }
  }

  static List<ModelBackend> fromJson(Iterable? json) {
    if (json == null) {
      return [];
    }
    return json.map((e) => fromString(e)).toList();
  }
}
