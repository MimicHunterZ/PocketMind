# Flutter UI 组件库规范

## 概述

PocketMind 移动端自定义 UI 组件库,追求"杂志感"设计语言。

**组件位置**: `mobile/lib/page/widget/`

**组件总数**: 36 个 (根目录 15 个 + common 3 个 + desktop 3 个 + note_detail 12 个 + preview_card 3 个)

## 主题系统

### 位置
`mobile/lib/util/theme_data.dart`

### 核心扩展颜色

#### AppColors
基础扩展颜色:
- `skeletonBase` / `skeletonHighlight` - 骨架屏颜色
- `errorBackground` / `errorIcon` / `errorText` - 错误状态
- `cardBorder` - 卡片边框

```dart
final appColors = AppColors.of(context);
```

#### CategoryHomeColors
分类首页配色:
- 首页背景、渐变色
- 卡片样式 (背景、边框、阴影)
- 文字颜色 (titleText, bodyText, metaText)
- Tab 样式 (激活/非激活)

#### ChatBubbleColors
聊天气泡颜色:
- 用户/助手气泡 (背景、文字)
- 输入栏、时间标签、流式动画点

#### FlowingBackgroundColors
流动背景色:
- `LightFlowingBackgroundColors` - 亮色 (赤陶橙、温暖杏色)
- `DarkFlowingBackgroundColors` - 暗色 (明亮橙红、紫色)

### 预定义主题
- **calmBeigeTheme** - 亮色模式 (杂志感、米色风格)
- **quietNightTheme** - 暗色模式 (极简深色)

## 核心组件清单

### 输入组件

#### MyTextField
统一文本输入框。

```dart
MyTextField(
  controller: TextEditingController,
  hintText: '请输入...',
  colorScheme: Theme.of(context).colorScheme,
  maxLines: 1,
  autofocus: false,
  expands: false,  // 填满父容器高度
  padding: EdgeInsets.all(16),
)
```

#### TagSelector
标签管理组件 (增删改查)。

```dart
TagSelector(
  tags: ['Flutter', 'Dart'],
  onTagsChanged: (tags) => print(tags),
  hintText: 'Add Tag',
)
```

**特性**: Chip 样式、内联输入框、动画展开

### 导航组件

#### PMAppBar
统一标题栏 (自动处理平台差异)。

```dart
PMAppBar(
  title: Text('标题'),
  actions: [IconButton(...)],
  leading: BackButton(),
  automaticallyImplyLeading: true,
)
```

**特性**: 桌面端标题靠左,移动端居中;自动处理返回按钮

#### CategoriesBar
分类导航栏 (毛玻璃效果)。

```dart
CategoriesBar()  // 使用 Riverpod Provider
```

**特性**: 毛玻璃背景、横向滚动、长按删除

#### ItemBar
单个导航项 (用于 CategoriesBar)。

```dart
ItemBar(
  svgPath: 'assets/icons/home.svg',
  text: '首页',
  isActive: true,
  onTap: () {},
)
```

#### DesktopSidebar
桌面端侧边栏。

```dart
DesktopSidebar()
static const double width = 260;
```

**特性**: App Logo、主导航、macOS 红绿灯预留空间

### 展示组件

#### PMImage
智能图片渲染组件。

```dart
PMImage(
  pathOrUrl: 'https://example.com/image.jpg',
  fit: BoxFit.cover,
  width: 200,
  height: 200,
  cacheWidth: 400,       // 本地图片缓存尺寸
  memCacheWidth: 400,    // 网络图片缓存尺寸
  placeholder: CircularProgressIndicator(),
  errorWidget: Icon(Icons.error),
)
```

**特性**: 
- 自动识别网络图片、本地路径、Asset
- 缓存优化、内存控制
- StreamBuilder 监听本地图片更新

#### NoteItem
笔记列表项 (支持瀑布流/列表)。

```dart
NoteItem(
  note: note,
  noteService: noteService,
  isWaterfall: true,
  isDesktop: false,
)
```

