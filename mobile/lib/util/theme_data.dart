// 主题定义 - 统一的亮色/暗色主题
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

// 流动背景颜色 - 亮色模式
class LightFlowingBackgroundColors {
  static const Color blob1 = Color(0xFFE58F6F); // 赤陶橙
  static const Color blob2 = Color(0xFFF4A261); // 温暖杏色
  static const Color blob3 = Color(0xFFE76F51); // 珊瑚橙
  static const Color blob4 = Color(0xFF2A9D8F); // 青绿色
}

// 流动背景颜色 - 暗色模式
class DarkFlowingBackgroundColors {
  static const Color blob1 = Color(0xFFFF6B35); // 明亮橙红
  static const Color blob2 = Color(0xFF8B5CF6); // 紫色
  static const Color blob3 = Color(0xFF3B82F6); // 蓝色
  static const Color blob4 = Color(0xFFF59E0B); // 金色
}

// 扩展颜色 - 用于骨架屏、占位图等
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.skeletonBase,
    required this.skeletonHighlight,
    required this.errorBackground,
    required this.errorIcon,
    required this.errorText,
    required this.cardBorder,
  });

  /// 骨架屏底色
  final Color skeletonBase;

  /// 骨架屏高亮色
  final Color skeletonHighlight;

  /// 错误卡片背景
  final Color errorBackground;

  /// 错误图标颜色
  final Color errorIcon;

  /// 错误文字颜色
  final Color errorText;

  /// 卡片边框颜色
  final Color cardBorder;

  @override
  AppColors copyWith({
    Color? skeletonBase,
    Color? skeletonHighlight,
    Color? errorBackground,
    Color? errorIcon,
    Color? errorText,
    Color? cardBorder,
  }) {
    return AppColors(
      skeletonBase: skeletonBase ?? this.skeletonBase,
      skeletonHighlight: skeletonHighlight ?? this.skeletonHighlight,
      errorBackground: errorBackground ?? this.errorBackground,
      errorIcon: errorIcon ?? this.errorIcon,
      errorText: errorText ?? this.errorText,
      cardBorder: cardBorder ?? this.cardBorder,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      skeletonBase: Color.lerp(skeletonBase, other.skeletonBase, t)!,
      skeletonHighlight: Color.lerp(
        skeletonHighlight,
        other.skeletonHighlight,
        t,
      )!,
      errorBackground: Color.lerp(errorBackground, other.errorBackground, t)!,
      errorIcon: Color.lerp(errorIcon, other.errorIcon, t)!,
      errorText: Color.lerp(errorText, other.errorText, t)!,
      cardBorder: Color.lerp(cardBorder, other.cardBorder, t)!,
    );
  }

  static AppColors of(BuildContext context) {
    return Theme.of(context).extension<AppColors>()!;
  }
}

/// 亮色模式扩展颜色
const lightAppColors = AppColors(
  skeletonBase: Color(0xFFE8E8E8),
  skeletonHighlight: Color(0xFFF5F5F5),
  errorBackground: Color(0xFFF5F5F5),
  errorIcon: Color(0xFFD0D0D0),
  errorText: Color(0xFF9E9E9E),
  cardBorder: Color(0x1A000000), // black 10%
);

/// 暗色模式扩展颜色
const darkAppColors = AppColors(
  skeletonBase: Color(0xFF2A2A2A),
  skeletonHighlight: Color(0xFF3A3A3A),
  errorBackground: Color(0xFF252525),
  errorIcon: Color(0xFF4A4A4A),
  errorText: Color(0xFF6A6A6A),
  cardBorder: Color(0x33FFFFFF), // white 20%
);

class SharePageThemeColors extends ThemeExtension<SharePageThemeColors> {
  const SharePageThemeColors({required this.primary, required this.secondary});

  final Color? primary;
  final Color? secondary;

  @override
  SharePageThemeColors copyWith({Color? primary, Color? secondary}) {
    return SharePageThemeColors(
      primary: primary ?? this.primary,
      secondary: secondary ?? this.secondary,
    );
  }

  @override
  SharePageThemeColors lerp(
    ThemeExtension<SharePageThemeColors>? other,
    double t,
  ) {
    if (other is! SharePageThemeColors) {
      return this;
    }
    return SharePageThemeColors(
      primary: Color.lerp(primary, other.primary, t),
      secondary: Color.lerp(secondary, other.secondary, t),
    );
  }

  static SharePageThemeColors? of(BuildContext context) {
    return Theme.of(context).extension<SharePageThemeColors>();
  }
}

const lightShareColors = SharePageThemeColors(
  primary: Color(0xFFFFFFFF),
  secondary: Color(0xFFEAE5E0),
);

