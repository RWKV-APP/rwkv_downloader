import 'package:rwkv_downloader/src/model/enums.dart';
import 'package:rwkv_downloader/src/model/model_config.dart';
import 'package:rwkv_downloader/src/model/model_group.dart';
import 'package:rwkv_downloader/src/model/model_info.dart';
import 'package:rwkv_downloader/src/model/model_tag.dart';
import 'package:test/test.dart';

void main() {
  //
  test('test_model_config', () {
    final config = ModelConfig(
      version: 1,
      timestamp: 0,
      vocabList: [],
      decodeParams: [],
      models: [
        ModelInfo(
          decodeParams: [],
          id: 'id',
          name: 'name',
          modelSize: 1,
          url: 'url',
          sha256: 'sha256',
          md5: 'md5',
          fileSize: 1,
          quantization: 'quantization',
          backend: ModelBackend.web_rwkv,
          tags: ['tag1'],
          groups: ['group1'],
          isDebug: false,
          description: '',
          updatedAt: 0,
          vocabId: '',
          vocabUrl: '',
          contextLength: -1
        ),
      ],
      tags: [ModelTag(name: 'tag1', desc: 'desc', color: 'color')],
      groups: [
        ModelGroup(
          name: 'group1',
          desc: 'desc',
          platforms: [ModelPlatform.android],
          backends: [ModelBackend.web_rwkv],
          tags: [1],
        ),
      ],
    );
    final config2 = ModelConfig.fromMap(config.toMap());
    print(config2.toMap());
  });
}
