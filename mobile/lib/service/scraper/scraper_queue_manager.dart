import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pocketmind/util/logger_service.dart';
import 'package:pocketmind/service/scraper/scraper_task.dart';

/// 爬虫队列管理器
///
/// 负责管理爬虫任务队列，支持：
/// - 任务持久化（SharedPreferences）
/// - 任务去重（同一 noteId 不重复入队）
/// - 失败自动重试（最多 3 次，间隔 30 秒）
/// - 串行执行（同时最多 1 个任务运行）
/// - 任务取消
class ScraperQueueManager {
  static const String _tag = 'ScraperQueue';
  static const String _queueKey = 'scraper_task_queue';
  static const Duration _retryDelay = Duration(seconds: 30);

  static ScraperQueueManager? _instance;
  SharedPreferences? _prefs;

  /// 任务队列
  final List<ScraperTask> _queue = [];

  /// 当前正在执行的任务
  ScraperTask? _currentTask;

  /// 是否正在处理队列
  bool _isProcessing = false;

  /// 取消标记
  bool _cancelRequested = false;

  /// 队列变化通知流
  final StreamController<List<ScraperTask>> _queueController =
      StreamController<List<ScraperTask>>.broadcast();

  /// 当前任务变化通知流
  final StreamController<ScraperTask?> _currentTaskController =
      StreamController<ScraperTask?>.broadcast();

  /// MethodChannel 用于与 Android 前台服务通信
  static const MethodChannel _channel = MethodChannel(
    'com.doublez.pocketmind/scraper',
  );

  /// 任务执行回调（由外部设置）
  Future<void> Function(ScraperTask task)? onExecuteTask;

  /// 任务失败通知回调（由外部设置）
  void Function(ScraperTask task, String error)? onTaskFailed;

  ScraperQueueManager._() {
    _setupMethodChannel();
  }

  /// 获取单例实例
  static ScraperQueueManager get instance {
    _instance ??= ScraperQueueManager._();
    return _instance!;
  }

  /// 工厂构造函数
  factory ScraperQueueManager() => instance;

