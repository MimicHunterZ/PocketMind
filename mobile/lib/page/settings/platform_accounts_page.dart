import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketmind/providers/infrastructure_providers.dart';
import 'package:pocketmind/service/cookie_manager_service.dart';
import 'package:pocketmind/page/settings/xhs_login_page.dart';
import 'package:pocketmind/page/settings/zhihu_login_page.dart';
import 'package:pocketmind/util/logger_service.dart';
import 'package:pocketmind/util/platform_detector.dart';

/// 平台账号管理页面
///
/// 展示各平台的登录状态，提供登录/退出功能
class PlatformAccountsPage extends ConsumerStatefulWidget {
  const PlatformAccountsPage({super.key});

  @override
  ConsumerState<PlatformAccountsPage> createState() =>
      _PlatformAccountsPageState();
}

class _PlatformAccountsPageState extends ConsumerState<PlatformAccountsPage> {
  static const String _tag = 'PlatformAccountsPage';

  Map<String, _PlatformStatus> _platformStatuses = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPlatformStatuses();
  }

  /// 加载各平台状态
  Future<void> _loadPlatformStatuses() async {
    setState(() => _isLoading = true);

    try {
      final statuses = <String, _PlatformStatus>{};

      for (var platform in PlatformType.getSupportedPlatforms) {
        CookieManagerService cm = ref.read(cookieManagerServiceProvider);
        bool isExpired = await cm.isExpired(platform.identifier);

        DateTime? expiresAt;
        if (isExpired) {
          final cookie = await cm.getCookie(platform.identifier);
          expiresAt = cookie?.expiresAt;
        }

        statuses[platform.identifier] = _PlatformStatus(
          platformId: platform.identifier,
          platformName: platform.displayName,
          isLoggedIn: !isExpired,
          expiresAt: expiresAt,
        );
      }

      setState(() {
        _platformStatuses = statuses;
        _isLoading = false;
      });
    } catch (e) {
      PMlog.e(_tag, '加载平台状态失败: $e');
      setState(() => _isLoading = false);
    }
  }

  /// 处理登录
  Future<void> _handleLogin(String platformId) async {
    Widget? loginPage;

    switch (platformId) {
      case 'xhs':
        loginPage = const XhsLoginPage();
        break;
      case 'zhihu':
        loginPage = const ZhihuLoginPage();
        break;
      default:
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('暂不支持 $platformId 平台登录')));
        return;
    }

    final result = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (context) => loginPage!));

    if (result == true) {
      // 登录成功，刷新状态
      await _loadPlatformStatuses();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('登录成功'), backgroundColor: Colors.green),
        );
      }
    }
  }

  /// 处理退出登录
  Future<void> _handleLogout(String platformId, String platformName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('退出 $platformName'),
        content: const Text('确定要退出登录吗？退出后需要重新登录才能抓取该平台的内容。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('退出'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(cookieManagerServiceProvider).clearCookies(platformId);
      await _loadPlatformStatuses();

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('已退出 $platformName')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('平台账号管理')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _platformStatuses.isEmpty
          ? const Center(
              child: Text('暂无支持的平台', style: TextStyle(color: Colors.grey)),
            )
          : RefreshIndicator(
              onRefresh: _loadPlatformStatuses,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: _platformStatuses.length,
                itemBuilder: (context, index) {
                  final status = _platformStatuses.values.elementAt(index);
                  return _buildPlatformTile(status);
                },
              ),
            ),
    );
  }

  Widget _buildPlatformTile(_PlatformStatus status) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: _getPlatformIcon(status.platformId),
        title: Text(status.platformName),
        subtitle: _buildSubtitle(status),
        trailing: status.isLoggedIn
            ? TextButton(
                onPressed: () =>
                    _handleLogout(status.platformId, status.platformName),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('退出'),
              )
            : ElevatedButton(
                onPressed: () => _handleLogin(status.platformId),
                child: const Text('登录'),
              ),
      ),
    );
  }

  Widget _getPlatformIcon(String platformId) {
    IconData iconData;
    Color iconColor;

    switch (platformId) {
      case 'xhs':
        iconData = Icons.auto_awesome;
        iconColor = Colors.red;
        break;
      case 'zhihu':
        iconData = Icons.question_answer;
        iconColor = Colors.blue;
        break;
      default:
        iconData = Icons.language;
        iconColor = Colors.grey;
    }

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: iconColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(iconData, color: iconColor),
    );
  }

  Widget _buildSubtitle(_PlatformStatus status) {
    if (!status.isLoggedIn) {
      return const Text('未登录', style: TextStyle(color: Colors.grey));
    }

    if (status.expiresAt != null) {
      final daysLeft = status.expiresAt!.difference(DateTime.now()).inDays;
      if (daysLeft <= 3) {
        return Text(
          '即将过期（$daysLeft天后）',
          style: const TextStyle(color: Colors.orange),
        );
      }
      return Text(
        '已登录，$daysLeft天后过期',
        style: const TextStyle(color: Colors.green),
      );
    }

    return const Text('已登录', style: TextStyle(color: Colors.green));
  }
}

/// 平台状态数据类
class _PlatformStatus {
  final String platformId;
  final String platformName;
  final bool isLoggedIn;
  final DateTime? expiresAt;

  _PlatformStatus({
    required this.platformId,
    required this.platformName,
    required this.isLoggedIn,
    this.expiresAt,
  });
}
