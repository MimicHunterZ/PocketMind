import 'package:flutter_local_notifications/flutter_local_notifications.dart'
    as fln;
import 'package:fluttertoast/fluttertoast.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:pocketmind/service/call_back_dispatcher.dart';
import 'package:pocketmind/util/logger_service.dart';
import 'package:workmanager/workmanager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'dart:convert';

import 'package:pocketmind/core/constants.dart';

/// 抓取结果类型
enum ScrapeResultType { success, partialSuccess, failed }

/// Action ID 常量
class NotificationActionIds {
  static const String retry = 'retry_scrape';
  static const String dismiss = 'dismiss';
}

/// 后台通知响应处理
@pragma('vm:entry-point')
void onBackgroundNotificationResponse(fln.NotificationResponse response) {
  PMlog.d(
    'NotificationService',
    '后台通知响应: actionId=${response.actionId}, payload=${response.payload}',
  );

  // 处理重试 action
  if (response.actionId == NotificationActionIds.retry &&
      response.payload != null) {
    _handleRetryAction(response.payload!);
    return;
  }

  // 处理忽略 action
  if (response.actionId == NotificationActionIds.dismiss &&
      response.payload != null) {
    _handleDismissAction(response.payload!);
  }
}

/// 处理重试 action
void _handleRetryAction(String payload) async {
  try {
    final failedUrls = _extractFailedUrls(payload);
    if (failedUrls.isEmpty) return;

    PMlog.d('NotificationService', '触发重试任务（策略校验由后台统一处理）: $failedUrls');

    Workmanager().initialize(callbackDispatcher, isInDebugMode: false);

    await Workmanager().registerOneOffTask(
      'url_scraper_retry_policy_${DateTime.now().millisecondsSinceEpoch}',
      AppConstants.taskRetryUrlsWithPolicy,
      inputData: {AppConstants.taskInputUrls: failedUrls},
      initialDelay: const Duration(seconds: 1),
    );

    PMlog.d('NotificationService', '重试任务已注册');
  } catch (e) {
    PMlog.e('NotificationService', '解析重试 payload 失败: $e');
  }
}

List<String> _extractFailedUrls(String payload) {
  final data = json.decode(payload) as Map<String, dynamic>;
  return (data['failedUrls'] as List?)
          ?.map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toSet()
          .toList() ??
      [];
}