const darkShareColors = SharePageThemeColors(
  primary: Color(0xFFFFFFFF),
  secondary: Color(0xFFEAE5E0),
);

// 亮色模式
final ThemeData calmBeigeTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.light,
  colorScheme: const ColorScheme(
    brightness: Brightness.light,
    primary: Color(0xFF3A3A35), // 主文本色
    onPrimary: Color(0xFFFFFFFF),
    secondary: Color(0xFF9B9691), // 副文本色
    onSecondary: Color(0xFFFFFFFF),
    surface: Color(0xFFFFFFFF), // 卡片背景
    onSurface: Color(0xFF3A3A35),
    error: Color(0xFFBA1A1A),
    onError: Color(0xFFFFFFFF),
    // 强调色 - 赤陶色
    tertiary: Color(0xFFD97757),
    onTertiary: Color(0xFFFFFFFF),
    // 侧边栏/次级背景色
    surfaceContainerLow: Color(0xFFF2F0ED),
    surfaceContainerHighest: Color(0xFFD97757),
    outline: Color(0xFFE0DDD9), // 分割线颜色
    onSurfaceVariant: Color(0xFF9B9691),
    outlineVariant: Color(0xFFD6D2CE),
  ),
  switchTheme: SwitchThemeData(
    // 1. 定义滑块颜色 (Thumb)
    thumbColor: WidgetStateProperty.resolveWith<Color?>((states) {
      if (states.contains(WidgetState.selected)) {
        return const Color(0xFFD97757); // 【打开】状态：橙色
      }
      // 【关闭】状态：显式指定为灰色/白色，不要返回 null
      return const Color(0xFF79747E);
    }),

    // 2. 定义轨道颜色 (Track)
    trackColor: WidgetStateProperty.resolveWith<Color?>((states) {
      if (states.contains(WidgetState.selected)) {
        return const Color(0xFFD97757).withValues(alpha: 0.5); // 【打开】状态：淡橙色
      }
      // 【关闭】状态：显式指定为浅灰色
      return const Color(0xFFE7E0EC);
    }),

    // 3. 定义轨道边框
    trackOutlineColor: WidgetStateProperty.resolveWith<Color?>((states) {
      if (states.contains(WidgetState.selected)) {
        return Colors.transparent; // 打开时不要边框
      }
      return const Color(0xFF79747E); // 关闭时显示深灰边框
    }),
  ),
  scaffoldBackgroundColor: const Color(0xFFF2F0ED), // Scaffold 背景
  canvasColor: const Color(0xFFF2F0ED),
  cardColor: const Color(0xFFFFFFFF), // 卡片背景
  shadowColor: Colors.black.withValues(alpha: 0.05),
  fontFamily: 'SF Pro',
  textTheme: TextTheme(
    titleLarge: TextStyle(
      fontFamily: 'Merriweather',
      fontFamilyFallback: const ['LXGWWenKaiLite'],
      fontSize: 24.sp,
      fontWeight: FontWeight.w900,
      // 杂志感大标题稍微收紧字母间距
      letterSpacing: -0.5,
      // 标题行高要小，避免松散
      height: 1.2,
      color: const Color(0xFF3A3A35),
    ),

    titleMedium: TextStyle(
      fontFamily: 'Merriweather',
      fontFamilyFallback: const ['LXGWWenKaiLite'],
      fontSize: 18.sp,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.5,
      height: 1.2,
      color: const Color(0xFF3A3A35),
    ),
    bodyLarge: TextStyle(
      fontFamily: 'LXGWWenKaiLite',
      fontFamilyFallback: const ['Merriweather'],
      fontSize: 16.sp,
      fontWeight: FontWeight.normal,
      // 杂志感正文行高 1.6 倍
      height: 1.6,
      color: const Color(0xFF3A3A35),
    ),

    bodyMedium: TextStyle(
      fontFamily: 'LXGWWenKaiLite',
      fontFamilyFallback: const ['Merriweather'],
      fontSize: 14.sp,
      fontWeight: FontWeight.normal,
      height: 1.5,
      color: const Color(0xFF3A3A35),
    ),

    bodySmall: TextStyle(
      fontFamily: 'LXGWWenKaiLite',
      fontFamilyFallback: const ['Merriweather'],
      fontSize: 12.sp,
      fontWeight: FontWeight.normal,
      height: 1.4,
      color: const Color(0xFF3A3A35),
    ),
  ),
  appBarTheme: AppBarTheme(
    backgroundColor: Colors.transparent,
    elevation: 0,
    foregroundColor: Color(0xFF3A3A35),
    titleTextStyle: TextStyle(
      fontSize: 24.sp,
      fontWeight: FontWeight.bold,
      color: Color(0xFF3A3A35),
    ),
  ),
  floatingActionButtonTheme: const FloatingActionButtonThemeData(
    backgroundColor: Color(0xFFD97757), // 强调色
    foregroundColor: Color(0xFFFFFFFF),
    shape: StadiumBorder(),
    elevation: 4,
  ),
  extensions: const <ThemeExtension<dynamic>>[
    lightShareColors,
    lightAppColors,
    lightChatBubbleColors,
  ],
);

