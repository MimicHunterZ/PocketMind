import 'package:uuid/uuid.dart';

/// 进程级稳定标识。
///
/// 每个 isolate 第一次访问 [current] 时生成一个 UUID，后续访问保持不变；
/// 进程结束（被 OOM、强退、Workmanager 后台任务结束等）后下次启动会重新生成。
///
/// 用途：在 ScrapeAttempt 的 `claimedBy` 字段上标记是哪个 isolate / 进程
/// 领走了作业，让"慢 worker 写回 CAS"能识别出"我已被收编"。
abstract final class ProcessId {
  static String? _cached;

  /// 当前 isolate / 进程的稳定 UUID。
  static String get current => _cached ??= const Uuid().v4();

  /// 仅供测试使用：注入一个固定值或重置为下次生成。
  /// 生产代码不应调用。
  static void debugSet(String? value) {
    _cached = value;
  }
}
