import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {

  /// App Group ID（Runner 与 ShareExtension 共享同一个容器，
  /// 用于跨进程共享 Isar 数据库与 pocket_images 目录）。
  /// ⚠️ 修改此处后，Xcode 两个 target 的 Capabilities → App Groups 也要同步改。
  static let appGroupId = "group.com.doublez.pocketmind"

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  /// Flutter 的隐式 Engine 启动后自动调用本方法。这里既要注册 GeneratedPluginRegistrant
  /// 让 path_provider / shared_preferences / isar 等插件生效,也要把我们自己的两个
  /// MethodChannel 挂上去 (storage / logger)。
  ///
  /// 通过 `engineBridge.pluginRegistry.registrar(forPlugin:)` 拿到 registrar,
  /// 它的 `messenger()` 就是我们要的 FlutterBinaryMessenger。
  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "PocketMindNativeChannels") {
      let messenger = registrar.messenger()
      registerStorageChannel(messenger: messenger)
      registerLoggerChannel(messenger: messenger)
    }
  }

  // MARK: - 存储路径桥接

  /// `com.doublez.pocketmind/storage` 的 `getAppGroupPath` 方法返回 App Group 容器根目录。
  /// 主 App 与 ShareExtension 都通过这个 channel 拿到同一个路径,
  /// Dart 侧 storage_paths.dart 调用此方法。
  private func registerStorageChannel(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "com.doublez.pocketmind/storage",
      binaryMessenger: messenger
    )
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "getAppGroupPath":
        if let url = FileManager.default.containerURL(
          forSecurityApplicationGroupIdentifier: AppDelegate.appGroupId
        ) {
          result(url.path)
        } else {
          result(FlutterError(
            code: "APP_GROUP_NOT_CONFIGURED",
            message: "未能获取 App Group 容器：\(AppDelegate.appGroupId)，请在 Xcode 中给 Runner 勾上对应 App Group capability。",
            details: nil
          ))
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  // MARK: - 日志桥接

  /// `com.doublez.pocketmind/logger` 的 `log` 方法把 Dart 端日志转到 NSLog,
  /// 用 Xcode 控制台 / Console.app 即可看到（与 Android `MainActivity.kt` 的 LOG_CHANNEL 等价）。
  private func registerLoggerChannel(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "com.doublez.pocketmind/logger",
      binaryMessenger: messenger
    )
    channel.setMethodCallHandler { call, result in
      if call.method == "log" {
        let args = call.arguments as? [String: Any]
        let tag = args?["tag"] as? String ?? "FlutterLog"
        let message = args?["message"] as? String ?? ""
        NSLog("[\(tag)] \(message)")
        result(nil)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
