import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_community/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pocketmind/model/category.dart';
import 'package:pocketmind/model/note.dart';
import 'package:pocketmind/providers/infrastructure_providers.dart';
import 'package:pocketmind/providers/shared_preferences_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import '../api/note_api_service.dart';
import '../providers/note_providers.dart';
import '../util/logger_service.dart';

String tag = 'BackgroundWorker';
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    PMlog.d(tag, '后台任务启动: $task');
    try {
      // 1. 基础环境初始化
      WidgetsFlutterBinding.ensureInitialized();

      // 2. 重新初始化 Isar (因为在新的 Isolate 中)
      // 注意：这里不能依赖 main() 里的全局 isar 变量
      final dir = await getApplicationDocumentsDirectory();
      final isar = await Isar.open([
        NoteSchema,
        CategorySchema,
      ], directory: dir.path);

      final prefs = await SharedPreferences.getInstance();

      // 3. 构建 Riverpod 容器 (Container)
      // 后台没有 Widget 树，所以没有 ProviderScope，需要手动创建一个 Container
      final ref = ProviderContainer(
        overrides: [
          isarProvider.overrideWithValue(isar),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );

      switch (task) {
        case 'scrapeAndSave':
          final urls =
              (inputData?['urls'] as List?)
                  ?.map((e) => e.toString())
                  .toList() ??
              [];
          final userQuestion = inputData?['uq'];
          if (urls.isNotEmpty) {
            await scrapeAndSave(ref, urls, userQuestion);
          } else {
            PMlog.e(tag, 'url 的 value 为空');
          }
          break;
        default:
          // Handle unknown task types
          break;
      }

      return Future.value(true);
    } catch (e, stack) {
      // 【修改 2】: 捕获所有异常，防止 Worker 报红 FAILURE
      PMlog.e(tag, '❌ 任务执行发生严重错误: $e');
      PMlog.e(tag, '堆栈: $stack');

      // 返回 false 表示任务失败，WorkManager 配置了策略的话可能会重试
      return Future.value(false);
    }
  });
}

Future<void> scrapeAndSave(
  ProviderContainer ref,
  List<String> urls,
  String? userQuestion,
) async {
  // 1. 批量获取元数据
  final metadataResults = await ref
      .read(metadataManagerProvider)
      .fetchAndProcessMetadata(urls);

  // 2. 批量查找数据库中的笔记
  final notes = await ref.read(noteServiceProvider).findNotesWithUrls(urls);

  final noteRepo = ref.read(noteRepositoryProvider);
  final noteApiService = ref.read(noteApiServiceProvider);
  final needCleanUrls = [];
  // 3. 遍历找到的笔记进行处理
  for (final note in notes) {
    final url = note.url;

    // 校验：URL 不为空，且元数据抓取结果中包含该 URL
    if (url != null && metadataResults.containsKey(url)) {
      final metaDataNote = metadataResults[url];

      // 更新基础元数据
      note.previewContent =
          metaDataNote?.previewContent ?? metaDataNote?.previewDescription;
      note.previewTitle = metaDataNote?.title;
      note.previewImageUrls = metaDataNote?.imageUrls ?? note.previewImageUrls;

      await noteRepo.save(note);
      needCleanUrls.add(url);
      // AI 分析逻辑
      try {
        // 只有当有内容需要分析时才调用
        if (note.previewContent == null || note.previewContent!.isEmpty) {
          PMlog.w(tag, '笔记 $url 内容为空，跳过 AI 分析');
          continue;
        }

        PMlog.d(tag, '$url 有待处理的 AI 问题，开始调用 AI 分析');

        final aiResponse = await noteApiService.analyzeContent(
          uuid: note.uuid!,
          title: note.title,
          content: note.previewContent!,
          userQuestion: userQuestion,
        );

        // 根据模式保存结果
        if (aiResponse.isSummaryMode) {
          // SUMMARY 模式
          if (aiResponse.summary != null) {
            note.aiSummary = aiResponse.summary;
          }
        } else if (aiResponse.isQaMode) {
          // QA 模式
          final qaContent =
              'Q: ${aiResponse.userQuestion ?? note.pendingAiQuestion}\n\nA: ${aiResponse.qaAnswer ?? ''}';
          note.aiSummary = qaContent;
        }

        // 统一处理标签追加逻辑 (支持 SUMMARY 和 QA 模式)
        if (aiResponse.tags.isNotEmpty) {
          final existingTags = note.tag ?? '';
          final newTagsSet = aiResponse.tags.toSet();

          // 如果已有标签，避免重复
          if (existingTags.isNotEmpty) {
            final currentTagsList = existingTags.split(',');
            newTagsSet.removeAll(currentTagsList);
          }

          if (newTagsSet.isNotEmpty) {
            final newTagsStr = newTagsSet.join(',');
            note.tag = existingTags.isEmpty
                ? newTagsStr
                : '$existingTags,$newTagsStr';
          }
        }

        PMlog.d(tag, '笔记 $url AI 分析完成，mode=${aiResponse.mode}');

        // AI 分析完成后再次保存
        await noteRepo.save(note);
      } catch (e) {
        // AI 分析失败静默处理，不阻塞其他笔记的处理
        PMlog.e(tag, '笔记 $url AI 分析失败: $e');
      }
    }
  }

  PMlog.d(tag, '开始消除 URLs: $needCleanUrls');

  // 再次刷新，防止在处理过程中有新的 URL 加入
  final prefs = ref.read(sharedPreferencesProvider);
  await prefs.reload();
  final currentUrls = prefs.getStringList('needCallBackUrl') ?? [];
  for (var url in needCleanUrls) {
    currentUrls.remove(url);
  }
  await prefs.setStringList('needCallBackUrl', currentUrls);
  PMlog.d(tag, 'Pending URLs processed and cleared. Remaining: $currentUrls');
}
