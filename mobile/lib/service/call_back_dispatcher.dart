import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_community/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pocketmind/api/api_constants.dart';
import 'package:pocketmind/core/constants.dart';
import 'package:pocketmind/model/category.dart';
import 'package:pocketmind/model/note.dart';
import 'package:pocketmind/model/note_asset.dart';
import 'package:pocketmind/model/chat_session.dart';
import 'package:pocketmind/model/chat_message.dart';
import 'package:pocketmind/sync/model/mutation_entry.dart';
import 'package:pocketmind/sync/model/sync_checkpoint.dart';
import 'package:pocketmind/providers/infrastructure_providers.dart';
import 'package:pocketmind/providers/shared_preferences_provider.dart';
import 'package:pocketmind/service/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import 'package:uuid/uuid.dart';

import '../api/note_api_service.dart';
import '../api/models/note_metadata.dart';
import '../providers/note_providers.dart';
import '../providers/pm_service_providers.dart';
import '../util/image_storage_helper.dart';
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
        NoteAssetSchema,
        ChatSessionSchema,
        ChatMessageSchema,
        MutationEntrySchema,
        SyncCheckpointSchema,
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
        case AppConstants.taskScrapeAndSave:
          final urls =
              (inputData?[AppConstants.taskInputUrls] as List?)
                  ?.map((e) => e.toString())
                  .toList() ??
              [];
          final userQuestion = inputData?[AppConstants.taskInputUserQuestion];
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
        case AppConstants.taskRetryUrlsWithPolicy:
          final urls =
              (inputData?[AppConstants.taskInputUrls] as List?)
                  ?.map((e) => e.toString())
                  .toList() ??
              [];
          if (urls.isNotEmpty) {
            await retryUrlsWithPolicy(ref, urls, notificationService);
          }
          break;
        case AppConstants.taskNotifyRetryExhausted:
          final urls =
              (inputData?[AppConstants.taskInputUrls] as List?)
                  ?.map((e) => e.toString())
                  .toList() ??
              [];
          if (urls.isNotEmpty) {
            await notifyRetryExhausted(notificationService, urls);
          }
          break;
        case AppConstants.taskMarkDismissedUrlsFailed:
          final urls =
              (inputData?[AppConstants.taskInputUrls] as List?)
                  ?.map((e) => e.toString())
                  .toList() ??
              [];
          if (urls.isNotEmpty) {
            await ref
                .read(noteServiceProvider)
                .markUrlsAsFailedAndStopRetry(urls);
            PMlog.d(tag, '已处理忽略动作，URL 标记失败并停止重试: $urls');
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
  final List<String> successUrls = [];
  final List<String> failedUrls = [];
  final List<String> successPreviews = [];
  String? lastErrorMessage;

  try {
    final noteService = ref.read(noteServiceProvider);

    // 0. 标记为抓取中
    final processingNotes = await noteService.findNotesWithUrls(urls);
    for (final note in processingNotes) {
      await noteService.persistResourceStatus(
        note,
        AppConstants.resourceStatusScraping,
      );
    }

    // 1. 客户端尝试抓取（主要用于小红书/知乎/Bilibili 等平台特定网站）
    final metadataResults = await ref
        .read(metadataManagerProvider)
        .fetchAndProcessMetadata(urls);

    // 2. 查找对应笔记
    final notes = await noteService.findNotesWithUrls(urls);

    final noteApiService = ref.read(noteApiServiceProvider);
    final assetApiService = ref.read(assetApiServiceProvider);

    for (final note in notes) {
      final url = note.url;
      if (url == null) continue;

      final metaData = metadataResults[url];
      final bool isFromPlatformScraper =
          metaData?.source == MetadataSource.platformScraper;
      final fetchedPreviewContent =
          metaData?.previewContent ?? metaData?.previewDescription;
      final bool hasFetchedContent =
          fetchedPreviewContent != null && fetchedPreviewContent.isNotEmpty;

      try {
        // 更新客户端抓取到的基础元数据（如有）
        if (metaData != null) {
          note.previewTitle ??= metaData.title;
          if (note.previewContent == null && hasFetchedContent) {
            note.previewContent = fetchedPreviewContent;
          }
          // 将元数据中的第一张图路径设为预览图
          if (note.previewImageUrl == null && metaData.imageUrls.isNotEmpty) {
            note.previewImageUrl = metaData.imageUrls.first;
          }
        }

        // 仅平台爬虫成功时才有本地图片需要上传
        if (isFromPlatformScraper &&
            metaData != null &&
            metaData.imageUrls.isNotEmpty) {
          await ImageStorageHelper().init();
          final isar = ref.read(isarProvider);
          int sortOrder = 0;
          for (final relativePath in metaData.imageUrls) {
            try {
              final file = ImageStorageHelper().getFileByRelativePath(
                relativePath,
              );
              if (await file.exists()) {
                try {
                  final res = await assetApiService.uploadImage(
                    file,
                    noteUuid: note.uuid!,
                    sortOrder: sortOrder,
                  );
                  await _upsertImageNoteAsset(
                    isar: isar,
                    noteUuid: note.uuid!,
                    relativePath: relativePath,
                    sortOrder: sortOrder,
                    fileSize: res.size,
                    mime: res.mime,
                    serverAssetUuid: res.uuid,
                    serverUrl: '${ApiConstants.assetsImages}/${res.uuid}',
                    metadataJson: jsonEncode({
                      'width': res.width,
                      'height': res.height,
                    }),
                  );
                } catch (e) {
                  final fileSize = await file.length();
                  await _upsertImageNoteAsset(
                    isar: isar,
                    noteUuid: note.uuid!,
                    relativePath: relativePath,
                    sortOrder: sortOrder,
                    fileSize: fileSize,
                    mime: _guessImageMime(relativePath),
                  );
                  PMlog.w(tag, '上传失败，已保留本地资产: $relativePath, e=$e');
                }
                sortOrder++;
                PMlog.d(tag, '已写入 NoteAsset: $relativePath');
              }
            } catch (e) {
              PMlog.e(tag, '图片上传失败，静默跳过: $relativePath, e=$e');
            }
          }
        }

        // 提交 AI 分析，入队等待前台轮询
        // - 平台爬虫成功 / 有客户端内容 → 后端直接分析已有内容
        // - 通用网址 → 后端自行抓取再分析
        await noteApiService.submitAnalysis(
          uuid: note.uuid!,
          url: url,
          previewTitle: note.previewTitle,
          previewContent: _nonEmptyText(note.previewContent),
          userQuestion: userQuestion,
        );

        // 将 noteUuid 入队，应用进前台时由 AiPollingService 轮询回写
        final prefs = ref.read(sharedPreferencesProvider);
        await _enqueueAiAnalysis(prefs, note.uuid!);

        // 元数据处理完成，标记 CRAWLED
        await noteService.persistResourceStatus(
          note,
          AppConstants.resourceStatusCrawled,
        );
        await ref.read(noteRepositoryProvider).saveSyncInternalNote(note);

        final platform = _getPlatformName(url, metaData?.source);
        final content = note.previewTitle ?? note.previewContent;
        successUrls.add(url);
        successPreviews.add('[$platform] ${_truncateText(content, 15)}');
        PMlog.d(tag, '笔记处理成功: $url');
      } catch (e) {
        PMlog.e(tag, '笔记处理失败: $url, e=$e');
        await noteService.persistResourceStatus(
          note,
          AppConstants.resourceStatusPending,
        );
        failedUrls.add(url);
        lastErrorMessage = e.toString().length > 80
            ? e.toString().substring(0, 80)
            : e.toString();
      }
    }

    // 检查是否有 URL 没有找到对应笔记
    for (final url in urls) {
      if (!successUrls.contains(url) && !failedUrls.contains(url)) {
        failedUrls.add(url);
        lastErrorMessage = '未找到对应的笔记记录';
      }
    }

    PMlog.d(tag, '处理结果统计: 成功=${successUrls.length}, 失败=${failedUrls.length}');

    // 失败 URL 增加失败计数，达到上限后标记 FAILED 并停止重试
    final reachedMaxRetryUrls = await noteService.increaseRetryCountForUrls(
      failedUrls,
    );
    if (reachedMaxRetryUrls.isNotEmpty) {
      await noteService.markUrlsAsFailedAndStopRetry(reachedMaxRetryUrls);
      failedUrls.removeWhere(reachedMaxRetryUrls.contains);
      await notifyRetryExhausted(notificationService, reachedMaxRetryUrls);
      PMlog.w(tag, 'URL 达到最大重试次数，已标记失败并停止重试: $reachedMaxRetryUrls');
    }

    // 清理主要成功 URL
    await noteService.removePendingUrls(successUrls);

    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.reload();

    // 发送抓取结果通知
    if (successUrls.isNotEmpty && failedUrls.isEmpty) {
      await notificationService.showScrapeResultNotification(
        resultType: ScrapeResultType.success,
        successCount: successUrls.length,
        contentPreviews: successPreviews,
      );
    } else if (successUrls.isNotEmpty && failedUrls.isNotEmpty) {
      await notificationService.showScrapeResultNotification(
        resultType: ScrapeResultType.partialSuccess,
        successCount: successUrls.length,
        failedCount: failedUrls.length,
        failedUrls: failedUrls,
        contentPreviews: successPreviews,
        errorMessage: lastErrorMessage,
      );
    } else if (failedUrls.isNotEmpty) {
      await notificationService.showScrapeResultNotification(
        resultType: ScrapeResultType.failed,
        failedCount: failedUrls.length,
        failedUrls: failedUrls,
        errorMessage: lastErrorMessage ?? '分析失败，请检查网络后重试',
      );
    }
  } catch (e) {
    PMlog.e(tag, '抓取过程发生异常: $e');

    // 异常结束：将本次抓取中的记录恢复为待重试，避免 UI 卡在抓取中
    final noteService = ref.read(noteServiceProvider);
    final processingNotes = await noteService.findNotesWithUrls(urls);
    for (final note in processingNotes) {
      if (note.resourceStatus == AppConstants.resourceStatusScraping) {
        await noteService.persistResourceStatus(
          note,
          AppConstants.resourceStatusPending,
        );
      }
    }

    // 发送失败通知
    await notificationService.showScrapeResultNotification(
      resultType: ScrapeResultType.failed,
      failedUrls: urls,
      errorMessage:
          '抓取过程中发生错误: ${e.toString().length > 50 ? e.toString().substring(0, 50) : e.toString()}',
    );
  }
}

