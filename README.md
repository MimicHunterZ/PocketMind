<div align="center">

# 🧠 PocketMind
### 无感收藏，灵感汇聚之处
Your Second Brain, One Tap Away.

[![Flutter](https://img.shields.io/badge/Built%20with-Flutter-02569B.svg)](https://flutter.dev)
[![Spring AI](https://img.shields.io/badge/Powered%20by-Spring%20AI-green.svg)](https://spring.io/projects/spring-ai)
[![Status](https://img.shields.io/badge/Status-Active%20Development-orange)]()
[![License: CC BY-NC-SA 4.0](https://img.shields.io/badge/License-CC%20BY--NC--SA%204.0-lightgrey.svg)](https://creativecommons.org/licenses/by-nc-sa/4.0/)

[功能特性] • [快速开始] • [开发初衷]

</div>

---

## 💥 不要让你的收藏夹一直吃灰”

**你是否经历过这样的时刻？**

* 在 B站 收藏了教程，在 小红书 点赞了攻略，在 浏览器 保存了文章……
* **但是**，当你真正需要用到它们时，却想不起来到底把它“丢”在了哪个 App 的角落里。
* 为了保存一个链接，你需要复制、切换 App、粘贴、保存……繁琐的操作让你最终选择了放弃。

**如果不去回顾，收藏就毫无意义。**

**PocketMind** 的诞生就是为了终结这种碎片化的混乱。它不仅仅是一个书签工具，更是你数字生活的**中央处理器**。无需跳出当前应用，无需繁琐操作，一个“转发”，万物归一。

---

## ✨ 核心魔法

### 🚀 1. 极致的无感记录
不需要复制链接，不需要打开 PocketMind。
在任何 App (Bilibili, 小红书, X...) 中点击 **“分享”** -> 选择 **PocketMind**。
这就是全部。在后台，PocketMind已经为您解析了标题、封面和摘要。

> *⚡️ Be lazy. Just share it.*

### 🎨 2. 赏心悦目的记忆流
告别枯燥的列表。PocketMind 采用**瀑布流** 设计。
您的每一次收藏都以精美的图文卡片呈现，浏览笔记不再是查找资料，而是一种视觉享受。

### 🧠 3. AI 驱动的第二大脑 (Coming Soon)
*这不仅仅是一个存储容器。* 我们正在构建基于 **Spring AI Alibaba** 的智能后端：
* **自动摘要**：太长不看？AI 帮你总结核心要点。
* **智能关联**：自动发现你笔记之间的隐形联系。
* **主动提醒**：基于你的喜好，在合适的时间唤醒沉睡的记忆。

---

## 📱 预览
### 如何快速分享（两种方式分享）？

如果没有提供直接分享到应用入口的app（如小红书）可以添加分享到 PocketMind 的快捷方式，复制链接后点击进行分享即可：

[https://github.com/user-attachments/assets/85860a47-1291-40d2-8380-09b5f2d94775](https://github.com/user-attachments/assets/e0662d10-2aa6-4c4b-963e-46e8c9cb1750)


如果提供了分享链接到应用的app，可以直接选择 PocketMind 即可分享啦：

https://github.com/user-attachments/assets/67c92ac7-dd09-41ac-a08a-35ee215b5ee4

### 如何抓取数据？
目前一共有四种策略，逐级递减
1. 参考 [MediaCrawler](https://github.com/NanmiCoder/MediaCrawler) 的爬虫策略，进行 dart 的无头浏览器版本实现，目前实现了小红书、知乎的抓取，此为最完整的抓取
<img width="349" height="717" alt="image" src="https://github.com/user-attachments/assets/5a165a31-8bda-4bc0-9e33-89d364832e21" />

2. 后端进行抓取，此流程目前是负责抓取 x 的内容
3. linkpreview.net 的 api 进行抓取预览数据，如果前面两者都为抓取识别或者为不符合的url时，用此方法进行兜底，确保可以预览基本的消息，目前只适用于 x
4. anylinkpreivew 本地预览库进行最后的兜底工作，同样也是抓取基本的预览信息，用于国内所有网站
>抓取失败后，会显示预览失败，但是会保留基本的 url 供跳转使用

### ai分析
目前ai分析为有两钟
1. 总结模式：如果分享界面没有在 ai 标签页下面输入问题，那么就会进入总结模式，ai 将返回对帖子内容的总结和 tag 标签的生成
2. 问题模式：分享界面输入问题后，ai会对问题进行回复。
> 需要先在设置里面进行登录才能使用
<img width="352" height="672" alt="image" src="https://github.com/user-attachments/assets/e0b96a3b-0804-40cd-a6a4-84ad5d766805" />

### 局域网同步
两台设备处于同一个局域网里面，并且开启允许接收的设置（手机app在前台，桌面端无要求）。两者之间就会进行实时的数据传输！确保都是最新的数据~

### 定闹钟
| 入口 | 晚上 | 傍晚 | 白天 |
|:---:|:---:|:---:|:---:|
| <img width="390" height="796" alt="image" src="https://github.com/user-attachments/assets/d76f34d9-ab87-4106-a1ca-a5a91d7dad5d" />|<img width="386" height="802" alt="image" src="https://github.com/user-attachments/assets/9c7973a2-a408-4e43-b2c3-90b903f112a0" />|<img width="382" height="795" alt="image" src="https://github.com/user-attachments/assets/6663c80e-4203-4ed2-bec9-c09a64efd587" /> | <img width="389" height="805" alt="image" src="https://github.com/user-attachments/assets/85248e06-9967-4fe1-92fa-65583bca32dc" /> |

### 好看的ui嘻嘻
手机端：
| 瀑布流主页 | 搜索 | 详情 | 新增 |
|:---:|:---:|:---:|:---:|
| <img width="429" height="914" alt="image" src="https://github.com/user-attachments/assets/04a1b1f0-b6b5-4723-ba5f-6d0104e1705c" />|<img width="444" height="915" alt="image" src="https://github.com/user-attachments/assets/00035a73-17e3-48ee-9ba8-a29e8de1714a" /> | <img width="350" height="1878" alt="image" src="https://github.com/user-attachments/assets/61f57178-9871-4df3-b2ba-15551a1f502d" /> | <img width="444" height="900" alt="image" src="https://github.com/user-attachments/assets/d79d2c16-5b06-4263-96c1-7de87383d045" /> |

电脑端：
| 瀑布流主页 | 搜索 |
|:---:|:---:|
| <img width="1561" height="846" alt="image" src="https://github.com/user-attachments/assets/db50f4a9-8d7f-43dc-8efb-c0ece8478e83" />| <img width="1565" height="854" alt="image" src="https://github.com/user-attachments/assets/bfe4ab59-1045-46f7-a4d7-68e20cf8b245" /> |
| 详情 | 新增 |
|<img width="1264" height="685" alt="image" src="https://github.com/user-attachments/assets/e32e39fb-5b5c-4f8a-8ca6-430b7b0b90b3" />|<img width="1565" height="833" alt="image" src="https://github.com/user-attachments/assets/66970ded-95fc-4c4d-b7f9-922bf382c6f7" /> |
---
> 目前只支持 Android，win ，没有苹果设备无法适配😭

## 下载
- 右侧 release 下载，目前仅发布最早的 0.1版本，0.2版本还在开发中
## 计划
- [x] 美化uxi
- [x] 增加 win 的适配，处理数据的传输
- [x] ai对笔记内容的基本分析
- [ ] 优化爬虫（已经支持 小红书、知乎）
- [ ] 支持视频、文件的转存
- [ ] 添加智能的提醒功能(基础提醒已经完成)
- [ ] 完善 AI 的支持


## 开发初衷
大概是懒癌后期😱，在X，微信公众号，B站，小红书等app查看一些文章的时候，总是收藏了但是需要的时候确不知道再哪一个app收藏夹里面了，并且也经常吃灰😥。

PocketMind 是我对自己数字生活的一次重构，一次不一样的尝试。

目前项目还在早期开发阶段，AI 分析和任务提醒功能正在紧锣密鼓地施工中。如果你也厌倦了收藏夹的混乱和搜藏无用，欢迎 Star 关注，见证它的成长。

## 🛠️ 快速上手 (Get Started)

PocketMind 包含移动端 (Mobile) 和 后端 (Backend) 两部分。

### 前置要求
* **Flutter SDK**: `^3.8.1`
* 可以运行 flutter 项目的编辑器
* **JDK**: `17+`

### 1. 运行 App
```Bash
cd mobile
flutter pub get
flutter run
```

#### 客户端项目架构
```
mobile/
├── android/src/main/kotlin/  # Android 原生层实现
│   ├── ShareActivity.kt      # 处理与 Flutter 层的分享交互逻辑
│   ├── MainActivity.kt       # Android 主应用入口
│   └── MyQSTileService.kt    # 快捷设置磁贴 (Quick Settings Tile) 服务
│
├── lib/
│   ├── api/                  # 网络层 (Dio 服务封装)
│   │
│   ├── data/                 # 数据层 (Repository 实现 & Mappers)
│   │   ├── repositories/     # Isar 数据库操作的具体实现
│   │
│   ├── model/                # 数据库模型 (Isar Schema 定义)
│   │
│   ├── page/                 # UI 表现层 (页面 & 组件)
│   │   ├── home/             # 主业务页面 (主页, 笔记详情)
│   │   ├── share/            # 分享扩展页面 (编辑笔记, 分享成功页)
│   │   └── widget/           # 通用 UI 组件 (毛玻璃导航栏, 链接预览卡片)
│   │
│   ├── providers/            # 状态管理 (Riverpod Providers 定义)
│   │
│   ├── util/                 # 工具类 (Url 处理, 主题, 全局配置)
│   ├── lan_sync/                 # 局域网同步
│   ├── router/               # 路由
│   ├── service/              # 业务
│   ├── main.dart             # 主应用 App 入口
│   └── main_share.dart       # 分享扩展 (Share Extension) 入口
```
### 2. 启动后端
后端负责 AI 解析。
```bash
cd backend
cd src/main/resources

# 复制模板文件进行对应修改
cp application-template.yml application.yml

# 启动 docker，完成前置依赖
sudo docker compose up -d

# 运行 springboot 项目
./mvnw spring-boot:run
```
