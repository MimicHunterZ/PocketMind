# iOS 快捷指令「保存到 PocketMind」实现进度

> 适用范围：iOS 端「不打开主 App、不跳转，复制 URL → 一键收藏到 PocketMind」的快捷入口。
>
> 背景诉求：iOS 不支持系统分享调起时（或不想走系统分享面板时），用户复制 URL 后能通过一个快捷入口直接把链接收藏进来，等价于安卓「下拉状态栏快捷开关 + 读剪贴板」的体验。
>
> 本文档是该功能的设计与进度源文件。涉及代码：`mobile/ios/Runner/QuickSaveQueue.swift`、`SaveToPocketMindIntent.swift`、`PocketMindShortcuts.swift`、`mobile/lib/util/quick_save_bridge.dart`、`mobile/lib/main.dart`。

---

## 1. 关键平台事实（决定整个方案形态）

这些是 iOS 的硬限制，是所有设计取舍的根因：

1. **iOS 不允许 App 主动调起自己的 ShareExtension**。安卓那套「QSTile / 快捷方式 → 拉起透明 ShareActivity 浮层」在 iOS 上走不通——`main_share` 在 iOS 跑在独立的 ShareExtension 进程（120MB 上限），只有系统分享能拉起它。
2. **iOS 不允许第三方 App 在别的 App 上画浮层**。那套半透明流动背景 + `EditNotePage` / `ShareSuccessPage` 的浮层是系统分享的专属特权，快捷指令 / 控制中心 / 长按图标都拿不到。
3. **App Intents（快捷指令）能做到「不跳转、做完即走、还能填信息」**：
   - `openAppWhenRun = false` → 全程不打开主 App，后台执行。
   - `@Parameter` + 系统输入框 → 跑指令时可弹**原生 SwiftUI** 填写框（填备注 / 选分类），但**不是** Flutter 的 `EditNotePage`。
   - 触发入口（一次定义、自动生效）：快捷指令 App、Siri、聚焦搜索（屏幕中间下拉）、轻点背面、操作按钮（仅带实体键机型）。
4. **App Intents 需 iOS 16+**；**控制中心控件（ControlWidget）需 iOS 18+**。项目部署目标 iOS 15，故 Swift 代码用 `@available` 守卫，低版本不暴露入口、不影响主功能。

---

## 2. 已确定的方案

**App Intents 快捷指令 + 原生 SwiftUI 填写框（备注 / 分类）+ `openAppWhenRun=false` 不跳转 + 轻量 App Group 队列落库。**

### 数据流

```
复制 URL → 跑快捷指令 (openAppWhenRun=false，不开 App)
  → SwiftUI 填写框：可填「备注」、选「分类」(分类从 App Group 的 categories.json 读)
  → 原生把 {url, note, categoryId, ts} 追加写进 App Group 队列文件 quick_save_queue.json
  → 系统飘「已保存到 PocketMind」→ 结束，全程不跳 App
  ⋯ 下次主 App 启动/前台 → 排空队列 → addNote(PENDING) → ResourceFetchScheduler 自动抓取+AI
```

### 为什么用「轻量队列」而非「无头 Flutter 引擎直写 Isar」

快捷指令进程为了 `openAppWhenRun=false` 不拉起主 App，无法直接写 Isar（Isar 由主 App 的 Flutter 引擎持有）。两条路里选了轻量队列：

- **轻量队列（采用）**：纯 Swift 写 App Group JSON，几乎不吃内存、无 120MB 风险、代码量最小。代价：笔记延迟到主 App 下次打开才真正入库——但抓取本就延迟到主 App 做，体验一致。
- 无头 Flutter 引擎直写 Isar（未采用）：笔记立刻入库，但重、要扛同样内存上限、复杂。

---

## 3. 已完成的代码（✅ 第一阶段：快捷指令 + 填写框，已落地）

### 新增文件

| 文件 | 作用 |
|---|---|
| `mobile/ios/Runner/QuickSaveQueue.swift` | App Group 队列读写：`enqueue` 追加 `{url,note,categoryId,ts}` 到 `quick_save_queue.json`（`NSFileCoordinator` 协调 + 原子写）；`readCategories` 读 `categories.json` 供填写框展示，读不到回落到默认 home 分类 |
| `mobile/ios/Runner/SaveToPocketMindIntent.swift` | App Intent 本体：`openAppWhenRun=false`，参数 链接 / 备注 / 分类；分类走 `PocketMindCategoryEntity` + `PocketMindCategoryQuery`（`EntityQuery`）从 categories.json 动态取；`perform()` 仅入队并返回「已保存到 PocketMind」对话。整文件 `@available(iOS 16.0, *)` |
| `mobile/ios/Runner/PocketMindShortcuts.swift` | `AppShortcutsProvider`，注册短语「保存到 PocketMind」「Save to PocketMind」，自动出现在快捷指令 App / Siri |
| `mobile/lib/util/quick_save_bridge.dart` | Dart 桥接：`exportCategories` 把分类写成 `categories.json`；`drainQuickSaveQueue` 读队列逐条 `addNote(url→PENDING)` 后清空。两方法均 `if (!Platform.isIOS) return` 守卫 |

### 改动文件

| 文件 | 改动 |
|---|---|
| `mobile/ios/Runner.xcodeproj/project.pbxproj` | 三个新 Swift 文件加入 Runner target 编译（`plutil -lint` 通过）。文件引用 ID 用 `DDDDDDDDDDDDDDDDDDDD000x` 占位 |
| `mobile/lib/main.dart` | 加 `quick_save_bridge` / `category_providers` import；`initState` 的 postFrame 回调里**先** `drainQuickSaveQueue` + `exportCategories`，**再** `runNow()`；`didChangeAppLifecycleState(resumed)` 里改为 `_drainQuickSave().whenComplete(() => runNow())`。非 iOS 下排空/导出是 no-op，既有顺序与行为不变 |

