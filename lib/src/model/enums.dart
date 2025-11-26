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
  mnn,
  qnn,
  llama_cpp(aliases: {'llama-cpp', 'llamacpp'}),
  albatross,
  mlx,
  web_rwkv(aliases: {'webRwkv', 'web-rwkv'}),
  unknown;

  final Set<String> aliases;

  const ModelBackend({this.aliases = const {}});

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

  static List<ModelBackend> fromJson(Iterable? json) {
    if (json == null) {
      return [];
    }
    return json.map((e) => fromString(e)).toList();
  }
}
