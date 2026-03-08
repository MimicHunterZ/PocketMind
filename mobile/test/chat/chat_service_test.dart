import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:pocketmind/api/chat_api_service.dart';
import 'package:pocketmind/api/models/chat_models.dart';
import 'package:pocketmind/data/repositories/isar_chat_message_repository.dart';
import 'package:pocketmind/data/repositories/isar_chat_session_repository.dart';
import 'package:pocketmind/model/chat_session.dart';
import 'package:pocketmind/service/chat_service.dart';

// ============================================================
// Null-safe Mock 类（对 Future<void> / Future<T> 提供 noSuchMethod 默认值）
// ============================================================

class MockIsarChatMessageRepository extends Mock
    implements IsarChatMessageRepository {
  @override
  Future<List<ChatBranchSummaryModel>> buildLocalBranchSummaries(
    String sessionUuid,
  ) =>
      (super.noSuchMethod(
            Invocation.method(#buildLocalBranchSummaries, [sessionUuid]),
            returnValue: Future<List<ChatBranchSummaryModel>>.value([]),
          )
          as Future<List<ChatBranchSummaryModel>>);

  @override
  Future<void> updateContent(String uuid, String content) =>
      (super.noSuchMethod(
            Invocation.method(#updateContent, [uuid, content]),
            returnValue: Future<void>.value(),
          )
          as Future<void>);

  @override
  Future<void> softDeleteAssistantChildrenOf(String parentUuid) =>
      (super.noSuchMethod(
            Invocation.method(#softDeleteAssistantChildrenOf, [parentUuid]),
            returnValue: Future<void>.value(),
          )
          as Future<void>);

  @override
  Future<void> updateBranchAlias(String uuid, String alias) =>
      (super.noSuchMethod(
            Invocation.method(#updateBranchAlias, [uuid, alias]),
            returnValue: Future<void>.value(),
          )
          as Future<void>);

  @override
  Future<void> upsertRating(String uuid, int rating) =>
      (super.noSuchMethod(
            Invocation.method(#upsertRating, [uuid, rating]),
            returnValue: Future<void>.value(),
          )
          as Future<void>);

  @override
  Future<void> upsertFromModels(List<ChatMessageModel> models) =>
      (super.noSuchMethod(
            Invocation.method(#upsertFromModels, [models]),
            returnValue: Future<void>.value(),
          )
          as Future<void>);

  @override
  Future<void> softDeleteByUuids(List<String> uuids) =>
      (super.noSuchMethod(
            Invocation.method(#softDeleteByUuids, [uuids]),
            returnValue: Future<void>.value(),
          )
          as Future<void>);
}

class MockIsarChatSessionRepository extends Mock
    implements IsarChatSessionRepository {
  @override
  Future<ChatSession?> findByUuid(String uuid) =>
      (super.noSuchMethod(
            Invocation.method(#findByUuid, [uuid]),
            returnValue: Future<ChatSession?>.value(null),
          )
          as Future<ChatSession?>);

  @override
  Future<void> updateActiveLeaf(String sessionUuid, String? leafUuid) =>
      (super.noSuchMethod(
            Invocation.method(#updateActiveLeaf, [sessionUuid, leafUuid]),
            returnValue: Future<void>.value(),
          )
          as Future<void>);

  @override
  Future<void> upsertFromModels(List<ChatSessionModel> models) =>
      (super.noSuchMethod(
            Invocation.method(#upsertFromModels, [models]),
            returnValue: Future<void>.value(),
          )
          as Future<void>);

  @override
  Future<void> softDelete(String uuid) =>
      (super.noSuchMethod(
            Invocation.method(#softDelete, [uuid]),
            returnValue: Future<void>.value(),
          )
          as Future<void>);
}

class MockChatApiService extends Mock implements ChatApiService {
  @override
  Future<void> editMessage(
    String sessionUuid,
    String messageUuid,
    String content,
  ) =>
      (super.noSuchMethod(
            Invocation.method(#editMessage, [
              sessionUuid,
              messageUuid,
              content,
            ]),
            returnValue: Future<void>.value(),
          )
          as Future<void>);

  @override
  Future<void> updateBranchAlias(
    String sessionUuid,
    String messageUuid,
    String alias,
  ) =>
      (super.noSuchMethod(
            Invocation.method(#updateBranchAlias, [
              sessionUuid,
              messageUuid,
              alias,
            ]),
            returnValue: Future<void>.value(),
          )
          as Future<void>);

  @override
  Future<void> rateMessage(
    String sessionUuid,
    String messageUuid,
    int rating,
  ) =>
      (super.noSuchMethod(
            Invocation.method(#rateMessage, [sessionUuid, messageUuid, rating]),
            returnValue: Future<void>.value(),
          )
          as Future<void>);

  @override
  Future<List<ChatMessageModel>> listMessages(
    String sessionUuid, {
    String? leafUuid,
  }) =>
      (super.noSuchMethod(
            Invocation.method(
              #listMessages,
              [sessionUuid],
              {#leafUuid: leafUuid},
            ),
            returnValue: Future<List<ChatMessageModel>>.value([]),
          )
          as Future<List<ChatMessageModel>>);

  @override
  Future<List<ChatSessionModel>> listSessions({
    String? noteUuid,
    int page = 0,
    int size = 50,
  }) =>
      (super.noSuchMethod(
            Invocation.method(#listSessions, [], {
              #noteUuid: noteUuid,
              #page: page,
              #size: size,
            }),
            returnValue: Future<List<ChatSessionModel>>.value([]),
          )
          as Future<List<ChatSessionModel>>);

  @override
  Future<void> renameSession(String sessionUuid, String title) =>
      (super.noSuchMethod(
            Invocation.method(#renameSession, [sessionUuid, title]),
            returnValue: Future<void>.value(),
          )
          as Future<void>);

  @override
  Future<void> deleteSession(String sessionUuid) =>
      (super.noSuchMethod(
            Invocation.method(#deleteSession, [sessionUuid]),
            returnValue: Future<void>.value(),
          )
          as Future<void>);

  @override
  Future<List<ChatBranchSummaryModel>> fetchBranches(String sessionUuid) =>
      (super.noSuchMethod(
            Invocation.method(#fetchBranches, [sessionUuid]),
            returnValue: Future<List<ChatBranchSummaryModel>>.value([]),
          )
          as Future<List<ChatBranchSummaryModel>>);
}

// ============================================================
// ChatService 单元测试
// ============================================================

void main() {
  late MockIsarChatMessageRepository messageRepo;
  late MockIsarChatSessionRepository sessionRepo;
  late MockChatApiService apiService;
  late ChatService service;

  const sessionUuid = 'session-1';
  const messageUuid = 'msg-user-1';
  const assistantUuid = 'msg-ai-1';

  setUpAll(() {
    // Mockito null-safety: 为非可空 Future 返回类型注册虚拟值
    provideDummy<Future<void>>(Future.value());
    provideDummy<Future<List<ChatMessageModel>>>(Future.value([]));
    provideDummy<Future<List<ChatSessionModel>>>(Future.value([]));
    provideDummy<Future<List<ChatBranchSummaryModel>>>(Future.value([]));
    provideDummy<Stream<ChatStreamEvent>>(const Stream.empty());
  });

  setUp(() {
    messageRepo = MockIsarChatMessageRepository();
    sessionRepo = MockIsarChatSessionRepository();
    apiService = MockChatApiService();
    service = ChatService(
      sessionRepo: sessionRepo,
      messageRepo: messageRepo,
      apiService: apiService,
    );
  });

  // ----------------------------------------------------------
  // Issue #4: editMessage 立即软删除 ASSISTANT 子消息
  // ----------------------------------------------------------
  group('editMessage', () {
    test('调用 API 后同时更新本地内容并软删除 ASSISTANT 子消息', () async {
      const newContent = '新内容';

      when(
        apiService.editMessage(sessionUuid, messageUuid, newContent),
      ).thenAnswer((_) async {});
      when(
        messageRepo.updateContent(messageUuid, newContent),
      ).thenAnswer((_) async {});
      when(
        messageRepo.softDeleteAssistantChildrenOf(messageUuid),
      ).thenAnswer((_) async {});

      await service.editMessage(sessionUuid, messageUuid, newContent);

      // 验证三步均被调用
      verify(
        apiService.editMessage(sessionUuid, messageUuid, newContent),
      ).called(1);
      verify(messageRepo.updateContent(messageUuid, newContent)).called(1);
      verify(messageRepo.softDeleteAssistantChildrenOf(messageUuid)).called(1);
    });

    test('API 失败时抛出异常，不调用本地更新', () async {
      when(
        apiService.editMessage(sessionUuid, messageUuid, '新内容'),
      ).thenThrow(Exception('网络错误'));

      await expectLater(
        service.editMessage(sessionUuid, messageUuid, '新内容'),
        throwsException,
      );

      // 不应调用本地操作（精确匹配确保没有任何调用路径会触发）
      verifyNever(messageRepo.updateContent(messageUuid, '新内容'));
      verifyNever(messageRepo.softDeleteAssistantChildrenOf(messageUuid));
    });
  });

  // ----------------------------------------------------------
  // Issue #2/#3: updateBranchAlias 同步 API + 本地
  // ----------------------------------------------------------
  group('updateBranchAlias', () {
    const leafUuid = 'msg-leaf-1';
    const alias = '测试分支';

    test('同步调用 API 并更新本地缓存', () async {
      when(
        apiService.updateBranchAlias(sessionUuid, leafUuid, alias),
      ).thenAnswer((_) async {});
      when(
        messageRepo.updateBranchAlias(leafUuid, alias),
      ).thenAnswer((_) async {});

      await service.updateBranchAlias(sessionUuid, leafUuid, alias);

      verify(
        apiService.updateBranchAlias(sessionUuid, leafUuid, alias),
      ).called(1);
      verify(messageRepo.updateBranchAlias(leafUuid, alias)).called(1);
    });

    test('API 失败时异常向上传播，本地不更新', () async {
      when(
        apiService.updateBranchAlias(sessionUuid, leafUuid, alias),
      ).thenThrow(Exception('网络错误'));

      await expectLater(
        service.updateBranchAlias(sessionUuid, leafUuid, alias),
        throwsException,
      );

      verifyNever(messageRepo.updateBranchAlias(leafUuid, alias));
    });
  });

  // ----------------------------------------------------------
  // syncMessages 和 updateActiveLeaf 依然工作正常
  // ----------------------------------------------------------
  group('updateActiveLeaf', () {
    test('调用仓库更新激活叶子节点', () async {
      when(
        sessionRepo.updateActiveLeaf(sessionUuid, assistantUuid),
      ).thenAnswer((_) async {});

      await service.updateActiveLeaf(sessionUuid, assistantUuid);

      verify(
        sessionRepo.updateActiveLeaf(sessionUuid, assistantUuid),
      ).called(1);
    });

    test('leafUuid 为 null 时切回主线', () async {
      when(
        sessionRepo.updateActiveLeaf(sessionUuid, null),
      ).thenAnswer((_) async {});

      await service.updateActiveLeaf(sessionUuid, null);

      verify(sessionRepo.updateActiveLeaf(sessionUuid, null)).called(1);
    });
  });

  // ----------------------------------------------------------
  // rateMessage: 同时更新 API 和本地缓存
  // ----------------------------------------------------------
  group('rateMessage', () {
    test('评分 1 调用 API 和本地缓存', () async {
      when(
        apiService.rateMessage(sessionUuid, messageUuid, 1),
      ).thenAnswer((_) async {});
      when(messageRepo.upsertRating(messageUuid, 1)).thenAnswer((_) async {});

      await service.rateMessage(sessionUuid, messageUuid, 1);

      verify(apiService.rateMessage(sessionUuid, messageUuid, 1)).called(1);
      verify(messageRepo.upsertRating(messageUuid, 1)).called(1);
    });

    test('评分 -1（点踩）调用 API 和本地缓存', () async {
      when(
        apiService.rateMessage(sessionUuid, messageUuid, -1),
      ).thenAnswer((_) async {});
      when(messageRepo.upsertRating(messageUuid, -1)).thenAnswer((_) async {});

      await service.rateMessage(sessionUuid, messageUuid, -1);

      verify(apiService.rateMessage(sessionUuid, messageUuid, -1)).called(1);
      verify(messageRepo.upsertRating(messageUuid, -1)).called(1);
    });

    test('评分 0（取消）调用 API 和本地缓存', () async {
      when(
        apiService.rateMessage(sessionUuid, messageUuid, 0),
      ).thenAnswer((_) async {});
      when(messageRepo.upsertRating(messageUuid, 0)).thenAnswer((_) async {});

      await service.rateMessage(sessionUuid, messageUuid, 0);

      verify(apiService.rateMessage(sessionUuid, messageUuid, 0)).called(1);
      verify(messageRepo.upsertRating(messageUuid, 0)).called(1);
    });

    test('API 失败时异常向上传播，不更新本地', () async {
      when(
        apiService.rateMessage(sessionUuid, messageUuid, 1),
      ).thenThrow(Exception('评分 API 失败'));

      await expectLater(
        service.rateMessage(sessionUuid, messageUuid, 1),
        throwsException,
      );

      verifyNever(messageRepo.upsertRating(messageUuid, 1));
    });
  });

  // ----------------------------------------------------------
  // syncMessages: 拉取服务端消息 + 落库
  // ----------------------------------------------------------
  group('syncMessages', () {
    test('主线同步：调用 API 并 upsert 本地缓存', () async {
      final models = <ChatMessageModel>[];
      when(
        apiService.listMessages(sessionUuid, leafUuid: null),
      ).thenAnswer((_) async => models);
      when(messageRepo.upsertFromModels(models)).thenAnswer((_) async {});

      await service.syncMessages(sessionUuid);

      verify(apiService.listMessages(sessionUuid, leafUuid: null)).called(1);
      verify(messageRepo.upsertFromModels(models)).called(1);
    });

    test('分支同步：携带 leafUuid 请求对应链路消息', () async {
      const leafUuid = 'leaf-uuid-1';
      final models = <ChatMessageModel>[];
      when(
        apiService.listMessages(sessionUuid, leafUuid: leafUuid),
      ).thenAnswer((_) async => models);
      when(messageRepo.upsertFromModels(models)).thenAnswer((_) async {});

      await service.syncMessages(sessionUuid, leafUuid: leafUuid);

      verify(
        apiService.listMessages(sessionUuid, leafUuid: leafUuid),
      ).called(1);
      verify(messageRepo.upsertFromModels(models)).called(1);
    });

    test('API 失败时抛出异常', () async {
      when(
        apiService.listMessages(sessionUuid, leafUuid: null),
      ).thenThrow(Exception('网络错误'));

      await expectLater(service.syncMessages(sessionUuid), throwsException);
    });
  });

  // ----------------------------------------------------------
  // renameSession: 调用 API 后同步会话列表
  // ----------------------------------------------------------
  group('renameSession', () {
    const newTitle = '新会话标题';

    test('重命名成功：调用 API 后同步会话列表到本地', () async {
      when(
        apiService.renameSession(sessionUuid, newTitle),
      ).thenAnswer((_) async {});
      when(apiService.listSessions(noteUuid: null)).thenAnswer((_) async => []);
      when(
        sessionRepo.upsertFromModels(<ChatSessionModel>[]),
      ).thenAnswer((_) async {});

      await service.renameSession(sessionUuid, newTitle);

      verify(apiService.renameSession(sessionUuid, newTitle)).called(1);
      // syncSessions 内部会调用 listSessions(noteUuid: null)
      verify(apiService.listSessions(noteUuid: null)).called(1);
    });

    test('API 失败时抛出异常', () async {
      when(
        apiService.renameSession(sessionUuid, newTitle),
      ).thenThrow(Exception('API 异常'));

      await expectLater(
        service.renameSession(sessionUuid, newTitle),
        throwsException,
      );
    });
  });

  // ----------------------------------------------------------
  // deleteSession: 服务端删除 + 本地软删除
  // ----------------------------------------------------------
  group('deleteSession', () {
    test('先调 API 删除，再软删本地记录', () async {
      when(apiService.deleteSession(sessionUuid)).thenAnswer((_) async {});
      when(sessionRepo.softDelete(sessionUuid)).thenAnswer((_) async {});

      await service.deleteSession(sessionUuid);

      verify(apiService.deleteSession(sessionUuid)).called(1);
      verify(sessionRepo.softDelete(sessionUuid)).called(1);
    });

    test('API 失败时不软删本地记录', () async {
      when(apiService.deleteSession(sessionUuid)).thenThrow(Exception('删除失败'));

      await expectLater(service.deleteSession(sessionUuid), throwsException);

      verifyNever(sessionRepo.softDelete(sessionUuid));
    });
  });

  // ----------------------------------------------------------
  // fetchBranches: 透传 API 结果
  // ----------------------------------------------------------
  group('fetchBranches', () {
    test('返回 API 响应的分支列表', () async {
      final branches = [
        const ChatBranchSummaryModel(
          leafUuid: 'leaf-1',
          branchAlias: '分支一',
          lastUserContent: '用户问题',
          lastAssistantContent: 'AI 回答',
          updatedAt: 100,
        ),
      ];
      when(
        apiService.fetchBranches(sessionUuid),
      ).thenAnswer((_) async => branches);

      final result = await service.fetchBranches(sessionUuid);

      expect(result, same(branches));
      verify(apiService.fetchBranches(sessionUuid)).called(1);
      verifyNever(messageRepo.buildLocalBranchSummaries(sessionUuid));
    });

    test('API 返回空列表时回退到本地分支摘要', () async {
      final localBranches = [
        const ChatBranchSummaryModel(
          leafUuid: 'leaf-local',
          branchAlias: '本地分支',
          lastUserContent: '本地用户问题',
          lastAssistantContent: '本地 AI 回答',
          updatedAt: 200,
        ),
      ];

      when(apiService.fetchBranches(sessionUuid)).thenAnswer((_) async => []);
      when(
        messageRepo.buildLocalBranchSummaries(sessionUuid),
      ).thenAnswer((_) async => localBranches);

      final result = await service.fetchBranches(sessionUuid);

      expect(result, same(localBranches));
      verify(apiService.fetchBranches(sessionUuid)).called(1);
      verify(messageRepo.buildLocalBranchSummaries(sessionUuid)).called(1);
    });

    test('API 失败时降级本地分支摘要', () async {
      final localBranches = [
        const ChatBranchSummaryModel(
          leafUuid: 'leaf-fallback',
          branchAlias: '降级分支',
          lastUserContent: '离线问题',
          lastAssistantContent: '离线回答',
          updatedAt: 300,
        ),
      ];

      when(
        apiService.fetchBranches(sessionUuid),
      ).thenAnswer((_) => Future.error(Exception('分支拉取失败')));
      when(
        messageRepo.buildLocalBranchSummaries(sessionUuid),
      ).thenAnswer((_) async => localBranches);

      final result = await service.fetchBranches(sessionUuid);

      expect(result, same(localBranches));
      verify(messageRepo.buildLocalBranchSummaries(sessionUuid)).called(1);
    });
  });
}
