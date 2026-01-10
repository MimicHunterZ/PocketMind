/// 爬虫任务状态枚举
enum TaskStatus {
  /// 等待执行
  pending,

  /// 正在执行
  running,

  /// 执行完成
  completed,

  /// 执行失败
  failed,

  /// 已取消
  cancelled,
}

/// 任务状态扩展方法
extension TaskStatusExtension on TaskStatus {
  /// 获取显示名称
  String get displayName {
    switch (this) {
      case TaskStatus.pending:
        return '排队中';
      case TaskStatus.running:
        return '处理中';
      case TaskStatus.completed:
        return '已完成';
      case TaskStatus.failed:
        return '失败';
      case TaskStatus.cancelled:
        return '已取消';
    }
  }

  /// 从字符串解析
  static TaskStatus fromString(String value) {
    switch (value) {
      case 'pending':
        return TaskStatus.pending;
      case 'running':
        return TaskStatus.running;
      case 'completed':
        return TaskStatus.completed;
      case 'failed':
        return TaskStatus.failed;
      case 'cancelled':
        return TaskStatus.cancelled;
      default:
        return TaskStatus.pending;
    }
  }
}

/// 爬虫任务数据模型
///
/// 表示一个待处理的 URL 抓取任务
class ScraperTask {
  /// 关联的笔记 ID
  final int noteId;

  /// 目标 URL
  final String url;

  /// 平台标识符
  final String platform;

  /// 任务状态
  TaskStatus status;

  /// 创建时间
  final DateTime createdAt;

  /// 开始执行时间
  DateTime? startedAt;

  /// 完成时间
  DateTime? completedAt;

  /// 错误信息
  String? errorMessage;

  /// 重试次数
  int retryCount;

  /// 下次重试时间（用于延迟重试）
  DateTime? nextRetryAt;

  ScraperTask({
    required this.noteId,
    required this.url,
    required this.platform,
    this.status = TaskStatus.pending,
    DateTime? createdAt,
    this.startedAt,
    this.completedAt,
    this.errorMessage,
    this.retryCount = 0,
    this.nextRetryAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// 从 JSON 反序列化
  factory ScraperTask.fromJson(Map<String, dynamic> json) {
    return ScraperTask(
      noteId: json['noteId'] as int,
      url: json['url'] as String,
      platform: json['platform'] as String,
      status: TaskStatusExtension.fromString(json['status'] ?? 'pending'),
      createdAt: DateTime.parse(json['createdAt']),
      startedAt: json['startedAt'] != null
          ? DateTime.parse(json['startedAt'])
          : null,
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'])
          : null,
      errorMessage: json['errorMessage'] as String?,
      retryCount: json['retryCount'] ?? 0,
      nextRetryAt: json['nextRetryAt'] != null
          ? DateTime.parse(json['nextRetryAt'])
          : null,
    );
  }

  /// 序列化为 JSON
  Map<String, dynamic> toJson() {
    return {
      'noteId': noteId,
      'url': url,
      'platform': platform,
      'status': status.name,
      'createdAt': createdAt.toIso8601String(),
      'startedAt': startedAt?.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'errorMessage': errorMessage,
      'retryCount': retryCount,
      'nextRetryAt': nextRetryAt?.toIso8601String(),
    };
  }

  /// 是否可以立即执行
  bool get canExecuteNow {
    if (status != TaskStatus.pending) return false;
    if (nextRetryAt == null) return true;
    return DateTime.now().isAfter(nextRetryAt!);
  }

  /// 是否可以重试
  bool get canRetry => retryCount < 3;

  /// 获取截断的 URL（用于显示）
  String get truncatedUrl {
    if (url.length <= 40) return url;
    return '${url.substring(0, 40)}...';
  }

  /// 复制并修改
  ScraperTask copyWith({
    int? noteId,
    String? url,
    String? platform,
    TaskStatus? status,
    DateTime? createdAt,
    DateTime? startedAt,
    DateTime? completedAt,
    String? errorMessage,
    int? retryCount,
    DateTime? nextRetryAt,
  }) {
    return ScraperTask(
      noteId: noteId ?? this.noteId,
      url: url ?? this.url,
      platform: platform ?? this.platform,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      errorMessage: errorMessage ?? this.errorMessage,
      retryCount: retryCount ?? this.retryCount,
      nextRetryAt: nextRetryAt ?? this.nextRetryAt,
    );
  }

  @override
  String toString() {
    return 'ScraperTask(noteId: $noteId, url: $truncatedUrl, '
        'status: ${status.displayName}, retryCount: $retryCount)';
  }
}
