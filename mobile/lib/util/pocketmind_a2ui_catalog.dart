import 'package:genui/genui.dart';
import 'package:go_router/go_router.dart';
import 'package:json_schema_builder/json_schema_builder.dart';
import 'package:pocketmind/model/note.dart';
import 'package:pocketmind/router/app_router.dart';
import 'package:pocketmind/router/route_paths.dart';

/// PocketMind 自己的本地函数(`functionCall`)注册表,合并进 genui 官方基础
/// catalog。新增本地函数只改这个列表,不用碰任何 `SurfaceController` 建立点。
class PocketMindClientFunctions {
  static const openNote = OpenNoteFunction();

  static List<ClientFunction> get all => [openNote];
}

/// 所有生产 `SurfaceController` 应该共用这一个 catalog 实例。
final Catalog pocketMindA2uiCatalog = BasicCatalogItems.asCatalog().copyWith(
  newFunctions: PocketMindClientFunctions.all,
);

/// 本地跳转到笔记详情页,不往返后端。
///
/// 参数直接带够 [Note] 需要的字段(`noteUuid`/`title`/`content`),不依赖本地
/// Isar 查询——数据由生成这个 `functionCall` 的一方(后端工具/demo)直接放进
/// `args` 里。用 [appNavigatorKey] 而不是 [ExecutionContext] 里的 `BuildContext`
/// 做跳转,因为 genui 的执行上下文本身不带 `BuildContext`。
///
/// 用 `go` 而不是 `push`:笔记详情页嵌套在带侧边栏的 `ShellRoute` 下,而调用
/// 这个函数的页面(聊天页/demo 页)都是 `ShellRoute` 外的全屏顶层路由——从
/// shell 外 `push` 一个 shell 内的路径,会让 go_router 同时挂两份 `ShellRoute`
/// 内部保活用的 `GlobalKey`,触发 `!keyReservation.contains(key)` 断言崩溃。
/// `go` 会整体按新地址重新计算路由树,不会有这个问题,和既有的
/// `note_item.dart` 打开笔记详情页的方式保持一致。
class OpenNoteFunction extends SynchronousClientFunction {
  const OpenNoteFunction();

  @override
  String get name => 'openNote';

  @override
  String get description => '本地打开笔记详情页,不往返后端。';

  @override
  ClientFunctionReturnType get returnType => ClientFunctionReturnType.empty;

  @override
  Schema get argumentSchema => S.object(
    properties: {
      'noteUuid': S.string(description: '笔记 uuid'),
      'title': S.string(description: '笔记标题'),
      'content': S.string(description: '笔记正文'),
    },
    required: ['noteUuid'],
  );

  @override
  Object? executeSync(JsonMap args, ExecutionContext context) {
    final ctx = appNavigatorKey.currentContext;
    if (ctx == null) return null;
    final note = Note()
      ..uuid = args['noteUuid'] as String?
      ..title = args['title'] as String?
      ..content = args['content'] as String?;
    ctx.go(RoutePaths.noteDetail, extra: note);
    return null;
  }
}