Future<void> retryUrlsWithPolicy(
  ProviderContainer ref,
  List<String> requestedUrls,
  NotificationService notificationService,
) async {
  final noteService = ref.read(noteServiceProvider);
  final eligibility = await noteService.evaluateRetryEligibility(requestedUrls);

  if (eligibility.reachedMaxRetryUrls.isNotEmpty) {
    await noteService.markUrlsAsFailedAndStopRetry(
      eligibility.reachedMaxRetryUrls,
    );
    await notifyRetryExhausted(
      notificationService,
      eligibility.reachedMaxRetryUrls,
    );
    PMlog.w(tag, '通知重试被拦截：已达上限并标记失败: ${eligibility.reachedMaxRetryUrls}');
  }

  if (eligibility.retryableUrls.isEmpty) {
    PMlog.d(tag, '无可重试 URL（可能已取消、已成功或已达上限）');
    return;
  }

  await noteService.markUrlsAsScraping(eligibility.retryableUrls);

  PMlog.d(tag, '触发重试任务: ${eligibility.retryableUrls}');
  await noteService.scheduleScrapeTask(
    urls: eligibility.retryableUrls,
    taskUniqueName:
        'url_scraper_retry_${DateTime.now().millisecondsSinceEpoch}',
    userQuestion: null,
    initialDelay: const Duration(seconds: 1),
  );
}

