import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:rwkv_downloader/src/model/model.dart';

Future serve() async {
  final pwd = Directory.current.path;
  await Process.run('python', [
    '-m',
    'http.server',
    '8081',
  ], workingDirectory: '${pwd}\\example');
}

void main() async {

  final src = File('./example/latest.json');
  final dst = File('./example/model_config.json');

  final content = await src.readAsString();
  final json = jsonDecode(content);

  final groups = <ModelGroup>[];
  final tags = <String, ModelTag>{};
  final models = <ModelInfo>[];

  final digest = crypto.md5;

  for (final g in json.entries) {
    groups.add(
      ModelGroup(name: g.key, desc: '', backends: [], platforms: [], tags: []),
    );
    for (final m in g.value['model_config']) {
      m['id'] = digest.convert(utf8.encode(m['url'])).toString();
      m['groups'] = [g.key];
      m['backend'] = m['backends']?.first;
      m['updatedAt'] = (m['date'] ?? 0) * 1000;
      ModelInfo model = ModelInfo.fromMap(m);
      if (model.groups.contains('albatross')) {
        model = model.copyWith(backend: ModelBackend.albatross);
      }
      if (model.name.toLowerCase().contains("coreml") ||
          model.name.contains("Translat") ||
          model.name.contains("mlx") ||
          (!model.groups.contains("chat") &&
              !model.groups.contains("roleplay"))) {
        continue;
      }

      model = model.copyWith(contextLength: extractCtxLen(model.url));

      models.add(model);

      for (final tag in m['tags'] ?? []) {
        if (!tags.containsKey(tag)) {
          tags[tag] = ModelTag(name: tag, desc: '', color: '');
        }
      }
    }
  }

  groups.removeWhere((e) => !models.any((m) => m.groups.contains(e.name)));
  tags.removeWhere((e, v) => !models.any((m) => m.tags.contains(e)));

  final config = ModelConfig(
    version: 1,
    timestamp: DateTime.now().millisecondsSinceEpoch ~/ 1000,
    models: models,
    tags: tags.values.toList(),
    groups: groups,
    vocabList: [],
    decodeParams: [],
  );

  final parsed = jsonEncode(config.toMap());
  if (await dst.exists()) {
    await dst.delete();
  }
  await dst.create(recursive: true);
  await dst.writeAsString(parsed);

  print("serving....");
  await serve();
  return;
}

int extractCtxLen(String text) {
  final reg = RegExp(r'ctx(\d+)\D');
  final match = reg.firstMatch(text);
  if (match == null) return -1;
  return int.parse(match.group(1)!);
}
