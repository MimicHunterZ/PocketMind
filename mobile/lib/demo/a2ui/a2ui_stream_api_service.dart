import 'package:ag_ui/ag_ui.dart'
    show
        ActivitySnapshotEvent,
        BaseEvent,
        RunErrorEvent,
        RunFinishedEvent,
        RunStartedEvent;
import 'package:dio/dio.dart' show CancelToken;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:genui/genui.dart' show basicCatalogId;

final a2uiStreamApiServiceProvider = Provider<A2uiStreamApiService>((ref) {
  return A2uiStreamApiService();
});

/// A2UI 用 AG-UI 作为传输层:AG-UI 管 run 生命周期,A2UI JSON 消息作为内容
/// 包在 [ActivitySnapshotEvent](activityType: `'a2ui-surface'`)里传输,
/// 与真实聊天后端(`AgUiEvent.ActivitySnapshot`)使用同一个事件承载 A2UI 内容。
/// mock 与真后端共用同一份 `Stream<BaseEvent>` 契约:
/// - [RunStartedEvent]                              → 开始一次 run
/// - `ActivitySnapshotEvent(activityType, content)`  → 一条 A2UI v0.9 消息
/// - [RunFinishedEvent]                              → 本轮结束
/// - [RunErrorEvent]                                  → 出错
///
/// 接真后端时,把 `mockStream`/`continueWithTopic` 换成
/// `AgUiClient(config: ...).runAgent(endpoint, input)` 即可,返回类型不变,
/// demo 页完全不用改。
///
/// 其中 `ActivitySnapshotEvent.content` 必须是合法的 A2UI v0.9 消息:
/// `createSurface` / `updateComponents` / `updateDataModel` / `deleteSurface`
/// 之一,且顶层带 `"version": "v0.9"`(genui SDK 强校验此版本号)。

class A2uiStreamApiService {
  /// 会话状态:按 surfaceId 保存当前根组件的 children 顺序。
  ///
  /// 真后端会在服务端维护这类会话状态(组件树结构、数据模型),客户端只负责
  /// 回传用户动作。这里用内存 map 模拟,使 demo 页无需自己跟踪 rootChildren。
  final Map<String, List<String>> _sessionRootChildren = {};

