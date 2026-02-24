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

      models.add(model);

      for (final tag in m['tags'] ?? []) {
        if (!tags.containsKey(tag)) {
          tags[tag] = ModelTag(name: tag, desc: '', color: '');
        }
      }
    }
  }

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

  await serve();
  return;
}