  /// 设置 MethodChannel 处理器
  void _setupMethodChannel() {
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'processQueue':
          await processQueue();
          break;
        case 'cancelTask':
          final noteId = call.arguments['noteId'] as int?;
          if (noteId != null) {
            await cancel(noteId);
          }
          break;
        case 'getQueueStatus':
          return {
            'queueLength': getQueueLength(),
            'currentUrl': _currentTask?.url,
            'isProcessing': _isProcessing,
          };
      }
    });
  }

  /// 初始化
  Future<void> init(SharedPreferences prefs) async {
    _prefs = prefs;
    await _loadQueue();
    PMlog.d(_tag, '初始化完成, 队列长度: ${_queue.length}');
  }

  /// 确保已初始化
  Future<SharedPreferences> _ensurePrefs() async {
    if (_prefs == null) {
      _prefs = await SharedPreferences.getInstance();
      await _loadQueue();
    }
    return _prefs!;
  }

  /// 从持久化存储加载队列
  Future<void> _loadQueue() async {
    final prefs = await _ensurePrefs();
    final jsonStr = prefs.getString(_queueKey);

    if (jsonStr == null || jsonStr.isEmpty) {
      return;
    }

    try {
      final List<dynamic> jsonList = jsonDecode(jsonStr);
      _queue.clear();
      for (var json in jsonList) {
        final task = ScraperTask.fromJson(json);
        // 恢复时将 running 状态重置为 pending（可能是上次异常退出）
        if (task.status == TaskStatus.running) {
          task.status = TaskStatus.pending;
        }
        _queue.add(task);
      }
      PMlog.d(_tag, '从存储恢复 ${_queue.length} 个任务');
    } catch (e) {
      PMlog.e(_tag, '加载队列失败: $e');
    }
  }

  /// 持久化队列到存储
  Future<void> _saveQueue() async {
    final prefs = await _ensurePrefs();
    final jsonList = _queue.map((t) => t.toJson()).toList();
    await prefs.setString(_queueKey, jsonEncode(jsonList));
    PMlog.d(_tag, '队列已持久化, 任务数: ${_queue.length}');
  }

  /// 广播队列变化
  void _notifyQueueChanged() {
    _queueController.add(List.unmodifiable(_queue));
  }

  /// 广播当前任务变化
  void _notifyCurrentTaskChanged() {
    _currentTaskController.add(_currentTask);
  }

  /// 入队新任务
  ///
  /// [noteId] 笔记 ID
  /// [url] 目标 URL
  /// [platform] 平台标识符
  /// 返回 true 表示成功入队，false 表示已存在相同任务
  Future<bool> enqueue(int noteId, String url, String platform) async {
    await _ensurePrefs();

    // 检查是否已存在相同 noteId 的 pending/running 任务（去重）
    final existingTask = _queue.firstWhere(
      (t) =>
          t.noteId == noteId &&
          (t.status == TaskStatus.pending || t.status == TaskStatus.running),
      orElse: () => ScraperTask(noteId: -1, url: '', platform: ''),
    );

    if (existingTask.noteId != -1) {
      PMlog.d(
        _tag,
        '任务已存在, 跳过入队: noteId=$noteId, status=${existingTask.status.displayName}',
      );
      return false;
    }

    // 创建新任务
    final task = ScraperTask(noteId: noteId, url: url, platform: platform);

    _queue.add(task);
    await _saveQueue();
    _notifyQueueChanged();

    PMlog.d(
      _tag,
      '任务入队: noteId=$noteId, url=${task.truncatedUrl}, '
      'platform=$platform, queueLength=${_queue.length}',
    );

    return true;
  }

  /// 获取下一个可执行的任务
  ScraperTask? _dequeue() {
    for (var task in _queue) {
      if (task.canExecuteNow) {
        return task;
      }
    }
    return null;
  }

  /// 处理队列
  Future<void> processQueue() async {
    if (_isProcessing) {
      PMlog.d(_tag, '队列正在处理中，跳过');
      return;
    }

    _isProcessing = true;
    _cancelRequested = false;

    try {
      while (!_cancelRequested) {
        // 获取下一个任务
        final task = _dequeue();
        if (task == null) {
          PMlog.d(_tag, '队列为空或无可执行任务');
          break;
        }

        // 标记为 running
        task.status = TaskStatus.running;
        task.startedAt = DateTime.now();
        _currentTask = task;
        await _saveQueue();
        _notifyQueueChanged();
        _notifyCurrentTaskChanged();

        // 更新 Android 通知
        await _updateNotification(task);

        PMlog.d(
          _tag,
          '开始执行任务: noteId=${task.noteId}, '
          'url=${task.truncatedUrl}, retryCount=${task.retryCount}',
        );

        try {
          // 执行任务
          if (onExecuteTask != null) {
            await onExecuteTask!(task);
          }

          // 执行成功，标记完成并移除
          await markCompleted(task.noteId);
        } catch (e) {
          // 执行失败
          final errorMsg = e.toString();
          final isCookieError = errorMsg.contains('Cookie');

          PMlog.e(_tag, '任务执行失败: noteId=${task.noteId}, error=$errorMsg');

          // Cookie 错误不重试
          await markFailed(task.noteId, errorMsg, canRetry: !isCookieError);
        }
      }
    } finally {
      _isProcessing = false;
      _currentTask = null;
      _notifyCurrentTaskChanged();

      // 队列处理完毕，停止前台服务
      await _stopForegroundService();

      PMlog.d(_tag, '队列处理完毕');
    }
  }

  /// 标记任务完成
  Future<void> markCompleted(int noteId) async {
    final index = _queue.indexWhere((t) => t.noteId == noteId);
    if (index == -1) return;

    // 从队列移除
    _queue.removeAt(index);
    await _saveQueue();
    _notifyQueueChanged();

    PMlog.d(_tag, '任务完成并移除: noteId=$noteId, remainingTasks=${_queue.length}');
  }

  /// 标记任务失败
  ///
  /// [noteId] 笔记 ID
  /// [error] 错误信息
  /// [canRetry] 是否允许重试
  Future<void> markFailed(
    int noteId,
    String error, {
    bool canRetry = true,
  }) async {
    final index = _queue.indexWhere((t) => t.noteId == noteId);
    if (index == -1) return;

    final task = _queue[index];

    if (canRetry && task.canRetry) {
      // 可以重试：增加重试计数，设置延迟重试时间，状态改回 pending
      task.retryCount++;
      task.nextRetryAt = DateTime.now().add(_retryDelay);
      task.status = TaskStatus.pending;
      task.errorMessage = error;

      PMlog.d(
        _tag,
        '任务将重试: noteId=$noteId, retryCount=${task.retryCount}, '
        'nextRetryAt=${task.nextRetryAt}',
      );
    } else {
      // 不能重试：标记为失败，保留在队列供 UI 查看
      task.status = TaskStatus.failed;
      task.completedAt = DateTime.now();
      task.errorMessage = error;

      // 通知失败
      onTaskFailed?.call(task, error);

      PMlog.d(_tag, '任务彻底失败: noteId=$noteId, error=$error');
    }

    await _saveQueue();
    _notifyQueueChanged();
  }

  /// 取消任务
  Future<void> cancel(int noteId) async {
    final index = _queue.indexWhere((t) => t.noteId == noteId);
    if (index == -1) return;

    final task = _queue[index];

    // 如果是当前正在执行的任务，设置取消标记
    if (_currentTask?.noteId == noteId) {
      _cancelRequested = true;
    }

    task.status = TaskStatus.cancelled;
    task.completedAt = DateTime.now();

    await _saveQueue();
    _notifyQueueChanged();

    PMlog.d(_tag, '任务已取消: noteId=$noteId');
  }

  /// 移除已完成/失败/取消的任务
  Future<void> removeTask(int noteId) async {
    _queue.removeWhere((t) => t.noteId == noteId);
    await _saveQueue();
    _notifyQueueChanged();

    PMlog.d(_tag, '任务已移除: noteId=$noteId');
  }

  /// 清除所有已完成的任务
  Future<void> clearCompletedTasks() async {
    _queue.removeWhere(
      (t) =>
          t.status == TaskStatus.completed ||
          t.status == TaskStatus.cancelled ||
          t.status == TaskStatus.failed,
    );
    await _saveQueue();
    _notifyQueueChanged();

    PMlog.d(_tag, '已清除完成的任务');
  }

  /// 获取 pending 任务数量
  int getQueueLength() {
    return _queue.where((t) => t.status == TaskStatus.pending).length;
  }

  /// 获取所有活跃任务（pending + running）
  List<ScraperTask> getActiveTasks() {
    return _queue
        .where(
          (t) =>
              t.status == TaskStatus.pending || t.status == TaskStatus.running,
        )
        .toList();
  }

  /// 获取所有任务
  List<ScraperTask> getAllTasks() {
    return List.unmodifiable(_queue);
  }

  /// 获取当前正在执行的任务
  ScraperTask? get currentTask => _currentTask;

  /// 是否正在处理
  bool get isProcessing => _isProcessing;

  /// 监听队列变化
  Stream<List<ScraperTask>> watchQueue() => _queueController.stream;

  /// 监听当前任务变化
  Stream<ScraperTask?> watchCurrentTask() => _currentTaskController.stream;

  /// 启动 Android 前台服务
  Future<void> startForegroundService() async {
    try {
      final taskCount = getQueueLength();
      await _channel.invokeMethod('startForegroundService', {
        'taskCount': taskCount,
      });
      PMlog.d(_tag, 'Android 前台服务已启动, taskCount=$taskCount');
    } catch (e) {
      PMlog.e(_tag, '启动前台服务失败: $e');
    }
  }

  /// 停止 Android 前台服务
  Future<void> _stopForegroundService() async {
    try {
      await _channel.invokeMethod('stopForegroundService');
      PMlog.d(_tag, 'Android 前台服务已停止');
    } catch (e) {
      PMlog.e(_tag, '停止前台服务失败: $e');
    }
  }

  /// 更新 Android 通知
  Future<void> _updateNotification(ScraperTask task) async {
    try {
      await _channel.invokeMethod('updateProgress', {
        'currentUrl': task.truncatedUrl,
        'pendingCount': getQueueLength(),
      });
    } catch (e) {
      PMlog.e(_tag, '更新通知失败: $e');
    }
  }

  /// 释放资源
  void dispose() {
    _queueController.close();
    _currentTaskController.close();
  }
}