// 暗色模式
final ThemeData quietNightTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  colorScheme: const ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFFA1A1AA), // 主文本色 - 柔和灰白
    onPrimary: Color(0xFF09090B),
    secondary: Color(0xFF71717A), // 副文本色
    onSecondary: Color(0xFF09090B),
    surface: Color(0xFF202022), // 卡片背景
    onSurface: Color(0xFFA1A1AA),
    error: Color(0xFFFFB4AB),
    onError: Color(0xFF690005),
    // 强调色 - 暖橙
    tertiary: Color(0xFFE58F6F),
    onTertiary: Color(0xFF09090B),
    // 侧边栏/次级背景色 - 纯黑
    surfaceContainerLow: Color(0xFF151515),
    // 点睛色
    surfaceContainerHighest: Color(0xFFE58F6F),
    outline: Color(0xBB838282), // 分割线颜色
    onSurfaceVariant: Color(0xFFC6C1C1),
    outlineVariant: Color(0xFF3F3F46),
  ),
  switchTheme: SwitchThemeData(
    // 1. 定义滑块颜色 (Thumb)
    thumbColor: WidgetStateProperty.resolveWith<Color?>((states) {
      if (states.contains(WidgetState.selected)) {
        return const Color(0xFFD97757); // 【打开】状态：橙色
      }
      // 【关闭】状态：显式指定为灰色/白色，不要返回 null
      return const Color(0xFF79747E);
    }),

    // 2. 定义轨道颜色 (Track)
    trackColor: WidgetStateProperty.resolveWith<Color?>((states) {
      if (states.contains(WidgetState.selected)) {
        return const Color(0xFFD97757).withValues(alpha: 0.5); // 【打开】状态：淡橙色
      }
      // 【关闭】状态：显式指定为浅灰色
      return const Color(0xFFE7E0EC);
    }),

    // 3. 定义轨道边框 (可选，让关闭状态更清晰)
    trackOutlineColor: WidgetStateProperty.resolveWith<Color?>((states) {
      if (states.contains(WidgetState.selected)) {
        return Colors.transparent; // 打开时不要边框
      }
      return const Color(0xFF79747E); // 关闭时显示深灰边框
    }),
  ),
  scaffoldBackgroundColor: const Color(0xFF202022), // Scaffold 背景
  canvasColor: const Color(0xFF09090B),
  cardColor: const Color(0xFF18181B), // 卡片背景 - 提亮
  shadowColor: Colors.black.withValues(alpha: 0.3),
  fontFamily: 'SF Pro',
  textTheme: TextTheme(
    titleLarge: TextStyle(
      fontFamily: 'Merriweather',
      fontFamilyFallback: const ['LXGWWenKaiLite'],
      fontSize: 32.sp,
      fontWeight: FontWeight.w900,
      letterSpacing: -0.5,
      // 标题行高要小，避免松散
      height: 1.2,
      color: const Color(0xFFE4E4E6),
    ),

    titleMedium: TextStyle(
      fontFamily: 'Merriweather',
      fontFamilyFallback: const ['LXGWWenKaiLite'],
      fontSize: 18.sp,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.5,
      height: 1.25,
      color: const Color(0xFFE4E4E6),
    ),

    bodyLarge: TextStyle(
      fontFamily: 'LXGWWenKaiLite',
      fontFamilyFallback: const ['Merriweather'],
      fontSize: 16.sp,
      fontWeight: FontWeight.normal,
      height: 1.6,
      color: const Color(0xFFA1A1AA),
    ),

    bodyMedium: TextStyle(
      fontFamily: 'LXGWWenKaiLite',
      fontFamilyFallback: const ['Merriweather'],
      fontSize: 14.sp,
      fontWeight: FontWeight.normal,
      height: 1.6,
      color: const Color(0xFFA1A1AA),
    ),

    bodySmall: TextStyle(
      fontFamily: 'LXGWWenKaiLite',
      fontFamilyFallback: const ['Merriweather'],
      fontSize: 12.sp,
      fontWeight: FontWeight.normal,
      height: 1.5,
      color: const Color(0xFF71717A),
    ),
  ),
  appBarTheme: AppBarTheme(
    backgroundColor: Colors.transparent,
    elevation: 0,
    foregroundColor: Color(0xFFA1A1AA),
    titleTextStyle: TextStyle(
      fontSize: 24.sp,
      fontWeight: FontWeight.bold,
      color: Color(0xFFA1A1AA),
    ),
  ),
  floatingActionButtonTheme: const FloatingActionButtonThemeData(
    backgroundColor: Color(0xFFE58F6F), // 强调色
    foregroundColor: Color(0xFFFFFFFF),
    shape: StadiumBorder(),
    elevation: 4,
  ),
  extensions: const <ThemeExtension<dynamic>>[
    darkShareColors,
    darkAppColors,
    darkChatBubbleColors,
  ],
);
// 聊天气泡颜色 - 供 ChatPage 使用