**特性**: 
- 自动保持状态
- 图片预热优化
- 桌面端悬停效果

#### LocalTextCard
纯文本笔记卡片 (4 种变体风格)。

```dart
LocalTextCard(
  note: note,
  isDesktop: false,
  isHovered: false,
)
```

**特性**: 
- `snippet` - 日志风格
- `quote` - 引用风格 (带引号装饰)
- `headline` - 大标题风格
- `essay` - 文章风格

#### LinkPreviewCard
链接预览卡片。

```dart
LinkPreviewCard(
  note: note,
  isWaterfall: true,
  hasContent: true,
  onTap: () {},
  isDesktop: false,
  publishDate: '2024-01-01',
  isHovered: false,
  isLoading: false,
)
```

**特性**: 自动分发到瀑布流/列表样式,加载态骨架屏

#### HeroGallery
头图轮播画廊。

```dart
HeroGallery(
  images: ['url1', 'url2'],
  title: '标题',
  isDesktop: false,
  height: 300,
  onImageTap: () {},
  showGradientFade: true,
  categoryLabel: '分类',
  dateLabel: '2024-01-01',
)
```

**特性**: PageView 轮播、指示器点、悬停箭头

### 反馈组件

#### CreativeToast
创意 Toast 提示组件。

```dart
// 静态方法
CreativeToast.show(
  context,
  type: ToastType.success,
  title: '成功',
  message: '操作成功',
  direction: ToastDirection.top,
  duration: Duration(seconds: 3),
);

// 快捷方法
CreativeToast.success(context, title: '成功', message: '...');
CreativeToast.error(context, title: '错误', message: '...');
CreativeToast.info(context, title: '提示', message: '...');
CreativeToast.warning(context, title: '警告', message: '...');
```

**特性**: 渐变背景、圆环动画、顶部/底部滑入

#### ScrapingSkeletonCard
抓取中骨架屏卡片。

```dart
ScrapingSkeletonCard(
  isVertical: true,
  url: 'https://example.com',
  publishDate: '2024-01-01',
)
```

### 选择器组件

#### CategorySelector
分类选择器 (弹窗)。

```dart
CategorySelector(
  selectedCategoryId: 1,
  onCategorySelected: (id) => print(id),
  builder: (context, category) => Text(category.name),
)
```

#### CreativeTimePicker
创意时间选择器 (动态主题)。

```dart
CreativeTimePicker(
  initialTime: DateTime.now(),
  onTimeSelected: (time, name) => print(time),
  onCancelled: () {},
)
```

**特性**: 根据时间段动态主题 (黎明/白天/黄昏/夜晚)、可拖动时针/分针

### 背景组件

#### FlowingBackground
流动渐变背景动画。

```dart
FlowingBackground()  // 无需参数
```

**特性**: 
- 3 层不同速度动画
- 5 个流动渐变球
- 毛玻璃模糊效果
- 自动适配亮/暗色主题

### 对话框组件

#### AddCategoryDialog
添加分类对话框。

```dart
final result = await showAddCategoryDialog(context);
if (result != null) {
  print('名称: ${result.name}');
  print('图标: ${result.iconPath}');
}
```

### 通用小组件

#### CategoryBadge
```dart
CategoryBadge(
  categoryName: '技术',
  style: CategoryBadgeStyle.normal,  // normal | onImage
)
```

#### DateLabel
```dart
DateLabel(
  dateText: '2024-01-01',
  style: DateLabelStyle.normal,  // normal | onImage
  fontSize: 12,
  iconSize: 14,
)
```

#### SourceInfo
源信息组件 (域名+发布日期)。

```dart
SourceInfo(
  url: 'https://example.com',
  publishDate: '2024-01-01',
)
```

**特性**: 域名映射 (微信、知乎、B站等),本地内容显示"本地"

### 笔记详情组件

位于 `note_detail/` 目录:

- `NoteDetailTopBar` - 顶部操作栏
- `NoteAiInsightSection` - AI 洞察区域
- `NoteCategorySelector` - 分类选择器
- `NoteDetailSidebar` - 详情页侧边栏
- `NoteLastEditedInfo` - 最后编辑信息
- `NoteLinkContentSection` - 链接内容区域
- `NoteOriginalDataSection` - 原始数据区域
- `NotePersonalNotesSection` - 个人笔记区域
- `NoteSourceLinkCard` - 源链接卡片
- `NoteSourceSection` - 源信息区域
- `NoteTagsSection` - 标签区域

## 使用规范

### 1. 主题获取

```dart
// ✅ 正确 - 从主题获取
final theme = Theme.of(context);
final colorScheme = theme.colorScheme;
final textTheme = theme.textTheme;
final appColors = AppColors.of(context);
final chatColors = ChatBubbleColors.of(context);

// ❌ 错误 - 硬编码
final color = Color(0xFF1A1A1A);
final textStyle = TextStyle(fontSize: 16);
```

### 2. 组件选择

```dart
// ✅ 正确 - 使用封装组件
MyTextField(
  controller: controller,
  hintText: '请输入...',
  colorScheme: colorScheme,
)

// ❌ 错误 - 直接使用原生组件
TextField(
  controller: controller,
  decoration: InputDecoration(hintText: '请输入...'),
)
```

### 3. 图片加载

```dart
// ✅ 正确 - 使用 PMImage
PMImage(pathOrUrl: 'https://...', width: 200, height: 200)

// ❌ 错误 - 直接使用
Image.network('https://...')
Image.file(File('...'))
```

### 4. Toast 提示

```dart
// ✅ 正确 - 使用 CreativeToast
CreativeToast.success(context, title: '成功', message: '保存成功');

// ❌ 错误 - 使用 SnackBar
ScaffoldMessenger.of(context).showSnackBar(...);
```

## 响应式适配

### 桌面端判断
```dart
final isDesktop = MediaQuery.of(context).size.width > 600;
```

### 尺寸适配
使用 `flutter_screenutil`:
```dart
width: 200.w,    // 宽度适配
height: 100.h,   // 高度适配
fontSize: 14.sp, // 字体适配
borderRadius: BorderRadius.circular(8.r),  // 圆角适配
```

## 性能优化

### 图片预热
```dart
ImagePrefetcher.prewarm(context, imageUrl);
```

### 解码尺寸控制
```dart
PMImage(
  pathOrUrl: url,
  cacheWidth: 400,      // 限制解码尺寸,节省内存
  memCacheWidth: 400,
)
```

### 列表项保持状态
```dart
class NoteItem extends StatefulWidget {
  // 使用 AutomaticKeepAliveClientMixin
}
```

## 组件目录结构

```
mobile/lib/page/widget/
├── [根目录] (15 个核心组件)
│   ├── creative_toast.dart
│   ├── text_field.dart (MyTextField)
│   ├── pm_app_bar.dart
│   ├── pm_image.dart
│   ├── tag_selector.dart
│   ├── category_selector.dart
│   ├── categories_bar.dart
│   ├── item_bar.dart
│   ├── note_Item.dart
│   ├── local_text_card.dart
│   ├── flowing_background.dart
│   ├── creative_time_picker.dart
│   ├── add_category_dialog.dart
│   ├── source_info.dart
│   └── glass_nav_bar.dart (已弃用)
├── common/ (3 个通用小组件)
│   ├── category_badge.dart
│   ├── date_label.dart
│   └── immersive_image.dart
├── desktop/ (3 个桌面端组件)
│   ├── desktop_sidebar.dart
│   ├── desktop_header.dart
│   └── sidebar_item.dart
├── note_detail/ (12 个笔记详情组件)
│   ├── note_detail_top_bar.dart
│   ├── hero_gallery.dart
│   └── ... (其他详情组件)
└── preview_card/ (3 个预览卡片)
    ├── link_preview_card.dart
    ├── preview_success_cards.dart
    └── scraping_skeleton_card.dart
```

## 相关文档

- [Flutter 架构规范](./flutter-architecture.md)
- [移动端编码规约](../../conventions/mobile-coding-standards.md)