  /// 本地 mock 流。剧本:问答式技术讲解(Java 类加载机制)。
  ///
  /// 完整覆盖三要素:
  /// 1. 多段流式 Markdown(`/answer1`、`/answer2` 两段长文,逐字累积)
  /// 2. 文字与组件混排(md 段、卡片、选择器、按钮同列依次出现)
  /// 3. A2UI 交互闭环(用户选择 → event 回传 → 据选择追加第二段讲解)
  ///
  /// 流式 md 的实现:把整段 md 全文按字符切片,逐帧把「累积到当前的全量文本」
  /// 写入同一 path。genui 的 Text 组件每帧收到新值就整体重渲染,这跟真后端
  /// 「按 token 累积重发」语义一致——流式感来自数据到达的节奏,不依赖组件
  /// 自己的动画。
  Stream<BaseEvent> mockStream({
    String? requestId,
    CancelToken? cancelToken,
    Duration delay = const Duration(milliseconds: 320),
  }) async* {
    final surfaceId =
        'mock_${requestId ?? DateTime.now().microsecondsSinceEpoch}';
    final runId = requestId ?? surfaceId;
    final rootChildren = _sessionRootChildren[surfaceId] = <String>[];

    bool cancelled() => cancelToken?.isCancelled ?? false;

    Future<bool> wait([Duration? d]) async {
      if (cancelled()) return false;
      final waitFor = d ?? delay;
      if (waitFor > Duration.zero) {
        await Future<void>.delayed(waitFor);
      }
      return !cancelled();
    }

    ActivitySnapshotEvent delta(Map<String, Object?> payload) {
      return ActivitySnapshotEvent(
        messageId: surfaceId,
        activityType: 'a2ui-surface',
        content: payload,
      );
    }

    yield RunStartedEvent(threadId: surfaceId, runId: runId);

    Map<String, Object?> data(String path, Object? value) {
      return {
        'version': 'v0.9',
        'updateDataModel': {
          'surfaceId': surfaceId,
          'path': path,
          'value': value,
        },
      };
    }

    Map<String, Object?> components(List<Map<String, Object?>> items) {
      return {
        'version': 'v0.9',
        'updateComponents': {'surfaceId': surfaceId, 'components': items},
      };
    }

    Map<String, Object?> root() {
      return {
        'id': 'root',
        'component': 'Column',
        'children': List<String>.from(rootChildren),
        'align': 'stretch',
      };
    }

    // ===== ① 建 surface + 初始数据 =====
    yield delta({
      'version': 'v0.9',
      'createSurface': {
        'surfaceId': surfaceId,
        'catalogId': basicCatalogId,
      },
    });
    if (!await wait()) return;

    yield delta(data('/', _initialData()));
    if (!await wait()) return;

    // ===== ② 标题 + 第一个流式 markdown 节点 =====
    rootChildren.addAll(['titleText', 'answer1']);
    yield delta(components([root(), ..._introComponents()]));
    if (!await wait()) return;

    // ===== ③ 第一段流式 md(累积重发) =====
    yield* _streamMarkdown(
      fullText: _answer1Md,
      path: '/answer1',
      data: data,
      delta: delta,
      cancelled: cancelled,
    );
    if (!await wait()) return;

    // ===== ④ 追加交互卡片:选择深入方向 =====
    rootChildren.add('choiceCard');
    yield delta(components([root(), ..._choiceComponents()]));
    if (!await wait()) return;

    yield delta(data('/status', '请选择想深入了解的方向'));
    if (!await wait()) return;

    // 第一轮到此结束,后续由用户交互(deep_dive 事件)驱动。
    // demo 页收到 event 后会调用 continueWithTopic() 继续推送第二段。
    yield RunFinishedEvent(threadId: surfaceId, runId: runId);
  }

  /// 用户在 ④ 选择方向并点击「确定」后,由 demo 页调用,推送第二段讲解。
  ///
  /// 这模拟真后端的第二轮响应:客户端把用户选择(event + context)回传后端,
  /// 后端据此生成后续 UI 帧。这里用本地 mock 模拟该轮流式。
  Stream<BaseEvent> continueWithTopic({
    required String surfaceId,
    required String topic,
    CancelToken? cancelToken,
    Duration delay = const Duration(milliseconds: 320),
  }) async* {
    final runId = 'continue_$surfaceId';
    final rootChildren = _sessionRootChildren[surfaceId];
    if (rootChildren == null) {
      yield const RunErrorEvent(message: '会话已失效,请重新开始');
      return;
    }
    yield RunStartedEvent(threadId: surfaceId, runId: runId);
    bool cancelled() => cancelToken?.isCancelled ?? false;

    Future<bool> wait([Duration? d]) async {
      if (cancelled()) return false;
      final waitFor = d ?? delay;
      if (waitFor > Duration.zero) {
        await Future<void>.delayed(waitFor);
      }
      return !cancelled();
    }

    ActivitySnapshotEvent delta(Map<String, Object?> payload) =>
        ActivitySnapshotEvent(
          messageId: surfaceId,
          activityType: 'a2ui-surface',
          content: payload,
        );

    Map<String, Object?> data(String path, Object? value) => {
      'version': 'v0.9',
      'updateDataModel': {'surfaceId': surfaceId, 'path': path, 'value': value},
    };

    Map<String, Object?> components(List<Map<String, Object?>> items) => {
      'version': 'v0.9',
      'updateComponents': {'surfaceId': surfaceId, 'components': items},
    };

    Map<String, Object?> root() => {
      'id': 'root',
      'component': 'Column',
      'children': List<String>.from(rootChildren),
      'align': 'stretch',
    };

    // ===== ⑦ 状态即时反馈 =====
    yield delta(data('/status', '正在展开:$topic …'));
    if (!await wait()) return;

    // ===== ⑧ 追加第二个流式 markdown 节点 =====
    if (!rootChildren.contains('answer2')) {
      rootChildren.add('answer2');
    }
    yield delta(components([root(), ..._answer2Components()]));
    if (!await wait()) return;

    // ===== ⑨ 第二段流式 md(据 topic 选择内容) =====
    final secondMd = _answer2MdFor(topic);
    yield* _streamMarkdown(
      fullText: secondMd,
      path: '/answer2',
      data: data,
      delta: delta,
      cancelled: cancelled,
    );
    if (!await wait()) return;

    // ===== ⑩ 追加「理解了」按钮 =====
    if (!rootChildren.contains('doneCard')) {
      rootChildren.add('doneCard');
    }
    yield delta(components([root(), ..._doneComponents()]));
    if (!await wait()) return;

    yield RunFinishedEvent(threadId: surfaceId, runId: runId);
  }