class ChatBubbleColors extends ThemeExtension<ChatBubbleColors> {
  const ChatBubbleColors({
    required this.userBubble,
    required this.userBubbleText,
    required this.assistantBubble,
    required this.assistantBubbleText,
    required this.timeLabelBackground,
    required this.timeLabelText,
    required this.inputBarBackground,
    required this.streamingDot,
  });

  /// 用户气泡背景色
  final Color userBubble;

  /// 用户气泡文字色
  final Color userBubbleText;

  /// AI 气泡背景色
  final Color assistantBubble;

  /// AI 气泡文字色
  final Color assistantBubbleText;

  /// 居中时间标签背景
  final Color timeLabelBackground;

  /// 居中时间标签文字
  final Color timeLabelText;

  /// 底部输入栏背景
  final Color inputBarBackground;

  /// 流式打字动画点颜色
  final Color streamingDot;

  @override
  ChatBubbleColors copyWith({
    Color? userBubble,
    Color? userBubbleText,
    Color? assistantBubble,
    Color? assistantBubbleText,
    Color? timeLabelBackground,
    Color? timeLabelText,
    Color? inputBarBackground,
    Color? streamingDot,
  }) {
    return ChatBubbleColors(
      userBubble: userBubble ?? this.userBubble,
      userBubbleText: userBubbleText ?? this.userBubbleText,
      assistantBubble: assistantBubble ?? this.assistantBubble,
      assistantBubbleText: assistantBubbleText ?? this.assistantBubbleText,
      timeLabelBackground: timeLabelBackground ?? this.timeLabelBackground,
      timeLabelText: timeLabelText ?? this.timeLabelText,
      inputBarBackground: inputBarBackground ?? this.inputBarBackground,
      streamingDot: streamingDot ?? this.streamingDot,
    );
  }

  @override
  ChatBubbleColors lerp(ThemeExtension<ChatBubbleColors>? other, double t) {
    if (other is! ChatBubbleColors) return this;
    return ChatBubbleColors(
      userBubble: Color.lerp(userBubble, other.userBubble, t)!,
      userBubbleText: Color.lerp(userBubbleText, other.userBubbleText, t)!,
      assistantBubble: Color.lerp(assistantBubble, other.assistantBubble, t)!,
      assistantBubbleText: Color.lerp(
        assistantBubbleText,
        other.assistantBubbleText,
        t,
      )!,
      timeLabelBackground: Color.lerp(
        timeLabelBackground,
        other.timeLabelBackground,
        t,
      )!,
      timeLabelText: Color.lerp(timeLabelText, other.timeLabelText, t)!,
      inputBarBackground: Color.lerp(
        inputBarBackground,
        other.inputBarBackground,
        t,
      )!,
      streamingDot: Color.lerp(streamingDot, other.streamingDot, t)!,
    );
  }

  static ChatBubbleColors of(BuildContext context) =>
      Theme.of(context).extension<ChatBubbleColors>()!;
}

const lightChatBubbleColors = ChatBubbleColors(
  userBubble: Color(0xFFD97757), // 赤陶橙 - 与主题 tertiary 一致
  userBubbleText: Color(0xFFFFFFFF),
  assistantBubble: Color(0xFFFFFFFF), // 纯白卡片
  assistantBubbleText: Color(0xFF3A3A35),
  timeLabelBackground: Color(0xFFE8E4DF),
  timeLabelText: Color(0xFF9B9691),
  inputBarBackground: Color(0xFFFFFFFF),
  streamingDot: Color(0xFFD97757),
);

const darkChatBubbleColors = ChatBubbleColors(
  userBubble: Color(0xFFE58F6F), // 暖橙 - 与暗色 tertiary 一致
  userBubbleText: Color(0xFF09090B),
  assistantBubble: Color(0xFF2C2C2E), // 稍亮于 scaffold 背景
  assistantBubbleText: Color(0xFFA1A1AA),
  timeLabelBackground: Color(0xFF2A2A2C),
  timeLabelText: Color(0xFF71717A),
  inputBarBackground: Color(0xFF2C2C2E),
  streamingDot: Color(0xFFE58F6F),
);
