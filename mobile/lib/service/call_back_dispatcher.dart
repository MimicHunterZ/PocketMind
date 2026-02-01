import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_community/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pocketmind/model/category.dart';
import 'package:pocketmind/model/note.dart';
import 'package:pocketmind/providers/infrastructure_providers.dart';
import 'package:pocketmind/providers/shared_preferences_provider.dart';
import 'package:pocketmind/service/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import '../api/note_api_service.dart';
import '../api/models/note_metadata.dart';
import '../providers/note_providers.dart';
import '../util/logger_service.dart';
import '../util/platform_detector.dart';

String tag = 'BackgroundWorker';
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    PMlog.d(tag, '后台任务启动: $task');

    // 初始化通知服务（用于发送抓取结果通知）
    final notificationService = NotificationService();

    try {
      // 1. 基础环境初始化
      WidgetsFlutterBinding.ensureInitialized();

      // 初始化通知服务
      await notificationService.init();

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
            await scrapeAndSave(ref, urls, userQuestion, notificationService);
          } else {
            PMlog.e(tag, 'url 的 value 为空');
            await notificationService.showScrapeResultNotification(
              resultType: ScrapeResultType.failed,
              errorMessage: 'URL 为空，无法进行抓取',
            );
          }
          break;
        default:
          // Handle unknown task types
          break;
      }

      return Future.value(true);
    } catch (e, stack) {
      // 捕获所有异常，防止 Worker 报红 FAILURE
      PMlog.e(tag, '❌ 任务执行发生严重错误: $e');
      PMlog.e(tag, '堆栈: $stack');

      // 发送失败通知
      final urls =
          (inputData?['urls'] as List?)?.map((e) => e.toString()).toList() ??
          [];
      await notificationService.showScrapeResultNotification(
        resultType: ScrapeResultType.failed,
        failedUrls: urls,
        errorMessage:
            '抓取过程中发生错误: ${e.toString().length > 50 ? e.toString().substring(0, 50) : e.toString()}',
      );

      // 返回 false 表示任务失败，WorkManager 配置了策略的话可能会重试
      return Future.value(false);
    }
  });
}

