import 'package:flutter_local_notifications/flutter_local_notifications.dart'
    as fln;
import 'package:fluttertoast/fluttertoast.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:pocketmind/util/logger_service.dart';
import 'dart:io';

class NotificationService {
  final fln.FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      fln.FlutterLocalNotificationsPlugin();

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
      onDidReceiveNotificationResponse:
          (fln.NotificationResponse notificationResponse) async {
            // Handle notification tap
          },
    );
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

  Future<void> cancelNotification(int id) async {
    await flutterLocalNotificationsPlugin.cancel(id);
  }
}
