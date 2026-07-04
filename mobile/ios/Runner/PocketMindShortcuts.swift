//
//  PocketMindShortcuts.swift
//  Runner
//
//  把 SaveToPocketMindIntent 注册成 App Shortcut,让它免配置地出现在
//  快捷指令 App / Siri / 聚焦搜索里。用户也可在快捷指令里把剪贴板接到
//  「链接」参数,实现「复制 URL → 一句话保存」。
//
//  iOS 16+;低版本不暴露。
//

import AppIntents

@available(iOS 16.0, *)
struct PocketMindShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: SaveToPocketMindIntent(),
            phrases: [
                "保存到 \(.applicationName)",
                "用 \(.applicationName) 收藏",
                "Save to \(.applicationName)"
            ],
            shortTitle: "保存到 PocketMind",
            systemImageName: "bookmark"
        )
    }
}
