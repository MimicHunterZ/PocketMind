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

@ProviderFor(chatSessions)
const chatSessionsProvider = ChatSessionsFamily._();

/// 聊天会话列表流。

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

  ChatSessionsProvider call(String? noteUuid) =>
      ChatSessionsProvider._(argument: noteUuid, from: this);

  @override
  String toString() => r'chatSessionsProvider';
}

/// 实时监听单个会话（用于 [BranchBanner] 订阅 activeLeafUuid 变化）。

@ProviderFor(chatSessionStream)
const chatSessionStreamProvider = ChatSessionStreamFamily._();

/// 实时监听单个会话（用于 [BranchBanner] 订阅 activeLeafUuid 变化）。

final class ChatSessionStreamProvider
    extends
        $FunctionalProvider<
          AsyncValue<ChatSession?>,
          ChatSession?,
          Stream<ChatSession?>
        >
    with $FutureModifier<ChatSession?>, $StreamProvider<ChatSession?> {
  /// 实时监听单个会话（用于 [BranchBanner] 订阅 activeLeafUuid 变化）。
  const ChatSessionStreamProvider._({
    required ChatSessionStreamFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'chatSessionStreamProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$chatSessionStreamHash();

  @override
  String toString() {
    return r'chatSessionStreamProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<ChatSession?> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<ChatSession?> create(Ref ref) {
    final argument = this.argument as String;
    return chatSessionStream(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ChatSessionStreamProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$chatSessionStreamHash() => r'7f4268ee34185d92a3f381163cd3ccb4243a1620';

/// 实时监听单个会话（用于 [BranchBanner] 订阅 activeLeafUuid 变化）。

final class ChatSessionStreamFamily extends $Family
    with $FunctionalFamilyOverride<Stream<ChatSession?>, String> {
  const ChatSessionStreamFamily._()
    : super(
        retry: null,
        name: r'chatSessionStreamProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// 实时监听单个会话（用于 [BranchBanner] 订阅 activeLeafUuid 变化）。

  ChatSessionStreamProvider call(String sessionUuid) =>
      ChatSessionStreamProvider._(argument: sessionUuid, from: this);

  @override
  String toString() => r'chatSessionStreamProvider';
}

/// 指定会话的消息列表流（按时间轴升序）。
///
/// 自动感知会话的 [ChatSession.activeLeafUuid]：
/// - null → 主线（watchBySessionUuid）
/// - 非 null → 分支链路（watchByLeafUuid）

@ProviderFor(chatMessages)
const chatMessagesProvider = ChatMessagesFamily._();

/// 指定会话的消息列表流（按时间轴升序）。
///
/// 自动感知会话的 [ChatSession.activeLeafUuid]：
/// - null → 主线（watchBySessionUuid）
/// - 非 null → 分支链路（watchByLeafUuid）

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
  /// 自动感知会话的 [ChatSession.activeLeafUuid]：
  /// - null → 主线（watchBySessionUuid）
  /// - 非 null → 分支链路（watchByLeafUuid）
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

String _$chatMessagesHash() => r'378fbacaeba071123600b0f168c4d9c33146d133';

/// 指定会话的消息列表流（按时间轴升序）。
///
/// 自动感知会话的 [ChatSession.activeLeafUuid]：
/// - null → 主线（watchBySessionUuid）
/// - 非 null → 分支链路（watchByLeafUuid）

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
  /// 自动感知会话的 [ChatSession.activeLeafUuid]：
  /// - null → 主线（watchBySessionUuid）
  /// - 非 null → 分支链路（watchByLeafUuid）

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

/// 获取会话所有分支摘要列表（按需拉取，BranchListPage 使用）。

@ProviderFor(chatBranches)
const chatBranchesProvider = ChatBranchesFamily._();

/// 获取会话所有分支摘要列表（按需拉取，BranchListPage 使用）。

final class ChatBranchesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<ChatBranchSummaryModel>>,
          List<ChatBranchSummaryModel>,
          FutureOr<List<ChatBranchSummaryModel>>
        >
    with
        $FutureModifier<List<ChatBranchSummaryModel>>,
        $FutureProvider<List<ChatBranchSummaryModel>> {
  /// 获取会话所有分支摘要列表（按需拉取，BranchListPage 使用）。
  const ChatBranchesProvider._({
    required ChatBranchesFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'chatBranchesProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$chatBranchesHash();

  @override
  String toString() {
    return r'chatBranchesProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<ChatBranchSummaryModel>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<ChatBranchSummaryModel>> create(Ref ref) {
    final argument = this.argument as String;
    return chatBranches(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ChatBranchesProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$chatBranchesHash() => r'ccfe5ea44a1e60d9da6d7e446ad4018782fb395a';

/// 获取会话所有分支摘要列表（按需拉取，BranchListPage 使用）。

final class ChatBranchesFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<List<ChatBranchSummaryModel>>,
          String
        > {
  const ChatBranchesFamily._()
    : super(
        retry: null,
        name: r'chatBranchesProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// 获取会话所有分支摘要列表（按需拉取，BranchListPage 使用）。

  ChatBranchesProvider call(String sessionUuid) =>
      ChatBranchesProvider._(argument: sessionUuid, from: this);

  @override
  String toString() => r'chatBranchesProvider';
}

/// 实时监听单条消息（用于分支芯片显示 AI 生成的别名）。

@ProviderFor(chatMessageByUuid)
const chatMessageByUuidProvider = ChatMessageByUuidFamily._();

/// 实时监听单条消息（用于分支芯片显示 AI 生成的别名）。

final class ChatMessageByUuidProvider
    extends
        $FunctionalProvider<
          AsyncValue<ChatMessage?>,
          ChatMessage?,
          Stream<ChatMessage?>
        >
    with $FutureModifier<ChatMessage?>, $StreamProvider<ChatMessage?> {
  /// 实时监听单条消息（用于分支芯片显示 AI 生成的别名）。
  const ChatMessageByUuidProvider._({
    required ChatMessageByUuidFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'chatMessageByUuidProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$chatMessageByUuidHash();

  @override
  String toString() {
    return r'chatMessageByUuidProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<ChatMessage?> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<ChatMessage?> create(Ref ref) {
    final argument = this.argument as String;
    return chatMessageByUuid(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ChatMessageByUuidProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$chatMessageByUuidHash() => r'e5677e3a6e7cd6d633e713298061270c9d2f349e';

/// 实时监听单条消息（用于分支芯片显示 AI 生成的别名）。

final class ChatMessageByUuidFamily extends $Family
    with $FunctionalFamilyOverride<Stream<ChatMessage?>, String> {
  const ChatMessageByUuidFamily._()
    : super(
        retry: null,
        name: r'chatMessageByUuidProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// 实时监听单条消息（用于分支芯片显示 AI 生成的别名）。

  ChatMessageByUuidProvider call(String uuid) =>
      ChatMessageByUuidProvider._(argument: uuid, from: this);

  @override
  String toString() => r'chatMessageByUuidProvider';
}

@ProviderFor(chatOnlineStatus)
const chatOnlineStatusProvider = ChatOnlineStatusProvider._();

final class ChatOnlineStatusProvider
    extends $FunctionalProvider<AsyncValue<bool>, bool, Stream<bool>>
    with $FutureModifier<bool>, $StreamProvider<bool> {
  const ChatOnlineStatusProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'chatOnlineStatusProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$chatOnlineStatusHash();

  @$internal
  @override
  $StreamProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<bool> create(Ref ref) {
    return chatOnlineStatus(ref);
  }
}

String _$chatOnlineStatusHash() => r'2a0129df02fac9674b7e36c4da015cae7448547a';

@ProviderFor(GlobalAiSessionController)
const globalAiSessionControllerProvider = GlobalAiSessionControllerProvider._();

final class GlobalAiSessionControllerProvider
    extends $NotifierProvider<GlobalAiSessionController, GlobalAiSessionState> {
  const GlobalAiSessionControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'globalAiSessionControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$globalAiSessionControllerHash();

  @$internal
  @override
  GlobalAiSessionController create() => GlobalAiSessionController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(GlobalAiSessionState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<GlobalAiSessionState>(value),
    );
  }
}

String _$globalAiSessionControllerHash() =>
    r'721fe85de6d42d03f63e32802f95b5768aa3d73f';

abstract class _$GlobalAiSessionController
    extends $Notifier<GlobalAiSessionState> {
  GlobalAiSessionState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<GlobalAiSessionState, GlobalAiSessionState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<GlobalAiSessionState, GlobalAiSessionState>,
              GlobalAiSessionState,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}

/// 消息发送 Notifier，按 [sessionUuid] 分组（family）。

@ProviderFor(ChatSend)
const chatSendProvider = ChatSendFamily._();

/// 消息发送 Notifier，按 [sessionUuid] 分组（family）。
final class ChatSendProvider
    extends $NotifierProvider<ChatSend, ChatSendState> {
  /// 消息发送 Notifier，按 [sessionUuid] 分组（family）。
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

String _$chatSendHash() => r'84ecbc8e90a59ea0ed661ac4663c7d5e23fe5b3a';

/// 消息发送 Notifier，按 [sessionUuid] 分组（family）。

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

  ChatSendProvider call(String sessionUuid) =>
      ChatSendProvider._(argument: sessionUuid, from: this);

  @override
  String toString() => r'chatSendProvider';
}

/// 消息发送 Notifier，按 [sessionUuid] 分组（family）。

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