  /// 把一段 md 全文按字符切片,逐帧把「累积全文」写入 [path]。
  ///
  /// 每帧的值都是前一帧的前缀延长,客户端据此只对新增片段做打字动画。
  Stream<BaseEvent> _streamMarkdown({
    required String fullText,
    required String path,
    required Map<String, Object?> Function(String, Object?) data,
    required ActivitySnapshotEvent Function(Map<String, Object?>) delta,
    required bool Function() cancelled,
    Duration tick = const Duration(milliseconds: 36),
    int charsPerTick = 4,
  }) async* {
    int cursor = 0;
    while (cursor < fullText.length) {
      if (cancelled()) return;
      final next = (cursor + charsPerTick).clamp(0, fullText.length);
      cursor = next;
      yield delta(data(path, fullText.substring(0, cursor)));
      if (tick > Duration.zero) {
        await Future<void>.delayed(tick);
      }
    }
  }

  Map<String, Object?> _initialData() {
    return {
      'status': '正在生成讲解…',
      'title': 'Java 类加载机制',
      'answer1': '',
      'answer2': '',
    };
  }

  List<Map<String, Object?>> _introComponents() {
    return [
      {
        'id': 'titleText',
        'component': 'Text',
        'text': {'path': '/title'},
        'variant': 'h2',
      },
      {
        'id': 'answer1',
        'component': 'Text',
        'text': {'path': '/answer1'},
      },
    ];
  }

  List<Map<String, Object?>> _choiceComponents() {
    return [
      {'id': 'choiceCard', 'component': 'Card', 'child': 'choiceColumn'},
      {
        'id': 'choiceColumn',
        'component': 'Column',
        'children': [
          'choiceTitle',
          'choiceStatus',
          'topicPicker',
          'deepButton',
        ],
        'align': 'stretch',
      },
      {
        'id': 'choiceTitle',
        'component': 'Text',
        'text': '想深入哪个方向?',
        'variant': 'h4',
      },
      {
        'id': 'choiceStatus',
        'component': 'Text',
        'text': {'path': '/status'},
        'variant': 'caption',
      },
      {
        'id': 'topicPicker',
        'component': 'ChoicePicker',
        'label': '深入方向',
        'variant': 'mutuallyExclusive',
        'value': {'path': '/choice/topic'},
        'options': [
          {'label': '热修复原理', 'value': '热修复原理'},
          {'label': '自定义 ClassLoader', 'value': '自定义 ClassLoader'},
        ],
      },
      {
        'id': 'deepButton',
        'component': 'Button',
        'variant': 'primary',
        'child': 'deepButtonLabel',
        'action': {
          'event': {
            'name': 'deep_dive',
            'context': {
              'topic': {'path': '/choice/topic'},
            },
          },
        },
      },
      {'id': 'deepButtonLabel', 'component': 'Text', 'text': '展开讲解'},
    ];
  }

