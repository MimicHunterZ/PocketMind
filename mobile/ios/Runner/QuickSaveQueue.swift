//
//  QuickSaveQueue.swift
//  Runner
//
//  快捷指令「保存到 PocketMind」的 App Group 桥接工具。
//
//  设计背景:
//    - App Intent 运行在主 App 进程之外的一个轻量进程里,且我们刻意让它
//      openAppWhenRun = false(不拉起主 App),所以它 *无法* 直接写 Isar
//      (Isar 是主 App 的 Flutter 引擎持有的)。
//    - 因此 Intent 只把 {url, note, categoryId, ts} 追加写进 App Group 容器里的
//      一个 JSON 队列文件;主 App 下次启动 / 前台时由 Dart 侧 quick_save_bridge.dart
//      排空队列 → addNote(PENDING) → ResourceFetchScheduler 自动续抓。
//    - 提醒时间不走这条队列:闹钟必须在跑指令的这一刻就注册进系统,等主 App
//      排空才注册等于永远迟到,所以 scheduleReminder 直接原生调 UNUserNotificationCenter。
//    - 分类列表反过来由主 App 导出成 categories.json 放进同一容器,供填写框展示。
//
//  与 ShareExtension 共享同一个 App Group(group.com.doublez.pocketmind)。
//

import Foundation
import UserNotifications

/// App Group 容器内,快捷指令与主 App 之间交换数据的两个文件名。
enum QuickSaveStore {
    static let appGroupId = "group.com.doublez.pocketmind"
    static let queueFileName = "quick_save_queue.json"
    static let categoriesFileName = "categories.json"
}

/// 一条待落库的快捷保存记录。字段命名与 Dart 侧 quick_save_bridge.dart 解析保持一致。
struct QuickSaveItem: Codable {
    let url: String
    let note: String?
    let categoryId: Int
    /// 毫秒时间戳,保持与 Android share payload 的 timestamp 同形状。
    let timestamp: Int
}

/// 供填写框展示的分类(主 App 导出)。
struct QuickSaveCategory: Codable {
    let id: Int
    let name: String
}

/// App Group 队列读写。所有方法都做了 best-effort 容错:
/// 容器拿不到 / 文件损坏时不抛异常,返回空或静默失败,避免快捷指令崩在用户面前。
enum QuickSaveQueue {

    /// App Group 容器根目录。未配置 App Group capability 时返回 nil。
    private static var containerURL: URL? {
        FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: QuickSaveStore.appGroupId
        )
    }

    private static var queueURL: URL? {
        containerURL?.appendingPathComponent(QuickSaveStore.queueFileName)
    }

    private static var categoriesURL: URL? {
        containerURL?.appendingPathComponent(QuickSaveStore.categoriesFileName)
    }

    // MARK: - 入队(快捷指令侧写)

    /// 把一条记录追加进队列文件。返回是否成功。
    ///
    /// 用 NSFileCoordinator 协调写入,避免主 App 正在排空(读+删)时与本次 append
    /// 撞车导致 JSON 损坏。
    @discardableResult
    static func enqueue(url: String, note: String?, categoryId: Int) -> Bool {
        guard let queueURL = queueURL else { return false }

        let item = QuickSaveItem(
            url: url,
            note: note,
            categoryId: categoryId,
            timestamp: Int(Date().timeIntervalSince1970 * 1000)
        )

        var coordinatorError: NSError?
        var success = false
        let coordinator = NSFileCoordinator()
        coordinator.coordinate(
            writingItemAt: queueURL,
            options: .forMerging,
            error: &coordinatorError
        ) { writeURL in
            var items = readItems(at: writeURL)
            items.append(item)
            guard let data = try? JSONEncoder().encode(items) else { return }
            do {
                try data.write(to: writeURL, options: .atomic)
                success = true
            } catch {
                NSLog("[QuickSaveQueue] 写队列失败: \(error.localizedDescription)")
            }
        }
        if let coordinatorError = coordinatorError {
            NSLog("[QuickSaveQueue] 文件协调失败: \(coordinatorError.localizedDescription)")
        }
        return success
    }

    /// 读出队列文件里现有的记录;文件不存在或损坏时返回空数组。
    private static func readItems(at url: URL) -> [QuickSaveItem] {
        guard let data = try? Data(contentsOf: url), !data.isEmpty else { return [] }
        return (try? JSONDecoder().decode([QuickSaveItem].self, from: data)) ?? []
    }

    // MARK: - 提醒通知(快捷指令跑的这一刻直接注册,不等主 App 排空)

    /// 直接用 UNUserNotificationCenter 注册本地提醒。
    ///
    /// 用户设提醒的目的就是"闹钟响之前不用管它",所以不能像笔记落库那样
    /// 等主 App 下次打开才处理——那样等于闹钟永远迟到。跟主 App 里
    /// NotificationService.scheduleNotification 是同一套系统机制(本地通知),
    /// 只是把注册时机提前到这里,且不走 permission_handler(那层检查在
    /// App Intent 进程里不可靠),权限已授予时直接生效,未授予时静默失败。
    static func scheduleReminder(date: Date, title: String, body: String) {
        guard date.timeIntervalSinceNow > 0 else { return }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: date
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(
            identifier: "quicksave_reminder_\(Int(date.timeIntervalSince1970 * 1000))",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in
            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    NSLog("[QuickSaveQueue] 提醒注册失败: \(error.localizedDescription)")
                }
            }
        }
    }

    // MARK: - 分类(主 App 导出,填写框读)

    /// 读主 App 导出的分类列表。读不到时返回仅含「home」默认分类的兜底,
    /// 保证填写框至少有一个可选项。
    static func readCategories() -> [QuickSaveCategory] {
        guard let categoriesURL = categoriesURL,
              let data = try? Data(contentsOf: categoriesURL),
              let categories = try? JSONDecoder().decode([QuickSaveCategory].self, from: data),
              !categories.isEmpty
        else {
            return [QuickSaveCategory(id: 1, name: "home")]
        }
        return categories
    }
}