Future<void> scrapeAndSave(
  ProviderContainer ref,
  List<String> urls,
  String? userQuestion,
  NotificationService notificationService,
) async {
  final List<String> successUrls = []; // 主要渠道（平台爬虫/后端）成功的 URL
  final List<String> failedUrls = []; // 真正失败的 URL（所有策略都失败）
  final List<String> fallbackUrls = []; // 使用兜底策略成功的 URL（主要渠道失败）
  final List<String> successPreviews = []; // 成功的内容预览（平台: 标题前几个字）
  final List<String> fallbackPreviews = []; // 兜底成功的内容预览
  String? lastErrorMessage;

  try {
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
        note.previewImageUrls =
            metaDataNote?.imageUrls ?? note.previewImageUrls;

        await noteRepo.save(note);
        needCleanUrls.add(url);

        // 生成内容预览字符串：[平台] 内容前15个字...
        final platform = _getPlatformName(url, metaDataNote?.source);
        // 优先使用内容，其次标题
        final content =
            metaDataNote?.previewContent ??
            metaDataNote?.previewDescription ??
            metaDataNote?.title ??
            note.title;
        final contentPreview = _truncateText(content, 15);
        final preview = '[$platform] $contentPreview';

        // 根据数据来源分类
        if (metaDataNote?.isFromPrimarySource ?? false) {
          // 来自主要渠道（平台爬虫/后端），算作成功
          successUrls.add(url);
          successPreviews.add(preview);
          PMlog.d(tag, '笔记 $url 从主要渠道成功获取元数据');
        } else {
          // 来自兜底渠道（LinkPreview API/本地解析）
          // 需要发失败通知
          fallbackUrls.add(url);
          fallbackPreviews.add(preview);
          PMlog.d(tag, '笔记 $url 使用兜底策略获取元数据，来源: ${metaDataNote?.source}');
        }

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
      } else if (url != null) {
        // 元数据抓取完全失败（所有策略都失败了）
        // 这是真正的失败，需要通知用户
        failedUrls.add(url);
        lastErrorMessage = '无法获取链接预览信息';
        PMlog.w(tag, '笔记 $url 元数据抓取失败（所有策略）');
      }
    }

    // 检查是否有 URL 没有找到对应的笔记
    for (final url in urls) {
      if (!successUrls.contains(url) &&
          !failedUrls.contains(url) &&
          !fallbackUrls.contains(url)) {
        failedUrls.add(url);
        lastErrorMessage = '未找到对应的笔记记录';
      }
    }

    PMlog.d(tag, '开始消除 URLs: $needCleanUrls');
    PMlog.d(
      tag,
      '抓取结果统计: 主要渠道成功=${successUrls.length}, 兜底成功=${fallbackUrls.length}, 失败=${failedUrls.length}',
    );

    // 再次刷新，防止在处理过程中有新的 URL 加入
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.reload();
    final currentUrls = prefs.getStringList('needCallBackUrl') ?? [];
    for (var url in needCleanUrls) {
      currentUrls.remove(url);
    }
    await prefs.setStringList('needCallBackUrl', currentUrls);
    PMlog.d(tag, 'Pending URLs processed and cleared. Remaining: $currentUrls');

    // 发送抓取结果通知
    // 逻辑：
    // - 主要渠道成功 → 成功通知（显示平台和内容预览）
    // - 兜底成功 = 主要渠道失败 → 失败通知（显示平台和内容预览）
    // - 完全失败 → 失败通知

    // 合并所有需要发送失败通知的 URL（兜底成功 + 真正失败）
    final allFailedUrls = [...fallbackUrls, ...failedUrls];
    final allFailedPreviews = [...fallbackPreviews];

    if (successUrls.isNotEmpty && allFailedUrls.isEmpty) {
      // 全部主要渠道成功
      await notificationService.showScrapeResultNotification(
        resultType: ScrapeResultType.success,
        successCount: successUrls.length,
        contentPreviews: successPreviews,
      );
    } else if (successUrls.isNotEmpty && allFailedUrls.isNotEmpty) {
      // 部分成功（有主要渠道成功，也有失败/兜底）
      await notificationService.showScrapeResultNotification(
        resultType: ScrapeResultType.partialSuccess,
        successCount: successUrls.length,
        failedCount: allFailedUrls.length,
        failedUrls: allFailedUrls,
        contentPreviews: [...successPreviews, ...allFailedPreviews],
        errorMessage: lastErrorMessage,
      );
    } else if (allFailedUrls.isNotEmpty) {
      // 没有主要渠道成功，都是失败/兜底
      await notificationService.showScrapeResultNotification(
        resultType: ScrapeResultType.failed,
        failedCount: allFailedUrls.length,
        failedUrls: allFailedUrls,
        contentPreviews: allFailedPreviews.isNotEmpty
            ? allFailedPreviews
            : null,
        errorMessage: lastErrorMessage ?? '主要渠道抓取失败，已使用兜底策略',
      );
    }
  } catch (e) {
    PMlog.e(tag, '抓取过程发生异常: $e');
    // 发送失败通知
    await notificationService.showScrapeResultNotification(
      resultType: ScrapeResultType.failed,
      failedUrls: urls,
      errorMessage:
          '抓取过程中发生错误: ${e.toString().length > 50 ? e.toString().substring(0, 50) : e.toString()}',
    );
  }
}

/// 根据 URL 和元数据来源获取平台显示名称
///
/// 优先使用 URL 检测平台（如小红书、知乎、X 等）
/// 兜底时显示来源策略名称
String _getPlatformName(String url, MetadataSource? source) {
  // 先通过 URL 检测平台
  final platform = PlatformDetector.detectPlatform(url);

  // 如果检测到具体平台，返回平台名称
  if (platform != PlatformType.generic) {
    return platform.displayName;
  }

  // 通用平台，根据来源策略显示
  switch (source) {
    case MetadataSource.platformScraper:
      return '本地爬虫';
    case MetadataSource.backend:
      return '后端';
    case MetadataSource.linkPreviewApi:
      return 'API';
    case MetadataSource.localParser:
      return '本地';
    default:
      return '通用';
  }
}

/// 截断文本，超过指定长度时添加省略号
String _truncateText(String? text, int maxLength) {
  if (text == null || text.isEmpty) return '无标题';
  if (text.length <= maxLength) return text;
  return '${text.substring(0, maxLength)}...';
}
