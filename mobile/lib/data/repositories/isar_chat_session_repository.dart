import 'package:isar_community/isar.dart';
import 'package:pocketmind/api/models/chat_models.dart';
import 'package:pocketmind/model/chat_session.dart';
import 'package:pocketmind/util/logger_service.dart';

/// Isar 聊天会话仓库。
///
/// 封装所有与 Isar 相关的 [ChatSession] 数据访问逻辑。
/// 上层（Service）通过此类操作本地缓存，而不直接调用 Isar。
class IsarChatSessionRepository {
  final Isar _isar;
  static const String _tag = 'IsarChatSessionRepository';

  IsarChatSessionRepository(this._isar);

  // 查询 / 监听

  /// 实时监听会话列表，按 [ChatSession.updatedAt] 倒序排列。
  ///
  /// [noteUuid] 不为 null 时只返回该笔记下的会话；为 null 时返回全部非删除会话。
  Stream<List<ChatSession>> watchSessions({String? noteUuid}) {
    if (noteUuid != null) {
      return _isar.chatSessions
          .filter()
          .scopeNoteUuidEqualTo(noteUuid)
          .and()
          .isDeletedEqualTo(false)
          .sortByUpdatedAtDesc()
          .watch(fireImmediately: true);
    }
    return _isar.chatSessions
        .filter()
        .isDeletedEqualTo(false)
        .sortByUpdatedAtDesc()
        .watch(fireImmediately: true);
  }

  /// 按 UUID 查找单个会话，未找到返回 null。
  Future<ChatSession?> findByUuid(String uuid) {
    return _isar.chatSessions.filter().uuidEqualTo(uuid).findFirst();
  }

  /// 直接查询指定笔记下的非删除会话（按 updatedAt 倒序），绕过 stream provider 时序问题。
  Future<List<ChatSession>> findByNoteUuid(String noteUuid) {
    return _isar.chatSessions
        .filter()
        .scopeNoteUuidEqualTo(noteUuid)
        .and()
        .isDeletedEqualTo(false)
        .sortByUpdatedAtDesc()
        .findAll();
  }

  /// 查询全局会话（scopeNoteUuid == null），按 updatedAt 倒序。
  Future<List<ChatSession>> findGlobalSessions() {
    return _isar.chatSessions
        .filter()
        .scopeNoteUuidIsNull()
        .and()
        .isDeletedEqualTo(false)
        .sortByUpdatedAtDesc()
        .findAll();
  }

  // 写入

  /// 将服务端返回的会话列表全量 upsert（有则更新，无则插入）。
  Future<void> upsertFromModels(List<ChatSessionModel> models) async {
    final sessions = models.map(_fromModel).toList();
    await _isar.writeTxn(() async {
      for (final s in sessions) {
        final existing = await _isar.chatSessions
            .filter()
            .uuidEqualTo(s.uuid)
            .findFirst();
        if (existing != null) {
          s.id = existing.id;
          s.activeLeafUuid = existing.activeLeafUuid;
        }
        await _isar.chatSessions.put(s);
      }
    });
    PMlog.d(_tag, 'upsert ${sessions.length} 条会话');
  }

  /// 本地软删除（标记 isDeleted=true），服务端删除由 Service 层负责。
  Future<void> softDelete(String uuid) async {
    await _isar.writeTxn(() async {
      final s = await _isar.chatSessions.filter().uuidEqualTo(uuid).findFirst();
      if (s != null) {
        s.isDeleted = true;
        await _isar.chatSessions.put(s);
        PMlog.d(_tag, '软删除会话: $uuid');
      }
    });
  }

  /// 实时监听单个会话（用于 BranchBanner 订阅 activeLeafUuid 变化）。
  Stream<ChatSession?> watchByUuid(String uuid) {
    return _isar.chatSessions
        .filter()
        .uuidEqualTo(uuid)
        .watch(fireImmediately: true)
        .map((list) => list.isEmpty ? null : list.first);
  }

  /// 本地更新会话的激活叶子节点，null = 回到主线。
  Future<void> updateActiveLeaf(String sessionUuid, String? leafUuid) async {
    await _isar.writeTxn(() async {
      final s = await _isar.chatSessions
          .filter()
          .uuidEqualTo(sessionUuid)
          .findFirst();
      if (s != null) {
        s.activeLeafUuid = leafUuid;
        await _isar.chatSessions.put(s);
        PMlog.d(_tag, '更新激活叶子节点: $sessionUuid -> $leafUuid');
      }
    });
  }

  /// 本地更新会话标题。
  Future<void> updateTitle(String sessionUuid, String title) async {
    await _isar.writeTxn(() async {
      final s = await _isar.chatSessions
          .filter()
          .uuidEqualTo(sessionUuid)
          .findFirst();
      if (s != null) {
        s.title = title;
        s.updatedAt = DateTime.now().millisecondsSinceEpoch;
        await _isar.chatSessions.put(s);
        PMlog.d(_tag, '更新会话标题: $sessionUuid -> $title');
      }
    });
  }

  // 私有工具

  static ChatSession _fromModel(ChatSessionModel m) {
    return ChatSession()
      ..uuid = m.uuid
      ..scopeNoteUuid = m.scopeNoteUuid
      ..title = m.title
      ..updatedAt = m.updatedAt
      ..isDeleted = false;
  }
}
