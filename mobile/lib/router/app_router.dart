import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pocketmind/model/note.dart';
import 'package:pocketmind/page/chat/branch_list_page.dart';
import 'package:pocketmind/page/chat/chat_page.dart';
import 'package:pocketmind/page/home/home_screen.dart';
import 'package:pocketmind/page/home/desktop/desktop_home_screen.dart';
import 'package:pocketmind/page/home/note_detail_page.dart';
import 'package:pocketmind/page/home/settings_page.dart';
import 'package:pocketmind/page/home/sync_settings_page.dart';
import 'package:pocketmind/page/home/auth_page.dart';
import 'package:pocketmind/page/settings/platform_accounts_page.dart';
import 'package:pocketmind/page/main_layout.dart';
import 'package:pocketmind/router/route_paths.dart';

/// 全局路由 NavigatorKey，供需要在 BuildContext 之外导航的场景使用
final appNavigatorKey = GlobalKey<NavigatorState>();

/// 全局路由配置
final appRouter = GoRouter(
  navigatorKey: appNavigatorKey,
  initialLocation: RoutePaths.home,
  debugLogDiagnostics: true,
  routes: [
    // 使用 ShellRoute 实现响应式布局 (侧边栏持久化)
    ShellRoute(
      builder: (context, state, child) {
        return MainLayout(child: child);
      },
      routes: [
        // 首页
        GoRoute(
          path: RoutePaths.home,
          builder: (context, state) {
            final isDesktop =
                Platform.isWindows || Platform.isMacOS || Platform.isLinux;
            return isDesktop ? const DesktopHomeScreen() : const HomeScreen();
          },
          routes: [
            // 笔记详情 (嵌套在首页路径下，方便返回)
            GoRoute(
              path: RoutePaths.noteDetail,
              builder: (context, state) {
                // 安全处理：当通过 URL 导航时 (如 Flutter inspect)，extra 可能为 null
                final note = state.extra as Note?;
                if (note == null) {
                  // 返回到首页，避免崩溃
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    context.go(RoutePaths.home);
                  });
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }
                return NoteDetailPage(note: note);
              },
            ),
          ],
        ),

        // 设置页
        GoRoute(
          path: RoutePaths.settings,
          builder: (context, state) => const SettingsPage(),
        ),

        // sync
        GoRoute(
          path: RoutePaths.sync,
          builder: (context, state) => const SyncSettingsPage(),
        ),

        // auth
        GoRoute(
          path: RoutePaths.auth,
          builder: (context, state) => const AuthPage(),
        ),

        // 平台账号管理
        GoRoute(
          path: RoutePaths.platformAccounts,
          builder: (context, state) => const PlatformAccountsPage(),
        ),
      ],
    ),
    // 聊天页 - 全屏，不含侧边栏
    GoRoute(
      path: RoutePaths.chat,
      builder: (context, state) {
        final sessionUuid = state.pathParameters['sessionUuid']!;
        return ChatPage(sessionUuid: sessionUuid);
      },
      routes: [
        // 分支列表页
        GoRoute(
          path: 'branches',
          builder: (context, state) {
            final sessionUuid = state.pathParameters['sessionUuid']!;
            return BranchListPage(sessionUuid: sessionUuid);
          },
        ),
      ],
    ),
  ],

  // 错误处理
  errorBuilder: (context, state) =>
      Scaffold(body: Center(child: Text('路由错误: ${state.error}'))),
);