Future<void> notifyRetryExhausted(
  NotificationService notificationService,
  List<String> urls,
) async {
  if (urls.isEmpty) return;
  await notificationService.showScrapeResultNotification(
    resultType: ScrapeResultType.failed,
    failedCount: urls.length,
    errorMessage: '已尝试3次抓取均失败，对应网页目前无法正常爬取~',
  );
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

String? _nonEmptyText(String? text) {
  if (text == null) return null;
  final normalized = text.trim();
  return normalized.isEmpty ? null : normalized;
}

/// 将 noteUuid 加入 AI 分析待轮询队列。
Future<void> _enqueueAiAnalysis(
  SharedPreferences prefs,
  String noteUuid,
) async {
  await prefs.reload();
  final pending = List<String>.from(
    prefs.getStringList(AppConstants.keyPendingAiAnalysis) ?? [],
  );
  if (!pending.contains(noteUuid)) {
    pending.add(noteUuid);
    await prefs.setStringList(AppConstants.keyPendingAiAnalysis, pending);
    PMlog.d(tag, '已入队 AI 待轮询: $noteUuid');
  }
}

Future<void> _upsertImageNoteAsset({
  required Isar isar,
  required String noteUuid,
  required String relativePath,
  required int sortOrder,
  required int fileSize,
  required String mime,
  String? serverAssetUuid,
  String? serverUrl,
  String? metadataJson,
}) async {
  await isar.writeTxn(() async {
    final existing = await isar.noteAssets
        .filter()
        .noteUuidEqualTo(noteUuid)
        .and()
        .localPathEqualTo(relativePath)
        .findFirst();

    final asset = existing ?? NoteAsset();
    asset.noteUuid = noteUuid;
    asset.assetUuid =
        serverAssetUuid ??
        (existing != null ? existing.assetUuid : 'local-${Uuid().v4()}');
    asset.type = 'image';
    asset.mime = mime;
    asset.fileSize = fileSize;
    asset.sortOrder = sortOrder;
    asset.localPath = relativePath;
    asset.serverUrl = serverUrl ?? asset.serverUrl;
    asset.metadataJson = metadataJson ?? asset.metadataJson;
    if (existing == null) {
      asset.createdAt = DateTime.now();
    }

    await isar.noteAssets.put(asset);
  });
}

String _guessImageMime(String path) {
  final lower = path.toLowerCase();
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.webp')) return 'image/webp';
  if (lower.endsWith('.gif')) return 'image/gif';
  return 'image/jpeg';
}
