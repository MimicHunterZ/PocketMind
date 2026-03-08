import 'package:pocketmind/api/post_detail_service.dart';
import 'package:pocketmind/core/constants.dart';
import 'package:pocketmind/data/repositories/isar_note_repository.dart';
import 'package:pocketmind/util/logger_service.dart';
import 'package:pocketmind/util/tag_list_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _tag = 'AiPollingService';

/// AI 分析结果前台轮询服务。
///
/// 后台任务调用 submitAnalysis 后将 noteUuid 写入 SharedPreferences，
/// 应用进入前台时由 [pollAll] 并发轮询所有待处理任务并持久化结果。
///
/// 轮询结束条件：
/// - COMPLETED → 写入 aiSummary 等字段，移出队列
/// - FAILED    → 保留现有数据，移出队列
/// - PROCESSING（超时）→ 保留队列，等待下次 resume 重试
class AiPollingService {
  final SharedPreferences _prefs;
  final IsarNoteRepository _noteRepository;
  final PostDetailService _postDetailService;

  AiPollingService(this._prefs, this._noteRepository, this._postDetailService);

  /// 并发轮询所有待处理 AI 分析任务。
  Future<void> pollAll() async {
    await _prefs.reload();
    final pending = List<String>.from(
      _prefs.getStringList(AppConstants.keyPendingAiAnalysis) ?? [],
    );
    if (pending.isEmpty) return;

    PMlog.d(_tag, 'AI 结果轮询开始: count=${pending.length}');
    await Future.wait(pending.map(_pollOne));
  }

  Future<void> _pollOne(String noteUuid) async {
    try {
      PMlog.d(_tag, '轮询中: uuid=$noteUuid');
      final result = await _postDetailService.pollUntilComplete(noteUuid);

      if (result.isProcessing) {
        // 超时仍未完成 → 保留队列，下次 resume 继续
        PMlog.w(_tag, 'AI 分析超时，保留队列: uuid=$noteUuid');
        return;
      }

      final note = await _noteRepository.findByUuid(noteUuid);
      if (note == null) {
        PMlog.w(_tag, '笔记不存在，移出队列: uuid=$noteUuid');
        await _removePending(noteUuid);
        return;
      }

      if (!result.isFailed) {
        // 写入 AI 分析结果（不覆盖已有的客户端数据）
        note.aiSummary = result.summary;
        if (result.previewTitle != null && note.previewTitle == null) {
          note.previewTitle = result.previewTitle;
        }
        if (result.previewDescription != null && note.previewContent == null) {
          note.previewContent = result.previewDescription;
        }
        if (result.assets.isNotEmpty) {
          // 仅设置首张预览图，不覆盖已有值
          note.previewImageUrl ??= result.assets.firstOrNull?.url;
        }
        // 合并 AI 标签到本地（不覆盖用户手动添加的标签）
        if (result.tags.isNotEmpty) {
          note.tags = TagListUtils.mergeLocalAndServer(
            localTags: note.tags,
            serverTags: result.tags,
          );
        }
        PMlog.d(_tag, 'AI 分析完成，写入结果: uuid=$noteUuid');
      } else {
        PMlog.w(_tag, 'AI 分析失败，保留现有数据: uuid=$noteUuid');
      }

      await _noteRepository.saveSyncInternalNote(note);
      await _removePending(noteUuid);
    } catch (e) {
      // 轮询异常（如网络断开）不移出队列，下次 resume 重试
      PMlog.e(_tag, '轮询异常，保留队列: uuid=$noteUuid, e=$e');
    }
  }

  Future<void> _removePending(String noteUuid) async {
    await _prefs.reload();
    final current = List<String>.from(
      _prefs.getStringList(AppConstants.keyPendingAiAnalysis) ?? [],
    );
    current.remove(noteUuid);
    await _prefs.setStringList(AppConstants.keyPendingAiAnalysis, current);
    PMlog.d(_tag, '从 AI 轮询队列移除: uuid=$noteUuid');
  }
}
