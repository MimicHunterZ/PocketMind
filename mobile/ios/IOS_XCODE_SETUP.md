# PocketMind iOS 接手清单

> **最新进展（2026-06-30）**：主 App 与 ShareExtension 已一起编译通过并装到真机（zhe的iPhone / iOS 18.7.9）。
> 系统分享的 Flutter 引擎链接、构建循环等坑已全部打通，剩真机端到端功能验证（Safari 分享 → 弹 Flutter UI → 写入笔记）。
> 关于 macOS：已经跑通了，不用再做任何事。

---

## 当前状态

### ✅ 主 App + ShareExtension 已编译并安装到真机（2026-06-30）

- 主 App 与系统分享 Extension 一起编译、签名、安装全链路打通。
- 本次踩的所有坑和对应解法，集中记在文末「本次实战记录」，**遇到问题先翻那一节**。
- ⚠️ 免费 Apple 证书 7 天过期，过期后重跑一次安装即可续期（见第五步）。
- ⏳ 待办：真机端到端验证分享流程（见第三步「测分享」），以及若要上架需做的合规化（见实战记录）。

### ✅ 已完成（Claude 写好的）

**Dart 侧改动**：
- `lib/util/storage_paths.dart`（新增）—— iOS App Group 路径桥接
- `lib/main.dart` `lib/main_share.dart` `lib/util/image_storage_helper.dart` `lib/service/call_back_dispatcher.dart` —— 全部接入新路径
- `lib/main_share.dart` —— iOS 平台守卫（Workmanager / flutter_uri_to_file / SystemNavigator.pop）
- `pubspec.yaml` —— 移除未使用的 `share_handler`

**iOS 原生侧（已集成进构建）**：
- `ios/Runner/AppDelegate.swift` —— 注册 storage / logger MethodChannel
- `ios/Runner/Runner.entitlements`（文件已就位）—— App Group capability
- `ios/Runner/Info.plist` —— 各类 Usage Description + ATS
- `ios/ShareExtension/ShareViewController.swift` —— Extension 完整实现（启 FlutterEngine + 解析 NSItemProvider + MethodChannel）；已改为**只手动注册 isar / shared_preferences / flutter_local_notifications 三个插件**，不再用全量 GeneratedPluginRegistrant
- `ios/ShareExtension/Info.plist` —— NSExtensionActivationRule
- `ios/ShareExtension/ShareExtension.entitlements`（文件已就位）—— App Group capability


**Xcode 工程已配置**：
- Runner 与 ShareExtension 的 iOS Deployment Target 均已统一为 15.0
  （ShareExtension 用 Xcode 26.4.1 新建时被自动填成了 26.4，已修回 15.0，见下方「Claude 改过的事」）
- ShareExtension Target 已通过 Xcode UI 添加（你做的）
- `Podfile` 加了 ShareExtension target 块 + Tsinghua 镜像

### ⛔ 已知阻塞问题（已解决，记录原因）

**CocoaPods 不认 Xcode 26 的 pbxproj 格式（objectVersion=70）**：
`pod install` 报错 `Unable to find compatibility version string for object version '70'`。
根因是 `xcodeproj` 这个 gem 的版本兼容表里没有 70 这个值（Xcode 26 用的格式）。
**本次已通过给 gem 打补丁解决**，详见第一步与文末实战记录。

---

## 你要做的事（按顺序）

### 第一步：让 `pod install` 认识 objectVersion 70（已做，换机/重装需重做）

> 本机的 `pod` 实际来自 Homebrew（`/opt/homebrew/bin/pod`），系统自带的 Ruby 2.6 太老装不了新版 CocoaPods，所以 `sudo gem install` 那条路走不通——直接用 brew 这套。

真正卡住的不是 CocoaPods 版本，而是它依赖的 `xcodeproj` gem 的「objectVersion 兼容表」里没有 `70`。
官方 master 已经修了（`70 => 'Xcode 16.0'`、`71 => 'Xcode 16.2'`），只是还没发版。本次手动把这两行补进了本机 gem：