/// 处理忽略 action（取消重试并标记失败）
void _handleDismissAction(String payload) async {
  try {
    final data = json.decode(payload) as Map<String, dynamic>;
    final failedUrls =
        (data['failedUrls'] as List?)
            ?.map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .toSet()
            .toList() ??
        [];

    if (failedUrls.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();

    final currentUrls =
        (prefs.getStringList(AppConstants.keyNeedCallbackUrl) ?? [])
            .where((url) => url.trim().isNotEmpty)
            .toSet();
    currentUrls.removeAll(failedUrls);
    await prefs.setStringList(
      AppConstants.keyNeedCallbackUrl,
      currentUrls.toList(),
    );

    Workmanager().initialize(callbackDispatcher, isInDebugMode: false);

    await Workmanager().registerOneOffTask(
      'url_scraper_dismiss_${DateTime.now().millisecondsSinceEpoch}',
      AppConstants.taskMarkDismissedUrlsFailed,
      inputData: {AppConstants.taskInputUrls: failedUrls},
      initialDelay: const Duration(seconds: 0),
    );

    PMlog.d('NotificationService', '已忽略并停止重试: $failedUrls');
  } catch (e) {
    PMlog.e('NotificationService', '处理忽略 action 失败: $e');
  }
}

/// 通知回调类型
typedef NotificationCallback = void Function(String? payload, String? actionId);

class NotificationService {
  static const String _tag = 'NotificationService';

  final fln.FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      fln.FlutterLocalNotificationsPlugin();

  /// 通知点击回调（前台）
  NotificationCallback? onNotificationTap;

  /// 抓取结果通知通道 ID
  static const String _scrapeChannelId = 'scrape_result_channel';
  static const String _scrapeChannelName = '抓取结果通知';

  /// 通知 ID 生成器（使用时间戳避免冲突）
  int _generateNotificationId() =>
      DateTime.now().millisecondsSinceEpoch % 100000;

  Future<void> init() async {
    tz.initializeTimeZones();
    String? timeZoneName;
    try {
      final timezoneInfo = await FlutterTimezone.getLocalTimezone();
      timeZoneName = timezoneInfo.identifier;
      PMlog.i('NotificationService', '获取到系统时区: $timeZoneName');
    } catch (e) {
      PMlog.e('NotificationService', '获取系统时区失败: $e');
    }

    try {
      if (timeZoneName != null) {
        tz.setLocalLocation(tz.getLocation(timeZoneName));
      } else {
        throw Exception('TimeZone name is null');
      }
    } catch (e) {
      PMlog.w(
        'NotificationService',
        '无法设置本地时区 ($timeZoneName), 尝试默认使用北京时间 (Asia/Shanghai)',
      );
      try {
        tz.setLocalLocation(tz.getLocation('Asia/Shanghai'));
        PMlog.i('NotificationService', '已切换到北京时间');
      } catch (e2) {
        PMlog.e('NotificationService', '设置北京时间失败, 降级使用 UTC: $e2');
        tz.setLocalLocation(tz.UTC);
      }
    }

    const fln.AndroidInitializationSettings initializationSettingsAndroid =
        fln.AndroidInitializationSettings('@mipmap/launcher_icon');

    const fln.WindowsInitializationSettings initializationSettingsWindows =
        fln.WindowsInitializationSettings(
          appName: 'pocketmind',
          appUserModelId: 'com.doublez.pocketmind',
          guid: '81984258-2100-44F4-893C-311394038165',
        );

    final fln.DarwinInitializationSettings initializationSettingsDarwin =
        fln.DarwinInitializationSettings();

    final fln.InitializationSettings initializationSettings =
        fln.InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsDarwin,
          macOS: initializationSettingsDarwin,
          windows: initializationSettingsWindows,
        );

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _handleNotificationResponse,
      onDidReceiveBackgroundNotificationResponse:
          onBackgroundNotificationResponse,
    );
  }

  /// 处理通知响应（点击通知或 action 按钮）- 前台
  void _handleNotificationResponse(fln.NotificationResponse response) {
    PMlog.d(
      _tag,
      '前台通知响应: actionId=${response.actionId}, payload=${response.payload}',
    );

    // 如果点击的是重试按钮，直接处理
    if (response.actionId == NotificationActionIds.retry &&
        response.payload != null) {
      _handleRetryAction(response.payload!);
      return;
    }

    if (response.actionId == NotificationActionIds.dismiss &&
        response.payload != null) {
      _handleDismissAction(response.payload!);
      return;
    }

    // 其他情况调用外部回调
    onNotificationTap?.call(response.payload, response.actionId);
  }

  Future<void> requestPermissions() async {
    if (Platform.isIOS || Platform.isMacOS) {
      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
            fln.IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
            fln.MacOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    } else if (Platform.isAndroid) {
      final fln.AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          flutterLocalNotificationsPlugin
              .resolvePlatformSpecificImplementation<
                fln.AndroidFlutterLocalNotificationsPlugin
              >();

      await androidImplementation?.requestNotificationsPermission();

      // 检查并请求精确闹钟权限
      await androidImplementation?.requestExactAlarmsPermission();
    }
  }

  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    bool highPrecision = false,
  }) async {
    // 0. 先检测权限检查与请求
    PermissionStatus status = await Permission.notification.status;

    if (!status.isGranted) {
      // 如果没有权限，主动请求一次 (iOS会弹窗，Android 13+会弹窗)
      status = await Permission.notification.request();

      // 如果请求后还是拒绝 (用户点了“不允许”或“不再询问”)
      if (!status.isGranted) {
        Fluttertoast.showToast(
          msg: '设置闹钟需要通知权限，请在设置中开启！',
          toastLength: Toast.LENGTH_LONG,
        );
        //打开系统设置页面
        await openAppSettings();
        return;
      }
    }

    // 1. 将输入的 DateTime (本地时间) 转换为 tz.local 时区下的 TZDateTime
    tz.TZDateTime tzDate = tz.TZDateTime.from(scheduledDate, tz.local);

    // 固定使用最高级别通知配置（用户可在系统层面调整）
    // Android: 强行弹窗、最大声音
    const fln.Importance androidImportance = fln.Importance.max;
    const fln.Priority androidPriority = fln.Priority.high;

    // iOS/macOS: 时效性通知 (TimeSensitive)，可突破专注模式
    const bool iosPresentSound = true;
    const bool iosPresentBadge = true;
    const bool iosPresentAlert = true;
    const fln.InterruptionLevel iosInterruptionLevel =
        fln.InterruptionLevel.timeSensitive;

    // Windows: 闹钟模式
    final fln.WindowsNotificationDetails windowsDetails =
        fln.WindowsNotificationDetails(
          scenario: fln.WindowsNotificationScenario.alarm,
          duration: fln.WindowsNotificationDuration.long,
        );

    const String androidChannelId = 'reminder_channel_high';
    const String androidChannelName = '提醒通知';

    try {
      await flutterLocalNotificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        tzDate,
        fln.NotificationDetails(
          // --- Android 配置 ---
          android: fln.AndroidNotificationDetails(
            androidChannelId, // 动态 ID
            androidChannelName,
            channelDescription: '闹钟定时提醒',
            importance: androidImportance,
            priority: androidPriority,
          ),

          // --- iOS / macOS 配置 ---
          iOS: fln.DarwinNotificationDetails(
            presentAlert: iosPresentAlert,
            presentBadge: iosPresentBadge,
            presentSound: iosPresentSound,
            interruptionLevel: iosInterruptionLevel, // 关键：设置中断级别
          ),
          macOS: fln.DarwinNotificationDetails(
            presentAlert: iosPresentAlert,
            presentBadge: iosPresentBadge,
            presentSound: iosPresentSound,
            interruptionLevel: iosInterruptionLevel,
          ),
          windows: windowsDetails,
          // --- Windows 配置 (功能有限) ---
          // Windows 主要是靠系统接管，代码里没有类似 Priority 的参数。
          // Linux 同理。
        ),
        androidScheduleMode: highPrecision
            ? fln.AndroidScheduleMode.alarmClock
            : fln.AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: null,
      );
      PMlog.i('NotificationService', '通知调度成功');
    } catch (e) {
      PMlog.e('NotificationService', '闹钟保存失败');
      Fluttertoast.showToast(
        msg: '闹钟保存失败',
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.CENTER,
      );
      PMlog.e('NotificationService', '调度通知失败: $e');
    }
  }

  /// 显示抓取结果通知
  ///
  /// [resultType] 抓取结果类型
  /// [successCount] 成功数量
  /// [failedCount] 失败数量
  /// [failedUrls] 失败的 URL 列表（用于重试）
  /// [errorMessage] 错误信息
  /// [contentPreviews] 内容预览列表（显示平台和内容前几个字）
  Future<void> showScrapeResultNotification({
    required ScrapeResultType resultType,
    int successCount = 0,
    int failedCount = 0,
    List<String>? failedUrls,
    String? errorMessage,
    List<String>? contentPreviews,
  }) async {
    String title;
    String body;

    switch (resultType) {
      case ScrapeResultType.success:
        title = '内容抓取成功';
        if (contentPreviews != null && contentPreviews.isNotEmpty) {
          body = contentPreviews.join('\n');
        } else {
          body = successCount > 1 ? '成功抓取 $successCount 条内容' : '内容已成功抓取并保存';
        }
        break;
      case ScrapeResultType.partialSuccess:
        title = '部分内容抓取成功';
        body = '成功 $successCount 条，失败 $failedCount 条';
        if (contentPreviews != null && contentPreviews.isNotEmpty) {
          body += '\n' + contentPreviews.join('\n');
        }
        if (errorMessage != null) {
          body += '\n$errorMessage';
        }
        break;
      case ScrapeResultType.failed:
        title = '内容抓取失败';
        if (contentPreviews != null && contentPreviews.isNotEmpty) {
          body = contentPreviews.join('\n');
          if (errorMessage != null) {
            body += '\n$errorMessage';
          }
        } else {
          body = errorMessage ?? '抓取过程中发生错误，请检查网络连接后重试';
        }
        break;
    }

    // 构建 payload（用于点击通知时处理重试）
    final payload = json.encode({
      'type': 'scrape_result',
      'resultType': resultType.name,
      'failedUrls': failedUrls ?? [],
      'canRetry': failedUrls != null && failedUrls.isNotEmpty,
    });

    await _showInstantNotification(
      id: _generateNotificationId(),
      title: title,
      body: body,
      channelId: _scrapeChannelId,
      channelName: _scrapeChannelName,
      payload: payload,
      // 失败时显示重试 action
      showRetryAction:
          resultType != ScrapeResultType.success &&
          failedUrls != null &&
          failedUrls.isNotEmpty,
    );
  }

  /// 发送即时通知（非定时）
  Future<void> _showInstantNotification({
    required int id,
    required String title,
    required String body,
    required String channelId,
    required String channelName,
    String? payload,
    bool showRetryAction = false,
  }) async {
    try {
      // Android actions（重试按钮和忽略按钮）
      List<fln.AndroidNotificationAction>? androidActions;
      if (showRetryAction && Platform.isAndroid) {
        androidActions = [
          const fln.AndroidNotificationAction(
            NotificationActionIds.retry,
            '🔄 重试',
            // false = 不打开应用，在后台触发 onDidReceiveBackgroundNotificationResponse
            showsUserInterface: false,
            cancelNotification: true, // 点击后关闭通知
          ),
          const fln.AndroidNotificationAction(
            NotificationActionIds.dismiss,
            '忽略',
            showsUserInterface: false,
            cancelNotification: true, // 点击后关闭通知
          ),
        ];
      }

      final notificationDetails = fln.NotificationDetails(
        android: fln.AndroidNotificationDetails(
          channelId,
          channelName,
          channelDescription: '显示内容抓取的结果通知',
          importance: fln.Importance.high,
          priority: fln.Priority.high,
          actions: androidActions,
        ),
        iOS: fln.DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          categoryIdentifier: showRetryAction ? 'scrape_retry' : null,
        ),
        macOS: fln.DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          categoryIdentifier: showRetryAction ? 'scrape_retry' : null,
        ),
        windows: const fln.WindowsNotificationDetails(),
      );

      await flutterLocalNotificationsPlugin.show(
        id,
        title,
        body,
        notificationDetails,
        payload: payload,
      );

      PMlog.d(_tag, '抓取结果通知已发送: $title');
    } catch (e) {
      PMlog.e(_tag, '发送抓取结果通知失败: $e');
    }
  }

  Future<void> cancelNotification(int id) async {
    await flutterLocalNotificationsPlugin.cancel(id);
  }
}