  List<Map<String, Object?>> _answer2Components() {
    return [
      {
        'id': 'answer2',
        'component': 'Text',
        'text': {'path': '/answer2'},
      },
    ];
  }

  List<Map<String, Object?>> _doneComponents() {
    return [
      {'id': 'doneCard', 'component': 'Card', 'child': 'doneColumn'},
      {
        'id': 'doneColumn',
        'component': 'Column',
        'children': ['doneButton', 'doneStatus'],
        'align': 'stretch',
      },
      {
        'id': 'doneButton',
        'component': 'Button',
        'variant': 'primary',
        'child': 'doneButtonLabel',
        'action': {
          'event': {'name': 'mark_done', 'context': <String, Object?>{}},
        },
      },
      {'id': 'doneButtonLabel', 'component': 'Text', 'text': '理解了'},
      {
        'id': 'doneStatus',
        'component': 'Text',
        'text': {'path': '/status'},
        'variant': 'caption',
      },
    ];
  }

  // ===== md 素材 =====

  static const String _answer1Md = '''
## 什么是类加载器

JVM 通过**类加载器(ClassLoader)**把 `.class` 文件加载进内存,转换为运行时的 `Class` 对象。它是 Java 动态性的基石。

### 三层标准加载器
1. **Bootstrap ClassLoader** — 加载 `jre/lib` 核心类库,由 C++ 实现
2. **Extension ClassLoader** — 加载 `jre/lib/ext` 扩展类库
3. **Application ClassLoader** — 加载 `CLASSPATH` 下的应用类

### 双亲委派模型
加载请求**先交给父加载器**,父加载器无法完成时才自己加载:

```java
protected Class<?> loadClass(String name, boolean resolve) {
    Class<?> c = findLoadedClass(name);
    if (c == null) {
        if (parent != null) {
            c = parent.loadClass(name, false);
        } else {
            c = findBootstrapClassOrNull(name);
        }
        if (c == null) c = findClass(name);
    }
    return c;
}
```

> 这样保证核心类不被篡改,且同一个类只被加载一次。
''';

  static const String _answer2HotfixMd = '''
## 热修复原理

热修复利用了双亲委派「同名类只加载一次,先到先得」的特性,用补丁类**抢先**覆盖有 bug 的原类。

### 核心步骤
1. 把修复后的类编译成补丁 **DEX** 文件
2. 用自定义 `ClassLoader` 抢先加载补丁 DEX
3. 通过反射把补丁 ClassLoader 插到加载链前端

| 方案 | 代表框架 | 特点 |
|------|----------|------|
| 类替换 | Tinker | 全量/差量 DEX,需重启 |
| 底层替换 | AndFix | 方法指针替换,即时生效 |
| Instant Run | 官方 | 开发期热部署 |

> 生产环境需权衡生效时机与兼容性,通常以「类替换」方案最稳妥。
''';

  static const String _answer2CustomLoaderMd = '''
## 自定义 ClassLoader

继承 `ClassLoader` 并重写 `findClass`,即可从**自定义来源**(网络、加密文件、内存)加载类。

### 实现要点
1. 重写 `findClass(String name)`,读取字节码
2. 调用 `defineClass(name, bytes, 0, bytes.length)` 转成 `Class`
3. **不要**重写 `loadClass`,以保留双亲委派

```java
public class MyLoader extends ClassLoader {
    @Override
    protected Class<?> findClass(String name) {
        byte[] bytes = loadBytesFrom(name); // 自定义来源
        return defineClass(name, bytes, 0, bytes.length);
    }
}
```

| 场景 | 说明 |
|------|------|
| 热部署 | 每次新建 loader 加载新版本类 |
| 加密保护 | 加载时解密字节码 |
| 隔离 | 不同 loader 加载的同名类互不相等 |
''';

  String _answer2MdFor(String topic) {
    if (topic.contains('自定义')) {
      return _answer2CustomLoaderMd;
    }
    return _answer2HotfixMd;
  }
}
