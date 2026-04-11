/// 路由路径常量定义
class RoutePaths {
  /// 首页 (笔记列表)
  static const String home = '/';

  /// 笔记详情页
  static const String noteDetail = '/note';

  /// 设置页
  static const String settings = '/settings';

  /// 同步设置页
  static const String sync = '/settings/sync';

  /// 账号登录/注册
  static const String auth = '/settings/auth';

  /// 全局 AI 入口
  static const String globalAi = '/global-ai';

  /// A2UI Demo 页面
  static const String genuiDemo = '/genui-demo';

  /// 平台账号管理
  static const String platformAccounts = '/settings/platform-accounts';

  /// 聊天页 - 参数 :sessionUuid
  static const String chat = '/chat/:sessionUuid';

  /// 生成聊天页路径
  static String chatOf(String sessionUuid) => '/chat/$sessionUuid';

  /// 分支列表页 - 参数 :sessionUuid
  static const String branchList = '/chat/:sessionUuid/branches';

  /// 生成分支列表页路径
  static String branchListOf(String sessionUuid) =>
      '/chat/$sessionUuid/branches';
}