```bash
# 找到 brew cocoapods 捆绑的 xcodeproj constants.rb
CONST=$(ls /opt/homebrew/Cellar/cocoapods/*/libexec/gems/xcodeproj-*/lib/xcodeproj/constants.rb)
# 在 "77 => 'Xcode 16.0'," 这行后面补 71 和 70 两行
# 已加内容：
#   71 => 'Xcode 16.2',
#   70 => 'Xcode 16.0',
```

> ⚠️ 这个补丁在 `/opt/homebrew/...` 下，**不在 git 仓库里**。`brew upgrade cocoapods` 可能把它覆盖回去，届时 `pod install` 会再报 objectVersion 70——重新补一次即可。等 CocoaPods/xcodeproj 发新版后此步可省略。

补完后跑：
```bash
cd ~/my/PocketMind/mobile/ios
/opt/homebrew/bin/pod install
```

**期望结果**：看到 `Pod installation complete!`，没有 "Unable to find compatibility version" 报错。

> 备选「最后手段」：手动改 pbxproj 第 6 行 `objectVersion = 70;` 改成 `56`，再 `pod install`。代价是下次用 Xcode 26 打开会被改回 70，循环一次。不推荐，优先用上面的 gem 补丁。

---

### 第二步：Xcode 配 App Groups（10 分钟）

```bash
open ~/my/PocketMind/mobile/ios/Runner.xcworkspace
```

⚠️ 一定打开 **`.xcworkspace`**，不是 `.xcodeproj`。

#### 2.1 给主 App（Runner）配 App Group

1. 左侧选 Runner 蓝图标 → 中间面板选 `Runner` Target
2. 顶部 Tab：`Signing & Capabilities`
3. **Team**：选你的 Apple ID（如果没登入：Xcode → Settings → Accounts → "+"）
4. **Bundle Identifier**：保持 `com.doublez.pocketmind`
5. 点左上 **`+ Capability`** → 搜 `App Groups` → 双击添加
6. 在 App Groups 区域点 `+` → 输入 `group.com.doublez.pocketmind` → 回车
7. 确认这个 group 前面的 checkbox 是勾选状态 ✅

> Xcode 会问要不要新建 entitlements 文件——**不用新建**，我们已经有 `ios/Runner/Runner.entitlements` 了。如果 Xcode 自动创建了别的 entitlements 文件，去 Build Settings 搜 `CODE_SIGN_ENTITLEMENTS`，确认值是 `Runner/Runner.entitlements`。

#### 2.2 给 ShareExtension 配同一个 App Group

1. 左侧选中 `ShareExtension` Target
2. `Signing & Capabilities` Tab
3. **Team**：和 Runner 同一个 Team（必须一致，否则 App Group 不通）
4. **Bundle Identifier**：保持 Xcode 默认的 `com.doublez.pocketmind.ShareExtension`（或改成 `.share` 也行，都可以）
5. `+ Capability` → App Groups → 勾选 `group.com.doublez.pocketmind`
6. 确认 Build Settings 里 `CODE_SIGN_ENTITLEMENTS` = `ShareExtension/ShareExtension.entitlements`
7. 顺手在 Build Settings 搜 `iOS Deployment Target`，确认 ShareExtension 是 **15.0**（不是 26.x）。Claude 已经在 pbxproj 里改好了，这里只是复核——若被 Xcode 改回 26.x，Extension 会在普通设备上装不上。

#### 2.3 验证 ShareExtension 文件正确挂载

在 Xcode 左侧 `ShareExtension` 目录下应该能看到：
- `ShareViewController.swift` —— Claude 写的 Flutter Extension 实现（约 230 行）
- `Info.plist` —— 含 NSExtensionActivationRule 接受 text/url/image/file
- `ShareExtension.entitlements` —— App Group
- `Base.lproj/MainInterface.storyboard` —— Xcode 默认生成的，里面 customClass 指向 ShareViewController

