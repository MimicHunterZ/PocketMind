import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_community/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pocketmind/core/constants.dart';
import 'package:pocketmind/model/category.dart';
import 'package:pocketmind/model/note.dart';
import 'package:pocketmind/model/note_asset.dart';
import 'package:pocketmind/model/chat_session.dart';
import 'package:pocketmind/model/chat_message.dart';
import 'package:pocketmind/model/scrape_attempt.dart';
import 'package:pocketmind/sync/model/mutation_entry.dart';
import 'package:pocketmind/sync/model/sync_checkpoint.dart';
import 'package:pocketmind/providers/infrastructure_providers.dart';
import 'package:pocketmind/providers/shared_preferences_provider.dart';
import 'package:pocketmind/providers/sync_providers.dart';
import 'package:pocketmind/service/notification_service.dart';
import 'package:pocketmind/util/image_storage_helper.dart';
import 'package:pocketmind/util/logger_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

const String _tag = 'BackgroundWorker';

/// Workmanager 后台任务分发入口。
///
/// 三种任务全部收敛到 [ResourceFetchScheduler] 的对应 API：
///   - [AppConstants.taskScrapeAndSave]：拉一次 scheduler.runNow()
///   - [AppConstants.taskRetryUrlsWithPolicy]：scheduler.retryNotes(noteUuids)
///   - [AppConstants.taskMarkDismissedUrlsFailed]：scheduler.dismissNotes(noteUuids)
///
/// inputData 中的 noteUuid 列表与 userQuestion 通过
/// [AppConstants.taskInputNoteUuids] / [AppConstants.taskInputUserQuestion] 传递。
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    PMlog.d(_tag, '后台任务启动: $task');

    final notificationService = NotificationService();

    try {
      WidgetsFlutterBinding.ensureInitialized();
      await notificationService.init();

      // 后台 isolate 重新打开 Isar
      final dir = await getApplicationDocumentsDirectory();
      final isar = await Isar.open([
        NoteSchema,
        CategorySchema,
        NoteAssetSchema,
        ChatSessionSchema,
        ChatMessageSchema,
        MutationEntrySchema,
        SyncCheckpointSchema,
        ScrapeAttemptSchema,
      ], directory: dir.path);

      await ImageStorageHelper().init();

      final prefs = await SharedPreferences.getInstance();

      final ref = ProviderContainer(
        overrides: [
          isarProvider.overrideWithValue(isar),
          sharedPreferencesProvider.overrideWithValue(prefs),
          notificationServiceProvider.overrideWithValue(notificationService),
        ],
      );

      try {
        final scheduler = ref.read(resourceFetchSchedulerProvider);
        switch (task) {
          case AppConstants.taskScrapeAndSave:
            final userQuestion =
                inputData?[AppConstants.taskInputUserQuestion] as String?;
            await scheduler.runNow(userQuestion: userQuestion);
            break;

          case AppConstants.taskRetryUrlsWithPolicy:
            final uuids = _readNoteUuids(inputData);
            if (uuids.isNotEmpty) {
              await scheduler.retryNotes(uuids);
            }
            await scheduler.runNow();
            break;

          case AppConstants.taskMarkDismissedUrlsFailed:
            final uuids = _readNoteUuids(inputData);
            if (uuids.isNotEmpty) {
              await scheduler.dismissNotes(uuids);
              PMlog.d(_tag, '已忽略并标记失败: $uuids');
            }
            break;

          default:
            PMlog.w(_tag, '未识别的后台任务: $task');
            break;
        }
      } finally {
        ref.dispose();
        // 显式关闭后台 isolate 的 Isar 实例。isolate 退出时 OS 会回收，
        // 但显式 close 让其他 isolate（主 App / 分享）能立刻拿到文件锁，
        // 而不是等 GC。
        try {
          await isar.close();
        } catch (e) {
          PMlog.w(_tag, 'Isar close 失败 (忽略): $e');
        }
      }

      return Future.value(true);
    } catch (e, stack) {
      PMlog.e(_tag, '❌ 后台任务异常: $e');
      PMlog.e(_tag, '堆栈: $stack');
      await notificationService.showScrapeResultNotification(
        resultType: ScrapeResultType.failed,
        errorMessage:
            '抓取过程中发生错误: ${e.toString().length > 50 ? e.toString().substring(0, 50) : e.toString()}',
      );
      return Future.value(false);
    }
  });
}

List<String> _readNoteUuids(Map<String, dynamic>? inputData) {
  return (inputData?[AppConstants.taskInputNoteUuids] as List?)
          ?.map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toSet()
          .toList() ??
      const <String>[];
}