### 落库接口对齐（已核对）

- `NoteService.addNote({title, content, url, categoryId = homeCategoryId, ...})`：带 `url` 时自动把 `resourceStatus` 置 PENDING。
- `CategoryService.getAllCategories()` → `List<Category>`，导出时过滤 `id != null && !isDeleted`。
- `AppConstants.homeCategoryId = 1` / `homeCategoryName = 'home'`，与 Swift 侧默认分类回落对齐。
- 主 App 启动 / 回前台已有 `ResourceFetchScheduler.runNow()` 入口，排空后的 PENDING 笔记本轮即被扫到。

### 验证状态

- `flutter analyze lib/main.dart lib/util/quick_save_bridge.dart` → No issues。
- `plutil -lint project.pbxproj` → OK。
- ⚠️ **尚未在 Xcode 真机编译验证**；需真机测试快捷指令端到端。

---

## 4. 测试方式（第一阶段）

真机（iPhone XS / iOS 18.7.9，已连）：

1. Xcode 把新代码编译安装到真机。
2. 打开「快捷指令」App → 搜 / 图库里找到「保存到 PocketMind」→ 确认存在（系统索引有几秒~几分钟延迟，搜不到可锁屏解锁 / 重启）。
3. 复制一个链接 → 跑「保存到 PocketMind」→ 弹填写框填链接 / 备注 / 选分类 → 看到「已保存到 PocketMind」且**未跳转**。
4. 打开主 App → 确认该链接成为一条新笔记并开始抓取。

进阶（复制完零输入）：快捷指令 App 里组「获取剪贴板 → 保存到 PocketMind（链接=剪贴板）」存成「收藏剪贴板」，再绑到下方入口。

### 可用的「按一下就跑」入口（按本机 iPhone XS / iOS 18.7.9 实情）

| 入口 | 本机可用 | 配置 |
|---|---|---|
| 加到主屏幕图标 | ✅ | 快捷指令长按 → 添加到主屏幕 |
| Siri 语音 | ✅ | 0 配置 |
| **轻点背面（Back Tap）** | ✅（主推） | 设置 → 辅助功能 → 触控 → 轻点背面 → 轻点两下 → 选「保存到 PocketMind」 |
| 操作按钮（实体键） | ❌ | iPhone XS 无实体动作键，仅 15 Pro / 16 / 17 系列有 |
| 控制中心控件（右上角下拉） | 系统支持(iOS18)但**代码未做** | 见第 5 节 |

---

## 5. 待定 / 下一阶段：控制中心控件（ControlWidget）

**用户意向：要做**（iPhone XS 可升级到 iOS 18，用户设备升级即可用）。**尚未开工。**

### 关键限制（会改变交互形态）

- ControlWidget 必须用**原生 SwiftUI** 写，Flutter 渲染不进控制中心；不跑 Flutter 引擎，无 120MB 坑。
- 控件点击触发的 Intent 若 `openAppWhenRun=false`，**系统不允许弹填写框**——控制中心控件追求「一按即走、零交互」。故控件形态只能是：**点方块 → 直接读剪贴板 URL → 存默认 home 分类的 PENDING → 完**。要填备注 / 选分类仍走轻点背面绑的快捷指令。

### 计划改动

| 改动 | 说明 |
|---|---|
| 新建 Widget Extension target | 控件必须独立成 target，不能塞进 Runner |
| 新增 `ControlWidget` Swift 文件 | `ControlWidgetButton` 形态，触发一个静默 Intent |
| 新增「无填写框」静默 Intent | 直接读剪贴板，复用 `QuickSaveQueue.enqueue`；`@available(iOS 18)` |
| 配 App Group + 部署目标 + 签名 | 新 target 勾同一 App Group；部署目标手动改回 15.0；控件代码 `@available(iOS 18)` 守卫 |

### 必须注意的现实成本（来自 iOS 构建记忆）

1. **免费证书一台设备最多 3 个 App**：主 App + ShareExtension 已占 2 个，再加 Widget Extension 正好顶满，之后再加 Extension 需付费账号。
2. 加新 target 后大概率要重跑 `pod install`，可能触发 **objectVersion 70** 已知报错，需重打 `xcodeproj` gem 补丁（见 `ios-build-toolchain-quirks` 记忆 / `IOS_XCODE_SETUP.md`）。
3. 新 target 部署目标会被 Xcode 自动填成 26.4，**必须手动改回 15.0**。
4. pbxproj 手改完整 target 比加文件复杂，改后 `plutil -lint` 校验，最终须在 Xcode 编译验证。

### 下一步待确认的问题（已问未答）

- 控件交互：确认走「读剪贴板静默存」（唯一可行形态）。
- 是否现在做：明白上述成本后是否立即动手，还是先用轻点背面 + 快捷指令 App 跑一阵。

---

## 6. 不改动的部分

- ShareExtension、`main_share.dart`、Android 侧 QSTile / ShareActivity 全部不动。
- 抓取 / AI 分析链路复用现有 `ResourceFetchScheduler`，零改动。
- 工作区里 `AppDelegate.swift`、`logger_service.dart`、`Runner.xcscheme` 的 modified 状态是之前 iOS 分享工作的残留，本功能未触碰。