如果 ShareViewController.swift 的内容是简单的 `SLComposeServiceViewController`（只有 `isContentValid`、`didSelectPost`、`configurationItems` 三个空方法），说明 Xcode 把 Claude 写的实现覆盖回默认模板了。重新跑：
```bash
# 让 Claude 那份重新覆盖回去（已经写在文件里了，重新打开应该就是对的）
cat ~/my/PocketMind/mobile/ios/ShareExtension/ShareViewController.swift | head -10
# 第一行应该是 //  ShareViewController.swift
# 第十行附近能看到 import Flutter
```

---

### 第三步：真机跑（已验证可行的命令）

```bash
cd ~/my/PocketMind/mobile
flutter devices   # 列出设备，记下 iPhone 的 id
```

**装 release 版（推荐，桌面能直接点开用）**：
```bash
flutter run -d <设备-id> --release --no-resident
```
- `--release`：debug 版受 iOS 14+ 限制，装上后只能从 flutter 工具启动、不能从桌面点开；release 版没这限制。
- `--no-resident`：装完即退出，不挂在前台热重载。
- 如果 `flutter run` 报 `Build succeeded but ... Runner.app not found`（偶发的路径误判），产物其实已在 `build/ios/iphoneos/Runner.app`，直接补一条安装即可：
  ```bash
  flutter install -d <设备-id> --release
  ```
- 验证是否装上：
  ```bash
  xcrun devicectl device info apps --device <设备-id> | grep doublez
  # 看到 com.doublez.pocketmind 即成功
  ```

> ⛔ **别用 `flutter build ios --no-codesign` 的产物去 `flutter install`**：那是未签名产物，真机验签会失败报
> `Failed to verify code signature ... 0xe8008014 (invalid signature)`。要装真机就走上面带签名的 `flutter run`。

#### 真机首次会失败
- 错误："Untrusted Developer" 或 "Could not launch"
- 修复：iPhone → 设置 → 通用 → VPN 与设备管理 → 找到你的 Apple ID 证书 → 点信任
- 然后再跑一次安装

#### 免费证书「最多 3 个 App」限制
- 报错：`This device has reached the maximum number of installed apps using a free developer profile`
- 免费 Apple ID 同一台设备最多装 3 个该证书签名的 App。删掉 iPhone 上一个不用的（常见的占位：WebDriverAgent、各种 Sample 调试 App）腾出名额再装。

#### 测分享
1. 真机 Safari 打开任意网页
2. 点分享按钮（方框上箭头）
3. 在分享面板列表里左右滑找 **"保存到 PocketMind"**
4. 点击 → 应该弹出透明卡片显示你的 Flutter 分享 UI（`ShareSuccessPage`，"Good find!" 那个）
5. 卡片关闭后，**重新打开主 App**，应该能看到刚保存的笔记

---

### 第四步：调试（如果出问题）

#### 看不到"保存到 PocketMind"在分享面板里
- 需要长按 / 滑动找到底部 "更多" → 编辑 → 开启 "保存到 PocketMind"
- 如果连开启选项都没有，是 ShareExtension 没装上：检查 Xcode build 时 `Embed Foundation Extensions` 阶段有没有把 ShareExtension.appex 嵌进 Runner.app

#### Extension 启动后立刻闪退
- Xcode 顶部 Scheme 切到 **`ShareExtension`**（不是 Runner），按 `Cmd+R` 跑
- 选 `Choose an app to run` → 选 Safari
- Xcode 会附加调试器到 Extension 进程
- 看 console 错误信息
- 常见原因：
  - **内存超 120MB 被 jetsam 杀**：Debug Navigator → Memory 监控峰值。`main_share.dart` 实测 60-80MB，超的话查最近改动有没有引入大依赖
  - **App Group 没配通**：日志里能看到 `APP_GROUP_NOT_CONFIGURED`，回去检查两个 Target 是不是都勾了同一个 group 且同一个 Team
  - **Flutter framework 没链接**：日志里 `dyld: Library not loaded: Flutter.framework`，回去检查 Podfile 里 `target 'ShareExtension'` 块在不在，跑 `pod install`

