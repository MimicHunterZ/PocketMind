import 'package:flutter_test/flutter_test.dart';
import 'package:pocketmind/api/note_api_service.dart';

void main() {
  group('AiAnalyzeResponse JSON 解析测试', () {
    test('SUMMARY 模式 - 正确解析 summary 和 tags', () {
      // 用户提供的 SUMMARY 模式 JSON
      final json = {
        'mode': 'SUMMARY',
        'userQuestion': '',
        'aiResponse': {
          'summary': '文章分享了为开源大模型快速适配 transformers 和 vLLM 推理框架的实践经验与高效工作流。',
          'tags': ['大模型推理', 'transformers', 'vLLM', '开源贡献', '模型适配'],
        },
      };

      final response = AiAnalyzeResponse.fromJson(json);

      expect(response.mode, 'SUMMARY');
      expect(response.isSummaryMode, true);
      expect(response.isQaMode, false);
      expect(response.userQuestion, '');
      expect(
        response.summary,
        '文章分享了为开源大模型快速适配 transformers 和 vLLM 推理框架的实践经验与高效工作流。',
      );
      expect(response.tags, ['大模型推理', 'transformers', 'vLLM', '开源贡献', '模型适配']);
      expect(response.qaAnswer, null);
    });

    test('QA 模式 - 正确解析 aiResponse 字符串', () {
      // 用户提供的 QA 模式 JSON
      final json = {
        'mode': 'QA',
        'userQuestion': 'vllm 是什么？',
        'aiResponse':
            '根据提供的内容，vLLM 是一个主流的大模型推理仓库或框架，用于大模型的推理。它依赖于 transformers 库，会调用模型的 transformers config。在适配新模型时，如果已经完成了 transformers 库的实现，可以较快地实现 vLLM 版本。vLLM 有自己独立的代码审核和持续集成（CI）流程。',
      };

      final response = AiAnalyzeResponse.fromJson(json);

      expect(response.mode, 'QA');
      expect(response.isQaMode, true);
      expect(response.isSummaryMode, false);
      expect(response.userQuestion, 'vllm 是什么？');
      expect(
        response.qaAnswer,
        '根据提供的内容，vLLM 是一个主流的大模型推理仓库或框架，用于大模型的推理。它依赖于 transformers 库，会调用模型的 transformers config。在适配新模型时，如果已经完成了 transformers 库的实现，可以较快地实现 vLLM 版本。vLLM 有自己独立的代码审核和持续集成（CI）流程。',
      );
      expect(response.summary, null);
      expect(response.tags, isEmpty);
    });

    test('SUMMARY 模式 - tags 为空数组时返回空列表', () {
      final json = {
        'mode': 'SUMMARY',
        'userQuestion': '',
        'aiResponse': {'summary': '这是一篇文章的摘要。', 'tags': <String>[]},
      };

      final response = AiAnalyzeResponse.fromJson(json);

      expect(response.isSummaryMode, true);
      expect(response.summary, '这是一篇文章的摘要。');
      expect(response.tags, isEmpty);
    });

    test('SUMMARY 模式 - aiResponse 为 null 时返回 null/空', () {
      final json = {'mode': 'SUMMARY', 'userQuestion': '', 'aiResponse': null};

      final response = AiAnalyzeResponse.fromJson(json);

      expect(response.isSummaryMode, true);
      expect(response.summary, null);
      expect(response.tags, isEmpty);
    });

    test('QA 模式 - userQuestion 为 null 时正确处理', () {
      final json = {
        'mode': 'QA',
        'userQuestion': null,
        'aiResponse': '这是 AI 的回答。',
      };

      final response = AiAnalyzeResponse.fromJson(json);

      expect(response.isQaMode, true);
      expect(response.userQuestion, null);
      expect(response.qaAnswer, '这是 AI 的回答。');
    });
  });
}
