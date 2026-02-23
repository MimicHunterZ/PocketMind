// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 聊天会话 Isar 仓库 Provider。

@ProviderFor(chatSessionRepository)
const chatSessionRepositoryProvider = ChatSessionRepositoryProvider._();

/// 聊天会话 Isar 仓库 Provider。

final class ChatSessionRepositoryProvider
    extends
        $FunctionalProvider<
          IsarChatSessionRepository,
          IsarChatSessionRepository,
          IsarChatSessionRepository
        >
    with $Provider<IsarChatSessionRepository> {
  /// 聊天会话 Isar 仓库 Provider。
  const ChatSessionRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'chatSessionRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$chatSessionRepositoryHash();

  @$internal
  @override
  $ProviderElement<IsarChatSessionRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  IsarChatSessionRepository create(Ref ref) {
    return chatSessionRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(IsarChatSessionRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<IsarChatSessionRepository>(value),
    );
  }
}

String _$chatSessionRepositoryHash() =>
    r'60471dae3f07972d8935400f825d0f1ea363dac7';

/// 聊天消息 Isar 仓库 Provider。

@ProviderFor(chatMessageRepository)
const chatMessageRepositoryProvider = ChatMessageRepositoryProvider._();

/// 聊天消息 Isar 仓库 Provider。

final class ChatMessageRepositoryProvider
    extends
        $FunctionalProvider<
          IsarChatMessageRepository,
          IsarChatMessageRepository,
          IsarChatMessageRepository
        >
    with $Provider<IsarChatMessageRepository> {
  /// 聊天消息 Isar 仓库 Provider。
  const ChatMessageRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'chatMessageRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$chatMessageRepositoryHash();

  @$internal
  @override
  $ProviderElement<IsarChatMessageRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  IsarChatMessageRepository create(Ref ref) {
    return chatMessageRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(IsarChatMessageRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<IsarChatMessageRepository>(value),
    );
  }
}

String _$chatMessageRepositoryHash() =>
    r'e2fd6777991cebce1f37b681c009d86f865e7845';

/// 聊天业务 Service Provider（全局单例）。

@ProviderFor(chatService)
const chatServiceProvider = ChatServiceProvider._();

/// 聊天业务 Service Provider（全局单例）。

final class ChatServiceProvider
    extends $FunctionalProvider<ChatService, ChatService, ChatService>
    with $Provider<ChatService> {
  /// 聊天业务 Service Provider（全局单例）。
  const ChatServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'chatServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$chatServiceHash();

  @$internal
  @override
  $ProviderElement<ChatService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ChatService create(Ref ref) {
    return chatService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ChatService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ChatService>(value),
    );
  }
}

String _$chatServiceHash() => r'0342f93e65e86a99ccb720b3d8a4792dae9d0463';

/// 聊天会话列表流。
///
/// [noteUuid] 为 null 时返回全部非删除会话（按 updatedAt 倒序）；
/// 不为 null 时返回该笔记下的会话。
///
/// 用法示例：
/// ```dart
/// ref.watch(chatSessionsProvider(null))       // 全局会话列表
/// ref.watch(chatSessionsProvider(noteUuid))   // 笔记下的会话列表
/// ```

@ProviderFor(chatSessions)
const chatSessionsProvider = ChatSessionsFamily._();

/// 聊天会话列表流。
///
/// [noteUuid] 为 null 时返回全部非删除会话（按 updatedAt 倒序）；
/// 不为 null 时返回该笔记下的会话。
///
/// 用法示例：
/// ```dart
/// ref.watch(chatSessionsProvider(null))       // 全局会话列表
/// ref.watch(chatSessionsProvider(noteUuid))   // 笔记下的会话列表
/// ```