#### 主 App 看不到 Extension 写的笔记
- 启动主 App 时看 Xcode console，应该有日志：`图片存储根目录已初始化: /private/var/mobile/Containers/Shared/AppGroup/...`
- 如果路径开头是 `/var/mobile/Containers/Data/Application/...`（不含 `Shared/AppGroup`），说明 App Group 没生效
- 检查清单：
  - Runner 和 ShareExtension 都开了 App Groups capability
  - 都勾的是同一个 ID `group.com.doublez.pocketmind`
  - Team ID 一致
  - 两个 entitlements 文件都被挂上了（Build Settings → CODE_SIGN_ENTITLEMENTS）

#### 免费 Apple ID 7 天过期
- iPhone 上 App 突然打不开提示"开发者证书已过期"
- 重新跑一次 `flutter run` 续 7 天
- 永久方案：付费 $99/年 Apple Developer Program 或用 AltStore 自动续签

---

### 第五步：发 GitHub Release（最后一步）

```bash
cd ~/my/PocketMind/mobile
fvm flutter build ipa --release
# 输出：build/ios/ipa/pocketmind.ipa
```

把 IPA 上传到 GitHub Release。用户用 [AltStore](https://altstore.io/) 装：

1. 用户电脑装 AltServer + iPhone 装 AltStore
2. AltStore → My Apps → "+" → 选你的 IPA
3. 输入用户自己的 Apple ID
4. AltStore 用用户 Team ID 重签整个 IPA（Runner + ShareExtension 一起重签，App Group 自动重写不会失配）
5. 安装完成，每 7 天 AltStore 自动续签

---

## 速查：所有写好的文件位置

| 文件 | 作用 |
|---|---|
| `lib/util/storage_paths.dart` | App Group 路径桥接（新增） |
| `lib/main.dart` `lib/main_share.dart` `lib/util/image_storage_helper.dart` `lib/service/call_back_dispatcher.dart` | 接入新路径 |
| `ios/Runner/AppDelegate.swift` | 主 App 注册 storage / logger Channel |
| `ios/Runner/Runner.entitlements` | 主 App App Group |
| `ios/Runner/Info.plist` | Usage Description + ATS |
| `ios/ShareExtension/ShareViewController.swift` | Extension 完整实现 ⭐ |
| `ios/ShareExtension/Info.plist` | NSExtensionActivationRule |
| `ios/ShareExtension/ShareExtension.entitlements` | Extension App Group |
| `ios/Podfile` | 含 ShareExtension target + Tsinghua 镜像 |
| `~/.zshrc` | 已加 `PUB_HOSTED_URL` `FLUTTER_STORAGE_BASE_URL` 国内镜像 |

---

## Claude 改过但你可能想知道的事

1. **`ios/Runner.xcodeproj/project.pbxproj` 的 `objectVersion`**：曾经被改成 56（试图绕过 cocoapods 兼容问题），**已恢复成 70**。
2. **iOS Deployment Target**：Runner 从 13.0 提到 15.0（`workmanager_apple` 要求）。**ShareExtension 用 Xcode 26.4.1 新建时被自动填成了 26.4**（Debug/Release/Profile 三个 config 都是），这会导致 Extension 只能装在 iOS 26.4+ 设备上、绝大多数真机上「保存到 PocketMind」直接不出现——**已全部修回 15.0**。如果以后在 Xcode 里重建/重配 Extension，记得回 Build Settings 搜 `IPHONEOS_DEPLOYMENT_TARGET` 确认 ShareExtension 仍是 15.0。
3. **`~/.zshrc`**：加了三行 Flutter / Pub 国内镜像 env vars，本机所有 Flutter 项目都受益。
4. **`mobile/macos/Podfile`** + **`mobile/ios/Podfile`**：加了 Tsinghua 镜像 source 行。

如果想看完整改动列表：
```bash
cd ~/my/PocketMind
git status
git diff mobile/ios/Runner.xcodeproj/project.pbxproj
```

---

## 本次实战记录（2026-06-30）

按发生顺序记录这次从「pod install 报错」到「主 App + ShareExtension 一起装上 iPhone」踩过的坑，方便复现/排查。

| # | 现象 | 根因 | 解法 |
|---|---|---|---|
| 1 | ShareExtension 只能装 iOS 26.4+ | Xcode 26.4.1 新建 target 时把 Deployment Target 自动填成 26.4 | pbxproj 里三个 config 全改回 15.0 |
| 2 | `pod install` 报 objectVersion 70 | `xcodeproj` gem 兼容表缺 70 | 给 brew gem 的 `constants.rb` 补 `70`/`71` 两行（见第一步） |
| 3 | 3 条 `CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER` warning | Xcode 新建 Extension 自带的设置与 Pods 注入冲突 | 删掉 ShareExtension 三个 config 里这条设置 |
| 4 | 编译报 `'sharedApplication' is unavailable (App Extension)` | Extension 复用了主 App 全部插件，`permission_handler` 用了 Extension 禁用的 API | Podfile `post_install` 加 `APPLICATION_EXTENSION_API_ONLY = NO` |
| 5 | Extension 编译报 `Unable to resolve module 'Flutter'` | ShareExtension target 的搜索路径里没有 Flutter 引擎（主 App 是靠 Run Script 把 Flutter.framework 拷进 BUILT_PRODUCTS_DIR，Extension 没这阶段） | Podfile `post_install` 给 `Pods-ShareExtension.*.xcconfig` 追加指向 **extension_safe 引擎** 的 `FRAMEWORK_SEARCH_PATHS[sdk=*]` + `OTHER_LDFLAGS = -framework Flutter` |
| 6 | Extension 编译报 `Unable to resolve module 'FlutterPluginRegistrant'` | 该模块在本工程根本不存在；Runner 是靠 bridging header `#import "GeneratedPluginRegistrant.h"` 用的，不是 import 模块 | 改 `ShareViewController.swift`：删掉 `import FlutterPluginRegistrant` 与全量 `GeneratedPluginRegistrant.register`，改成只 `import` + 手动注册 isar / shared_preferences / flutter_local_notifications 三个插件 |
| 7 | 编译报 `Sandbox: bash deny file-write-create .../resources-to-copy-ShareExtension.txt` | Xcode 26 新建 Extension 默认 `ENABLE_USER_SCRIPT_SANDBOXING = YES`，挡住 CocoaPods 的 Copy Resources 脚本 | pbxproj 里 ShareExtension 三个 config 改成 `NO`（与 Runner 一致） |
| 8 | 编译报 `Cycle inside Runner; building could produce unreliable results` | Embed Extension 的 appex 拷贝排在 CP 脚本之后，与 Thin Binary（其 input 含 Runner.app/Info.plist）+ Info.plist 处理形成依赖环 | 两步双保险：① 移除 Thin Binary 阶段的 `${TARGET_BUILD_DIR}/${INFOPLIST_PATH}` input；② 把 `Embed Foundation Extensions` 阶段移到 `Embed Frameworks` 之后、`Thin Binary` 之前（用 `xcodeproj` gem 改） |
| 9 | 真机安装报 `0xe8008014 invalid signature`（`objective_c.framework`） | 反复 `--no-codesign` build 在 `build/` 留下 adhoc 签名脏产物，被 `flutter run` 复用 | `flutter clean` + `pod install` 后走纯净 `flutter run --release` |
| 10 | 安装报 `maximum number of installed apps` | 免费证书一台设备最多 3 个 App | 删掉一个不用的腾名额 |
| 11 | debug 版桌面打不开（黑屏提示只能从工具启动） | iOS 14+ 对 debug 版 Flutter 的限制 | 改用 `--release` 安装 |

### ShareExtension 嵌 Flutter 引擎：最终怎么通的

核心三处改动（都在 `ios/Podfile` 的 `post_install` 和 `ShareViewController.swift` / pbxproj）：

1. **引擎链接**（解决 #5）：`post_install` 里遍历 `Pods-ShareExtension` 聚合 target，向它的三个 xcconfig 追加：
   ```
   FRAMEWORK_SEARCH_PATHS[sdk=iphoneos*]      = $(inherited) "<flutter_root>/bin/cache/artifacts/engine/ios/extension_safe/Flutter.xcframework/ios-arm64"
   FRAMEWORK_SEARCH_PATHS[sdk=iphonesimulator*] = $(inherited) "<flutter_root>/.../extension_safe/Flutter.xcframework/ios-arm64_x86_64-simulator"
   OTHER_LDFLAGS = $(inherited) -framework Flutter
   ```
   用 **extension_safe** 引擎（不是普通 `ios/Flutter.xcframework`）——它用 `APPLICATION_EXTENSION_API_ONLY=YES` 编译、不引用扩展禁用 API。运行时 Extension 通过 `@executable_path/../../Frameworks` rpath 加载宿主 App 里那份 `Flutter.framework`，所以 appex 本身只有 364K、不带引擎。
2. **插件精简注册**（解决 #6）：Extension 只手动注册 isar / shared_preferences / flutter_local_notifications，不用全量 GeneratedPluginRegistrant。这样既省内存又避开扩展禁用 API。
3. **构建顺序 / 沙盒**（解决 #7、#8）：关掉 ShareExtension 的脚本沙盒；调整 Runner 的 build phase 顺序断开依赖环。

> ⚠️ 这些 pbxproj 改动（#7 沙盒、#8 顺序）写在 `Runner.xcodeproj/project.pbxproj`，`pod install` / `flutter build` 不会重写它们，所以一次改动持久有效。但若有人重跑 `flutter create` 或在 Xcode 里重建 Extension target，需要重新做。Podfile 的 `post_install` 注入是每次 `pod install` 自动重放的，无需手动。

### 待办：上架 App Store 的合规化（当前是侧载折中）

当前为求快速跑通，用了 `APPLICATION_EXTENSION_API_ONLY = NO`（#4）。这能侧载 / AltStore 安装，但 App Store 审核会因 .appex 引用扩展禁用 API 被拒。要上架需：
- 确认 Extension 真的只链接 extension_safe 引擎与那 3 个安全插件；
- 把 `APPLICATION_EXTENSION_API_ONLY` 调回 `YES`，逐个解决暴露出来的禁用 API 链接错误。
（个人侧载用不影响，可暂时不管。）

### 本机环境备忘
- Xcode：26.4.1（Build 17E202）
- Flutter：3.41.8（经 fvm 管理，`~/fvm/versions/3.41.8`）
- `pod`：来自 Homebrew（`/opt/homebrew/bin/pod`，1.16.2，已手工补 xcodeproj gem）
- 真机：zhe的iPhone / iOS 18.7.9，Team `F2GPBS33F5`，Bundle `com.doublez.pocketmind`（Extension：`com.doublez.pocketmind.ShareExtension`）
- 改 pbxproj 用的 `xcodeproj` gem 跑法（brew ruby 需指定 RUBYLIB）：
  ```bash
  XCPROJ_LIB=$(ls -d /opt/homebrew/Cellar/cocoapods/*/libexec/gems/xcodeproj-*/lib | head -1)
  # 连同 nanaimo/claide/colored2/atomos 的 lib 一起拼进 RUBYLIB,再 /opt/homebrew/opt/ruby/bin/ruby 跑
  ```
