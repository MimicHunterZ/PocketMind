/// 主题分类图标选项
class ThemeCategoryIconOption {
  final String assetPath;
  final String label;

  const ThemeCategoryIconOption({required this.assetPath, required this.label});
}

/// 主题分类页果冻图标注册表
const List<ThemeCategoryIconOption> themeCategoryIconOptions = [
  ThemeCategoryIconOption(assetPath: 'assets/icons/jelly/notes.svg', label: '笔记'),
  ThemeCategoryIconOption(assetPath: 'assets/icons/jelly/design.svg', label: '设计'),
  ThemeCategoryIconOption(assetPath: 'assets/icons/jelly/github.svg', label: '代码'),
  ThemeCategoryIconOption(assetPath: 'assets/icons/jelly/reddit.svg', label: '社区'),
  ThemeCategoryIconOption(assetPath: 'assets/icons/jelly/wechat.svg', label: '微信'),
  ThemeCategoryIconOption(assetPath: 'assets/icons/jelly/weibo.svg', label: '微博'),
  ThemeCategoryIconOption(assetPath: 'assets/icons/jelly/youtube.svg', label: '视频'),
  ThemeCategoryIconOption(assetPath: 'assets/icons/jelly/discord.svg', label: '讨论'),
  ThemeCategoryIconOption(assetPath: 'assets/icons/jelly/planet.svg', label: '主页'),
  ThemeCategoryIconOption(assetPath: 'assets/icons/jelly/ghost.svg', label: '订阅'),
  ThemeCategoryIconOption(assetPath: 'assets/icons/jelly/mail.svg', label: '联系'),
  ThemeCategoryIconOption(assetPath: 'assets/icons/jelly/xhs.svg', label: '小红书'),
];
