import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:pocketmind/core/constants.dart';
import 'package:pocketmind/data/repositories/isar_note_repository.dart';
import 'package:pocketmind/service/metadata_manager.dart';
import 'package:pocketmind/sync/local_write_coordinator.dart';
import 'package:pocketmind/sync/sync_engine.dart';
import 'package:pocketmind/util/logger_service.dart';

/// 资源抓取调度器 —— 监听网络恢复事件，自动驱动 PENDING 笔记完成元数据抓取。
///
/// 职责范围：
/// - 扫描 [Note.resourceStatus] == PENDING 的笔记。
/// - 调用 [MetadataManager] 执行端侧抓取（链接预览 / 平台专属内容）。
/// - 抓取成功后更新 Note 字段并通知 [SyncEngine.kick]，触发推送告知后端。
/// - 抓取失败后更新 resourceStatus=FAILED，UI 降级展示裸 URL，不再无限重试。
///
/// 不负责：
/// - 后端 AI 摘要的拉取（由 Pull 增量机制自动回流）。
/// - 大文件上传（由独立的 AssetUploadService 处理）。
class ResourceFetchScheduler {
  final IsarNoteRepository _noteRepo;
  final MetadataManager _metadataManager;
  final LocalWriteCoordinator _writeCoordinator;
  final SyncEngine _syncEngine;

  static const String _tag = 'ResourceFetchScheduler';
  bool _isFetching = false;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  ResourceFetchScheduler({
    required IsarNoteRepository noteRepo,
    required MetadataManager metadataManager,
    required LocalWriteCoordinator writeCoordinator,
    required SyncEngine syncEngine,
  }) : _noteRepo = noteRepo,
       _metadataManager = metadataManager,
       _writeCoordinator = writeCoordinator,
       _syncEngine = syncEngine;

  /// 初始化调度器：
  /// - 订阅网络连接恢复事件，触发扫描
  /// - 启动时立即扫描一次（App 重启时处理上次遗留的 PENDING 笔记）
  void start() {
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      final hasNetwork = results.any((r) => r != ConnectivityResult.none);
      if (hasNetwork) {
        PMlog.d(_tag, '网络恢复，触发 PENDING 笔记扫描');
        _runScanNow();
      }
    });

    // 启动时立即扫描一次
    _runScanNow();
  }

  void dispose() {
    _connectivitySub?.cancel();
    _connectivitySub = null;
  }

  /// 立即触发一次 PENDING 笔记扫描（公开接口，供 App 前台恢复时调用）。
  /// 内部有防重入保护，并发调用安全。
  void runNow() {
    PMlog.d(_tag, '手动触发扫描（App 恢复或显式调用）');
    _runScanNow();
  }

  /// 立即执行一轮扫描（防重入）
  void _runScanNow() {
    if (_isFetching) return;
    _fetchPendingNotes();
  }

  Future<void> _fetchPendingNotes() async {
    _isFetching = true;
    try {
      // 查询所有 resourceStatus=PENDING 的笔记（有 url 且未抓取）
      final pendingNotes = await _noteRepo.findByResourceStatus(
        AppConstants.resourceStatusPending,
      );

      if (pendingNotes.isEmpty) {
        PMlog.d(_tag, '无 PENDING 笔记，跳过');
        return;
      }

      PMlog.d(_tag, '开始抓取 ${pendingNotes.length} 条 PENDING 笔记');

      for (final note in pendingNotes) {
        final url = note.url;
        if (url == null || url.isEmpty) continue;

        try {
          // 标记为抓取中
          await _noteRepo.updateResourceStatus(
            note,
            AppConstants.resourceStatusScraping,
          );

          // 调用 MetadataManager（端侧抓取：LinkPreview / 平台专属爬虫）
          final results = await _metadataManager.fetchAndProcessMetadata([url]);
          final metadata = results[url];

          if (metadata != null && metadata.isValid) {
            note
              ..previewTitle = metadata.title ?? note.previewTitle
              ..previewDescription =
                  metadata.displayDescription ?? note.previewDescription
              ..previewImageUrl = metadata.firstImage ?? note.previewImageUrl
              ..previewContent = metadata.previewContent ?? note.previewContent
              ..resourceStatus = AppConstants.resourceStatusCrawled;

            // 抓取成功后通过写入协调器落库并入队 mutation，避免下一轮 Pull 反向覆盖本地预览字段。
            await _writeCoordinator.writeNote(note);
            PMlog.d(_tag, '笔记 ${note.uuid} 抓取成功，状态: CRAWLED');

            // 通知 SyncEngine Push（后端收到 CRAWLED 后触发 AI 管线）
            _syncEngine.kick();
          } else {
            await _noteRepo.updateResourceStatus(
              note,
              AppConstants.resourceStatusFailed,
            );
            PMlog.w(_tag, '笔记 ${note.uuid} 抓取结果无效，标记 FAILED');
          }
        } catch (e) {
          PMlog.e(_tag, '笔记 ${note.uuid} 抓取出错: $e');
          await _noteRepo.updateResourceStatus(
            note,
            AppConstants.resourceStatusFailed,
          );
        }
      }
    } finally {
      _isFetching = false;
    }
  }
}