final class ChatSessionsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<ChatSession>>,
          List<ChatSession>,
          Stream<List<ChatSession>>
        >
    with
        $FutureModifier<List<ChatSession>>,
        $StreamProvider<List<ChatSession>> {
  /// 聊天会话列表流。
  ///
  /// [noteUuid] 为 null 时返回全部非删除会话（按 updatedAt 倒序）；
  /// 不为 null 时返回该笔记下的会话。
  ///
  /// 用法示例：
  /// ```dart
  /// ref.watch(chatSessionsProvider(null))       // 全局会话列表
  /// ref.watch(chatSessionsProvider(noteUuid))   // 笔记下的会话列表
  /// ```
  const ChatSessionsProvider._({
    required ChatSessionsFamily super.from,
    required String? super.argument,
  }) : super(
         retry: null,
         name: r'chatSessionsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$chatSessionsHash();

  @override
  String toString() {
    return r'chatSessionsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<List<ChatSession>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<ChatSession>> create(Ref ref) {
    final argument = this.argument as String?;
    return chatSessions(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ChatSessionsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$chatSessionsHash() => r'0e023cc4b6ed3fb128329e4af4309b9c1ee2fb47';

/// 聊天会话列表流。
///
/// [noteUuid] 为 null 时返回全部非删除会话（按 updatedAt 倒序）；
/// 不为 null 时返回该笔记下的会话。
///
/// 用法示例：
/// ```dart
/// ref.watch(chatSessionsProvider(null))       // 全局会话列表
/// ref.watch(chatSessionsProvider(noteUuid))   // 笔记下的会话列表
/// ```

final class ChatSessionsFamily extends $Family
    with $FunctionalFamilyOverride<Stream<List<ChatSession>>, String?> {
  const ChatSessionsFamily._()
    : super(
        retry: null,
        name: r'chatSessionsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// 聊天会话列表流。
  ///
  /// [noteUuid] 为 null 时返回全部非删除会话（按 updatedAt 倒序）；
  /// 不为 null 时返回该笔记下的会话。
  ///
  /// 用法示例：
  /// ```dart
  /// ref.watch(chatSessionsProvider(null))       // 全局会话列表
  /// ref.watch(chatSessionsProvider(noteUuid))   // 笔记下的会话列表
  /// ```

  ChatSessionsProvider call(String? noteUuid) =>
      ChatSessionsProvider._(argument: noteUuid, from: this);

  @override
  String toString() => r'chatSessionsProvider';
}

/// 指定会话的消息列表流（按时间轴升序）。
///
/// UI 订阅此 Provider，Isar 数据变更后自动推送最新列表。
/// 完整历史在进入页面时由 [ChatSend.initSession] 触发同步。

@ProviderFor(chatMessages)
const chatMessagesProvider = ChatMessagesFamily._();

/// 指定会话的消息列表流（按时间轴升序）。
///
/// UI 订阅此 Provider，Isar 数据变更后自动推送最新列表。
/// 完整历史在进入页面时由 [ChatSend.initSession] 触发同步。

final class ChatMessagesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<ChatMessage>>,
          List<ChatMessage>,
          Stream<List<ChatMessage>>
        >
    with
        $FutureModifier<List<ChatMessage>>,
        $StreamProvider<List<ChatMessage>> {
  /// 指定会话的消息列表流（按时间轴升序）。
  ///
  /// UI 订阅此 Provider，Isar 数据变更后自动推送最新列表。
  /// 完整历史在进入页面时由 [ChatSend.initSession] 触发同步。
  const ChatMessagesProvider._({
    required ChatMessagesFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'chatMessagesProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$chatMessagesHash();

  @override
  String toString() {
    return r'chatMessagesProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<List<ChatMessage>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<ChatMessage>> create(Ref ref) {
    final argument = this.argument as String;
    return chatMessages(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ChatMessagesProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$chatMessagesHash() => r'ced28c8392b29c50871a7be5e2e3b402798f3186';

/// 指定会话的消息列表流（按时间轴升序）。
///
/// UI 订阅此 Provider，Isar 数据变更后自动推送最新列表。
/// 完整历史在进入页面时由 [ChatSend.initSession] 触发同步。

final class ChatMessagesFamily extends $Family
    with $FunctionalFamilyOverride<Stream<List<ChatMessage>>, String> {
  const ChatMessagesFamily._()
    : super(
        retry: null,
        name: r'chatMessagesProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// 指定会话的消息列表流（按时间轴升序）。
  ///
  /// UI 订阅此 Provider，Isar 数据变更后自动推送最新列表。
  /// 完整历史在进入页面时由 [ChatSend.initSession] 触发同步。

  ChatMessagesProvider call(String sessionUuid) =>
      ChatMessagesProvider._(argument: sessionUuid, from: this);

  @override
  String toString() => r'chatMessagesProvider';
}

/// 按 UUID 查找单个会话（一次性 Future，用于取标题）。

@ProviderFor(chatSessionByUuid)
const chatSessionByUuidProvider = ChatSessionByUuidFamily._();

/// 按 UUID 查找单个会话（一次性 Future，用于取标题）。

final class ChatSessionByUuidProvider
    extends
        $FunctionalProvider<
          AsyncValue<ChatSession?>,
          ChatSession?,
          FutureOr<ChatSession?>
        >
    with $FutureModifier<ChatSession?>, $FutureProvider<ChatSession?> {
  /// 按 UUID 查找单个会话（一次性 Future，用于取标题）。
  const ChatSessionByUuidProvider._({
    required ChatSessionByUuidFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'chatSessionByUuidProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$chatSessionByUuidHash();

  @override
  String toString() {
    return r'chatSessionByUuidProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<ChatSession?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<ChatSession?> create(Ref ref) {
    final argument = this.argument as String;
    return chatSessionByUuid(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ChatSessionByUuidProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$chatSessionByUuidHash() => r'0f1335eb68acfb9e9de64ea63dcb709fd6e772c0';

/// 按 UUID 查找单个会话（一次性 Future，用于取标题）。

final class ChatSessionByUuidFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<ChatSession?>, String> {
  const ChatSessionByUuidFamily._()
    : super(
        retry: null,
        name: r'chatSessionByUuidProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// 按 UUID 查找单个会话（一次性 Future，用于取标题）。

  ChatSessionByUuidProvider call(String uuid) =>
      ChatSessionByUuidProvider._(argument: uuid, from: this);

  @override
  String toString() => r'chatSessionByUuidProvider';
}

/// 消息发送 Notifier，按 [sessionUuid] 分组（family）。
///
/// 职责：
/// 1. 调用 [ChatService.streamMessage] 获取 SSE 流；
/// 2. 监听 [ChatDeltaEvent] 累积流式文本，更新 [ChatSendState.streaming]；
/// 3. 收到 [ChatDoneEvent] 后触发 [ChatService.syncMessages] 落库，并复位状态；
/// 4. 遇到 [ChatErrorEvent] 或异常，更新 [ChatSendState.error]。
///
/// UI 显示逻辑：
/// - 消息列表来自 [chatMessagesProvider]（Isar stream，持久化驱动）；
/// - 流式文本通过 `(state as ChatSendStreaming).content` 额外渲染 AI 正在输入的气泡；
/// - 收到 `idle` 时隐藏该气泡（最终消息已落库，Isar stream 自动刷新）。

@ProviderFor(ChatSend)
const chatSendProvider = ChatSendFamily._();

/// 消息发送 Notifier，按 [sessionUuid] 分组（family）。
///
/// 职责：
/// 1. 调用 [ChatService.streamMessage] 获取 SSE 流；
/// 2. 监听 [ChatDeltaEvent] 累积流式文本，更新 [ChatSendState.streaming]；
/// 3. 收到 [ChatDoneEvent] 后触发 [ChatService.syncMessages] 落库，并复位状态；
/// 4. 遇到 [ChatErrorEvent] 或异常，更新 [ChatSendState.error]。
///
/// UI 显示逻辑：
/// - 消息列表来自 [chatMessagesProvider]（Isar stream，持久化驱动）；
/// - 流式文本通过 `(state as ChatSendStreaming).content` 额外渲染 AI 正在输入的气泡；
/// - 收到 `idle` 时隐藏该气泡（最终消息已落库，Isar stream 自动刷新）。
final class ChatSendProvider
    extends $NotifierProvider<ChatSend, ChatSendState> {
  /// 消息发送 Notifier，按 [sessionUuid] 分组（family）。
  ///
  /// 职责：
  /// 1. 调用 [ChatService.streamMessage] 获取 SSE 流；
  /// 2. 监听 [ChatDeltaEvent] 累积流式文本，更新 [ChatSendState.streaming]；
  /// 3. 收到 [ChatDoneEvent] 后触发 [ChatService.syncMessages] 落库，并复位状态；
  /// 4. 遇到 [ChatErrorEvent] 或异常，更新 [ChatSendState.error]。
  ///
  /// UI 显示逻辑：
  /// - 消息列表来自 [chatMessagesProvider]（Isar stream，持久化驱动）；
  /// - 流式文本通过 `(state as ChatSendStreaming).content` 额外渲染 AI 正在输入的气泡；
  /// - 收到 `idle` 时隐藏该气泡（最终消息已落库，Isar stream 自动刷新）。
  const ChatSendProvider._({
    required ChatSendFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'chatSendProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$chatSendHash();

  @override
  String toString() {
    return r'chatSendProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  ChatSend create() => ChatSend();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ChatSendState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ChatSendState>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ChatSendProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$chatSendHash() => r'd1370ae5b22fb2c95c0f17d7cc9d1fe4be154bd0';

/// 消息发送 Notifier，按 [sessionUuid] 分组（family）。
///
/// 职责：
/// 1. 调用 [ChatService.streamMessage] 获取 SSE 流；
/// 2. 监听 [ChatDeltaEvent] 累积流式文本，更新 [ChatSendState.streaming]；
/// 3. 收到 [ChatDoneEvent] 后触发 [ChatService.syncMessages] 落库，并复位状态；
/// 4. 遇到 [ChatErrorEvent] 或异常，更新 [ChatSendState.error]。
///
/// UI 显示逻辑：
/// - 消息列表来自 [chatMessagesProvider]（Isar stream，持久化驱动）；
/// - 流式文本通过 `(state as ChatSendStreaming).content` 额外渲染 AI 正在输入的气泡；
/// - 收到 `idle` 时隐藏该气泡（最终消息已落库，Isar stream 自动刷新）。

final class ChatSendFamily extends $Family
    with
        $ClassFamilyOverride<
          ChatSend,
          ChatSendState,
          ChatSendState,
          ChatSendState,
          String
        > {
  const ChatSendFamily._()
    : super(
        retry: null,
        name: r'chatSendProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// 消息发送 Notifier，按 [sessionUuid] 分组（family）。
  ///
  /// 职责：
  /// 1. 调用 [ChatService.streamMessage] 获取 SSE 流；
  /// 2. 监听 [ChatDeltaEvent] 累积流式文本，更新 [ChatSendState.streaming]；
  /// 3. 收到 [ChatDoneEvent] 后触发 [ChatService.syncMessages] 落库，并复位状态；
  /// 4. 遇到 [ChatErrorEvent] 或异常，更新 [ChatSendState.error]。
  ///
  /// UI 显示逻辑：
  /// - 消息列表来自 [chatMessagesProvider]（Isar stream，持久化驱动）；
  /// - 流式文本通过 `(state as ChatSendStreaming).content` 额外渲染 AI 正在输入的气泡；
  /// - 收到 `idle` 时隐藏该气泡（最终消息已落库，Isar stream 自动刷新）。

  ChatSendProvider call(String sessionUuid) =>
      ChatSendProvider._(argument: sessionUuid, from: this);

  @override
  String toString() => r'chatSendProvider';
}

/// 消息发送 Notifier，按 [sessionUuid] 分组（family）。
///
/// 职责：
/// 1. 调用 [ChatService.streamMessage] 获取 SSE 流；
/// 2. 监听 [ChatDeltaEvent] 累积流式文本，更新 [ChatSendState.streaming]；
/// 3. 收到 [ChatDoneEvent] 后触发 [ChatService.syncMessages] 落库，并复位状态；
/// 4. 遇到 [ChatErrorEvent] 或异常，更新 [ChatSendState.error]。
///
/// UI 显示逻辑：
/// - 消息列表来自 [chatMessagesProvider]（Isar stream，持久化驱动）；
/// - 流式文本通过 `(state as ChatSendStreaming).content` 额外渲染 AI 正在输入的气泡；
/// - 收到 `idle` 时隐藏该气泡（最终消息已落库，Isar stream 自动刷新）。

abstract class _$ChatSend extends $Notifier<ChatSendState> {
  late final _$args = ref.$arg as String;
  String get sessionUuid => _$args;

  ChatSendState build(String sessionUuid);
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build(_$args);
    final ref = this.ref as $Ref<ChatSendState, ChatSendState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ChatSendState, ChatSendState>,
              ChatSendState,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
