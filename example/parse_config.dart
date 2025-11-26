import 'dart:convert';
import 'dart:io';

import 'package:rwkv_downloader/src/model/model.dart';

void main() async {
  final src = File('./example/latest.json');
  final dst = File('./example/latest_parsed.json');

  final content = await src.readAsString();
  final json = jsonDecode(content);

  final groups = <ModelGroup>[];
  final tags = <String, ModelTag>{};
  final models = <ModelInfo>[];

  for (final g in json.entries) {
    groups.add(
      ModelGroup(name: g.key, desc: '', backends: [], platforms: [], tags: []),
    );
    for (final m in g.value['model_config']) {
      m['id'] = m['url'];
      m['groups'] = [g.key];
      m['backend'] = m['backends']?.first;
      ModelInfo model = ModelInfo.fromMap(m);
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
  );

  final parsed = jsonEncode(config.toMap());
  if (await dst.exists()) {
    await dst.delete();
  }
  await dst.create(recursive: true);
  await dst.writeAsString(parsed);
}
