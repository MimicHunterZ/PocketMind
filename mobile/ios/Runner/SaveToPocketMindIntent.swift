//
//  SaveToPocketMindIntent.swift
//  Runner
//
//  「保存到 PocketMind」快捷指令的 App Intent 定义。
//
//  交互形态(满足「不生硬跳转、做完即走、还能填信息」):
//    1. openAppWhenRun = false —— 全程不打开主 App。
//    2. URL 参数缺省时弹系统输入框让用户填(配合快捷指令把剪贴板接到这个参数,
//       即可实现「复制 URL → 跑指令」零输入)。
//    3. 备注(可选)+ 分类(从主 App 导出的 categories.json 动态取)走原生填写框。
//    4. perform() 仅把记录写进 App Group 队列,返回「已保存到 PocketMind」对话,
//       真正落库交给主 App 下次前台时排空队列(见 quick_save_bridge.dart)。
//
//  版本:App Intents 需 iOS 16+;项目部署目标 iOS 15,故整文件加 @available 守卫,
//  低版本机型上这个入口不出现,不影响主功能。
//

import AppIntents
import Foundation

// MARK: - 分类实体(填写框「选分类」用)

/// 快捷指令分类选择项。数据来源是主 App 导出到 App Group 的 categories.json,
/// 因此新建分类后需开一次主 App 才会同步到这里。
@available(iOS 16.0, *)
struct PocketMindCategoryEntity: AppEntity {
    let id: Int
    let name: String

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "分类"

    static var defaultQuery = PocketMindCategoryQuery()

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}

/// 为分类参数提供可选项与按 id 反查。所有数据从 QuickSaveQueue.readCategories() 来。
@available(iOS 16.0, *)
struct PocketMindCategoryQuery: EntityQuery {
    func entities(for identifiers: [Int]) async throws -> [PocketMindCategoryEntity] {
        let all = QuickSaveQueue.readCategories()
        return all
            .filter { identifiers.contains($0.id) }
            .map { PocketMindCategoryEntity(id: $0.id, name: $0.name) }
    }

    func suggestedEntities() async throws -> [PocketMindCategoryEntity] {
        QuickSaveQueue.readCategories()
            .map { PocketMindCategoryEntity(id: $0.id, name: $0.name) }
    }

    func defaultResult() async -> PocketMindCategoryEntity? {
        // 默认选中「home」(id=1),与 Dart 侧 AppConstants.homeCategoryId 对齐。
        let all = QuickSaveQueue.readCategories()
        return (all.first { $0.id == 1 } ?? all.first)
            .map { PocketMindCategoryEntity(id: $0.id, name: $0.name) }
    }
}

// MARK: - App Intent

@available(iOS 16.0, *)
struct SaveToPocketMindIntent: AppIntent {
    static var title: LocalizedStringResource = "保存到 PocketMind"

    static var description = IntentDescription(
        "把一个链接快速收藏到 PocketMind,可附带备注与分类。链接稍后会在打开 App 时自动抓取内容。"
    )

    /// 不拉起主 App,后台静默入队。
    static var openAppWhenRun: Bool = false

    @Parameter(
        title: "链接",
        description: "要收藏的链接;留空则在运行时询问。可在快捷指令里接入剪贴板。"
    )
    var url: String

    @Parameter(title: "备注", description: "可选的备注,会作为笔记内容。")
    var note: String?

    @Parameter(title: "分类")
    var category: PocketMindCategoryEntity?

    static var parameterSummary: some ParameterSummary {
        Summary("保存 \(\.$url) 到 PocketMind") {
            \.$category
            \.$note
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let trimmed = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return .result(dialog: "没有可保存的链接")
        }

        // 分类缺省时回落到 home(id=1)。
        let categoryId = category?.id ?? 1

        let ok = QuickSaveQueue.enqueue(
            url: trimmed,
            note: note?.trimmingCharacters(in: .whitespacesAndNewlines),
            categoryId: categoryId
        )

        guard ok else {
            return .result(dialog: "保存失败,请稍后重试")
        }
        return .result(dialog: "已保存到 PocketMind")
    }
}
