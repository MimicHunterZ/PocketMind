//
//  ShareViewController.swift
//  ShareExtension
//
//  PocketMind iOS Share Extension
//
//  与 Android `ShareActivity.kt` 功能对齐:
//    - 接收系统分享的 text / URL / 图片 / 文件
//    - 启动独立 FlutterEngine 跑 `mainShare` 入口
//    - 通过 `com.doublez.pocketmind/share` MethodChannel 把数据发给 Dart
//    - Dart 完成后调 `dismissExtension` -> 调 extensionContext.completeRequest
//
//  关键约束:
//    - Extension 进程内存上限 ~120MB (iOS 内核 jetsam 限制)
//    - main_share.dart 已实测 60-80MB,在余量内
//    - 抓取 (scraper) 不在 Extension 内执行,留给主 App ResourceFetchScheduler 续抓
//

import UIKit
import Flutter
import UniformTypeIdentifiers
// Share Extension 只手动注册分享流程真正用到的插件,而不是全量 GeneratedPluginRegistrant。
// 原因:全量注册会拉入 permission_handler / url_launcher / webview 等引用了
// [UIApplication sharedApplication] 等「扩展禁用 API」的插件,既增加内存(120MB 上限)
// 又妨碍上架审核。main_share.dart 运行时只需要本地存储与通知三件套。
import isar_community_flutter_libs
import shared_preferences_foundation
import flutter_local_notifications

class ShareViewController: UIViewController {

    // MARK: - Constants

    private static let appGroupId = "group.com.doublez.pocketmind"
    private static let shareChannelName = "com.doublez.pocketmind/share"
    private static let storageChannelName = "com.doublez.pocketmind/storage"
    private static let dartEntrypoint = "mainShare"
    private static let dartLibraryUri = "package:pocketmind/main_share.dart"

    // MARK: - State

    private var flutterEngine: FlutterEngine?
    private var flutterViewController: FlutterViewController?
    private var shareChannel: FlutterMethodChannel?

    /// Dart 端是否已发出 engineReady 信号 (与 Android ShareActivity 同协议)
    private var isEngineReady = false

    /// 引擎未就绪前先把解析好的分享数据缓存,等 engineReady 收到后再发 showShare
    private var pendingPayload: [String: Any]?

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear

        bootstrapFlutterEngine()
        parseShareItems()
    }

    // MARK: - Flutter Engine

    private func bootstrapFlutterEngine() {
        let engine = FlutterEngine(name: "share_engine")
        let started = engine.run(
            withEntrypoint: ShareViewController.dartEntrypoint,
            libraryURI: ShareViewController.dartLibraryUri
        )
        guard started else {
            NSLog("[ShareExtension] FlutterEngine 启动失败,直接关闭 Extension")
            completeRequest()
            return
        }

        // 只注册分享流程必需的插件(isar 本地库 / shared_preferences / 通知)。
        // workmanager、抓取、权限等都不在 Extension 内执行,留给主 App。
        IsarFlutterLibsPlugin.register(
            with: engine.registrar(forPlugin: "IsarFlutterLibsPlugin")!)
        SharedPreferencesPlugin.register(
            with: engine.registrar(forPlugin: "SharedPreferencesPlugin")!)
        FlutterLocalNotificationsPlugin.register(
            with: engine.registrar(forPlugin: "FlutterLocalNotificationsPlugin")!)

        // 用 engine 的 binaryMessenger 安装 channels
        let messenger = engine.binaryMessenger
        registerStorageChannel(messenger: messenger)
        registerShareChannel(messenger: messenger)

        flutterEngine = engine

        // 构建 FlutterViewController 把 Dart UI 挂到 Extension 视图层
        let controller = FlutterViewController(engine: engine, nibName: nil, bundle: nil)
        controller.view.backgroundColor = .clear
        addChild(controller)
        controller.view.frame = view.bounds
        controller.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(controller.view)
        controller.didMove(toParent: self)
        flutterViewController = controller
    }

    // MARK: - MethodChannels

    /// `getAppGroupPath` -> 返回 App Group 容器路径 (Dart util/storage_paths.dart 调用)
    private func registerStorageChannel(messenger: FlutterBinaryMessenger) {
        let channel = FlutterMethodChannel(
            name: ShareViewController.storageChannelName,
            binaryMessenger: messenger
        )
        channel.setMethodCallHandler { call, result in
            switch call.method {
            case "getAppGroupPath":
                if let url = FileManager.default.containerURL(
                    forSecurityApplicationGroupIdentifier: ShareViewController.appGroupId
                ) {
                    result(url.path)
                } else {
                    result(FlutterError(
                        code: "APP_GROUP_NOT_CONFIGURED",
                        message: "ShareExtension 未配置 App Group: \(ShareViewController.appGroupId)",
                        details: nil
                    ))
                }
            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }

    /// `engineReady` (Dart -> Native) 协商引擎就绪,与 Android 同协议
    /// `dismissExtension` (Dart -> Native) 触发 completeRequest 关闭分享 UI
    private func registerShareChannel(messenger: FlutterBinaryMessenger) {
        let channel = FlutterMethodChannel(
            name: ShareViewController.shareChannelName,
            binaryMessenger: messenger
        )
        channel.setMethodCallHandler { [weak self] call, result in
            guard let self = self else {
                result(nil)
                return
            }
            switch call.method {
            case "engineReady":
                self.isEngineReady = true
                result(nil)
                if let payload = self.pendingPayload {
                    self.pendingPayload = nil
                    self.notifyDartShowShare(payload: payload)
                }
            case "dismissExtension":
                result(nil)
                DispatchQueue.main.async {
                    self.completeRequest()
                }
            default:
                result(FlutterMethodNotImplemented)
            }
        }
        shareChannel = channel
    }

    private func notifyDartShowShare(payload: [String: Any]) {
        shareChannel?.invokeMethod("showShare", arguments: payload)
    }

    // MARK: - NSItemProvider parsing

    private func parseShareItems() {
        guard let inputItems = extensionContext?.inputItems as? [NSExtensionItem] else {
            NSLog("[ShareExtension] 无 inputItems,关闭")
            completeRequest()
            return
        }

        // 把所有 attachments 拍平成一组 NSItemProvider
        let providers: [NSItemProvider] = inputItems.flatMap { $0.attachments ?? [] }
        if providers.isEmpty {
            NSLog("[ShareExtension] 无 attachments,关闭")
            completeRequest()
            return
        }

        // 串行加载 - 大多数分享只有 1-2 个 attachments,不需要并发
        loadFirstAvailable(providers: providers, index: 0, accumulated: ShareItem())
    }

    /// 累积分享内容: title (从 contentText 来) + content (text/url 拼接) + imagePaths
    private struct ShareItem {
        var title: String = "分享内容"
        var contentLines: [String] = []
        var imagePaths: [String] = []
    }

    private func loadFirstAvailable(providers: [NSItemProvider], index: Int, accumulated: ShareItem) {
        if index >= providers.count {
            dispatchAccumulated(accumulated)
            return
        }
        let provider = providers[index]
        let next: (ShareItem) -> Void = { [weak self] updated in
            self?.loadFirstAvailable(providers: providers, index: index + 1, accumulated: updated)
        }

        if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
            provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { item, _ in
                var copy = accumulated
                if let url = item as? URL {
                    copy.contentLines.append(url.absoluteString)
                }
                next(copy)
            }
        } else if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
            provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { item, _ in
                var copy = accumulated
                if let text = item as? String {
                    copy.contentLines.append(text)
                }
                next(copy)
            }
        } else if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
            provider.loadFileRepresentation(forTypeIdentifier: UTType.image.identifier) { url, _ in
                var copy = accumulated
                if let url = url {
                    if let saved = self.copyToAppGroupTemp(sourceURL: url) {
                        copy.imagePaths.append(saved)
                    }
                }
                next(copy)
            }
        } else if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                var copy = accumulated
                if let url = item as? URL {
                    if let saved = self.copyToAppGroupTemp(sourceURL: url) {
                        copy.imagePaths.append(saved)
                    }
                }
                next(copy)
            }
        } else {
            // 类型不识别,跳过
            next(accumulated)
        }
    }

    /// 把分享带过来的临时文件拷贝到 App Group 容器,返回本地路径供 Dart 读取
    private func copyToAppGroupTemp(sourceURL: URL) -> String? {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: ShareViewController.appGroupId
        ) else {
            return nil
        }
        let inboxDir = containerURL.appendingPathComponent("share_inbox", isDirectory: true)
        try? FileManager.default.createDirectory(at: inboxDir, withIntermediateDirectories: true)

        let ext = sourceURL.pathExtension
        let filename = "\(UUID().uuidString)\(ext.isEmpty ? "" : ".\(ext)")"
        let destURL = inboxDir.appendingPathComponent(filename)
        do {
            try FileManager.default.copyItem(at: sourceURL, to: destURL)
            return destURL.path
        } catch {
            NSLog("[ShareExtension] 拷贝分享文件失败: \(error.localizedDescription)")
            return nil
        }
    }

    private func dispatchAccumulated(_ item: ShareItem) {
        let title = (extensionContext?.inputItems.first as? NSExtensionItem)?.attributedContentText?.string
            ?? item.title

        // 保留 Android 端 payload 形状: { title, content, timestamp }
        // 图片路径以换行追加到 content,Dart UrlHelper 会把 file:// 路径走图片分支
        var contentParts = item.contentLines
        contentParts.append(contentsOf: item.imagePaths.map { "file://\($0)" })
        let content = contentParts.joined(separator: "\n")

        let payload: [String: Any] = [
            "title": title,
            "content": content,
            "timestamp": Int(Date().timeIntervalSince1970 * 1000)
        ]

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if self.isEngineReady {
                self.notifyDartShowShare(payload: payload)
            } else {
                self.pendingPayload = payload
            }
        }
    }

    // MARK: - Completion

    private func completeRequest() {
        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }
}
