import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:pocketmind/providers/app_config_provider.dart';
import 'package:pocketmind/router/route_paths.dart';
import 'dart:io';
import 'package:pocketmind/util/proxy_config.dart';
import 'package:pocketmind/data/repositories/cleanup_service.dart';
import 'package:pocketmind/util/logger_service.dart';
import 'package:pocketmind/providers/infrastructure_providers.dart';
import 'package:pocketmind/page/widget/pm_app_bar.dart';
import '../widget/creative_toast.dart';
import 'package:pocketmind/util/theme_data.dart';

/// 设置页面
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  final _apiKeyController = TextEditingController();
  final _meteCacheTimeController = TextEditingController();
  final _proxyHostController = TextEditingController();
  final _proxyPortController = TextEditingController();
  final _customDomainController = TextEditingController();
  final _log = LogService();

  bool _proxyEnabled = false;
  bool _titleEnabled = false;
  bool _isWaterfallLayout = true;
  bool _isLoading = true;
  bool _highPrecisionNotification = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _proxyHostController.dispose();
    _proxyPortController.dispose();
    _customDomainController.dispose();
    _meteCacheTimeController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final config = ref.read(appConfigProvider);

    setState(() {
      _proxyEnabled = config.proxyEnabled;
      _titleEnabled = config.titleEnabled;
      _proxyHostController.text = config.proxyHost;
      _proxyPortController.text = config.proxyPort.toString();
      _customDomainController.text = config.customDomain;
      _apiKeyController.text = config.linkPreviewApiKey;
      _meteCacheTimeController.text = config.metaCacheTime.toString();
      _isWaterfallLayout = config.waterfallLayoutEnabled;
      _highPrecisionNotification = config.highPrecisionNotification;
      _isLoading = false;
    });
  }

  Future<void> _saveSettings() async {
    final notifier = ref.read(appConfigProvider.notifier);

    // 保存代理设置
    await notifier.setProxyEnabled(_proxyEnabled);
    await notifier.setProxyHost(_proxyHostController.text);
    await notifier.setProxyPort(
      int.tryParse(_proxyPortController.text) ?? 7890,
    );

    // 保存 Title 显示设置
    await notifier.setTitleEnabled(_titleEnabled);

    // 保存 布局 显示设置
    await notifier.setWaterFallLayout(_isWaterfallLayout);

    // 保存 Custom Domain
    await notifier.setCustomDomain(_customDomainController.text);

    // 保存 API Key
    await notifier.setLinkPreviewApiKey(_apiKeyController.text);

    // 保存 缓存时间
    await notifier.setMetaCacheTime(
      int.tryParse(_meteCacheTimeController.text) ?? 10,
    );

    // 保存通知设置
    await notifier.setHighPrecisionNotification(_highPrecisionNotification);

    // 应用代理设置
    _applyProxySettings();

    if (mounted) {
      CreativeToast.success(
        context,
        title: '设置已保存',
        message: '您的设置已成功保存',
        direction: ToastDirection.bottom,
      );
    }
  }

  void _applyProxySettings() {
    final config = ref.read(appConfigProvider);
    if (_proxyEnabled) {
      HttpOverrides.global = GlobalHttpOverrides(
        '${config.proxyHost}:${config.proxyPort}',
        allowBadCertificates: true,
      );
    } else {
      HttpOverrides.global = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        appBar: PMAppBar(title: Text('设置')),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: context.theme.scaffoldBackgroundColor,
      appBar: PMAppBar(
        title: const Text('设置'),
        actions: [
          TextButton(onPressed: _saveSettings, child: const Text('保存')),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.all(16.r),
        children: [
          // 账号
          _buildSectionTitle('账号'),
          _buildAccountCard(),
          SizedBox(height: 24.h),

          // Title 显示设置
          _buildSectionTitle('显示设置'),
          _buildTitleSettingCard(),
          SizedBox(height: 24.h),

          // 提醒设置
          _buildSectionTitle('提醒设置'),
          _buildNotificationCard(),
          SizedBox(height: 24.h),

          // 平台账号
          _buildSectionTitle('平台账号'),
          _buildPlatformAccountsCard(),
          SizedBox(height: 24.h),

          // 局域网同步设置
          _buildSectionTitle('数据同步'),
          _buildSyncSettingCard(),
          SizedBox(height: 24.h),

          // 存储管理
          _buildSectionTitle('存储管理'),
          _buildStorageCard(),
          SizedBox(height: 24.h),

          // API 环境设置
          _buildSectionTitle('服务器设置'),
          _buildServerConfigCard(),
          SizedBox(height: 24.h),

          // 网络代理设置
          _buildSectionTitle('网络代理'),
          _buildProxyCard(),
          SizedBox(height: 24.h),

          // LinkPreview API 设置
          _buildSectionTitle('LinkPreview API'),
          _buildApiKeyCard(),
          SizedBox(height: 24.h),
          // 说明
          _buildInfoCard(),
        ],
      ),
    );
  }

  Widget _buildAccountCard() {
    return Card(
      color: context.theme.cardColor,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.r),
        side: BorderSide(color: context.theme.dividerColor.withValues(alpha: 0.1)),
      ),
      child: ListTile(
        leading: const Icon(Icons.person_outline_rounded),
        title: Text('登录 / 注册', style: context.textTheme.bodyLarge),
        subtitle: Text('未登录也可正常使用，本地功能不受影响', style: context.textTheme.bodySmall),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => context.push(RoutePaths.auth),
      ),
    );
  }

  Widget _buildPlatformAccountsCard() {
    return Card(
      color: context.theme.cardColor,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.r),
        side: BorderSide(color: context.theme.dividerColor.withValues(alpha: 0.1)),
      ),
      child: ListTile(
        leading: const Icon(Icons.language_rounded),
        title: Text('第三方平台', style: context.textTheme.bodyLarge),
        subtitle: Text('小红书等平台账号授权，用于获取链接内容', style: context.textTheme.bodySmall),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => context.push(RoutePaths.platformAccounts),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: EdgeInsets.only(left: 4.w, bottom: 12.h),
      child: Text(title, style: context.textTheme.titleMedium),
    );
  }

  Widget _buildTitleSettingCard() {
    return Card(
      color: context.theme.cardColor,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.r),
        side: BorderSide(color: context.theme.dividerColor.withValues(alpha: 0.1)),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        child: Column(
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('布局排版', style: context.textTheme.bodyLarge),
              subtitle: Text(
                _isWaterfallLayout ? '瀑布流' : '传统列表',
                style: context.textTheme.bodySmall,
              ),
              value: _isWaterfallLayout,
              onChanged: (value) {
                setState(() => _isWaterfallLayout = value);
              },
            ),
            Divider(height: 10.h),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('显示标题字段', style: context.textTheme.bodyLarge),
              subtitle: Text(
                _titleEnabled ? '笔记卡片和编辑时将显示标题' : '隐藏用户笔记标题，仅保留内容',
                style: context.textTheme.bodySmall,
              ),
              value: _titleEnabled,
              onChanged: (value) {
                setState(() => _titleEnabled = value);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationCard() {
    return Card(
      color: context.theme.cardColor,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.r),
        side: BorderSide(color: context.theme.dividerColor.withValues(alpha: 0.1)),
      ),
      child: Padding(
        padding: EdgeInsets.all(16.r),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('高精度提醒', style: context.textTheme.bodyLarge),
              subtitle: Text(
                _highPrecisionNotification
                    ? '使用闹钟通道，耗电量较高但更准时'
                    : '使用省电通道，可能会有几分钟延迟',
                style: context.textTheme.bodySmall,
              ),
              value: _highPrecisionNotification,
              onChanged: (value) {
                setState(() => _highPrecisionNotification = value);
              },
            ),
            SizedBox(height: 8.h),
            Text(
              '提醒强度由系统设置控制，请在系统通知设置中调整',
              style: context.textTheme.bodySmall?.copyWith(
                color: context.theme.hintColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSyncSettingCard() {
    return Card(
      color: context.theme.cardColor,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.r),
        side: BorderSide(color: context.theme.dividerColor.withValues(alpha: 0.1)),
      ),
      child: ListTile(
        leading: Icon(Icons.sync, color: context.colorScheme.primary),
        title: Text('局域网同步', style: context.textTheme.bodyLarge),
        subtitle: Text('在多设备间同步笔记数据', style: context.textTheme.bodySmall),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          context.push(RoutePaths.sync);
        },
      ),
    );
  }

  Widget _buildStorageCard() {
    return Card(
      color: context.theme.cardColor,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.r),
        side: BorderSide(color: context.theme.dividerColor.withValues(alpha: 0.1)),
      ),
      child: Padding(
        padding: EdgeInsets.all(16.r),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.storage, color: context.colorScheme.primary),
                SizedBox(width: 12.w),
                Text('清理数据', style: context.textTheme.bodyLarge),
              ],
            ),
            SizedBox(height: 16.h),
            Text('定期清理已删除的笔记和孤立的图片文件，释放存储空间', style: context.textTheme.bodySmall),
            SizedBox(height: 16.h),
            ElevatedButton.icon(
              onPressed: _performCleanup,
              icon: const Icon(Icons.cleaning_services),
              label: const Text('执行清理'),
              style: ElevatedButton.styleFrom(
                minimumSize: Size(double.infinity, 44.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.r),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _performCleanup() async {
    final confirmed = await showConfirmDialog(
      context,
      title: '确认清理',
      message: '将清理,10天前软删除的所有笔记以及图片',
      cancelText: '取消',
      confirmText: '确认',
    );

    if (confirmed != true) return;

    // 显示加载对话框
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final isar = ref.read(isarProvider);
      final cleanupService = CleanupService(isar);
      final result = await cleanupService.performFullCleanup();

      if (!mounted) return;
      Navigator.pop(context); // 关闭加载对话框

      // 显示结果
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('清理完成'),
          content: Text(
            '清理结果：\n\n'
            '• 删除笔记：${result['notes']} 条\n'
            '• 删除图片：${result['images']} 张',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('确定'),
            ),
          ],
        ),
      );

      _log.i('SettingsPage', 'Cleanup completed: $result');
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // 关闭加载对话框

      _log.e('SettingsPage', 'Cleanup failed: $e');

      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('清理失败'),
          content: Text('清理过程中发生错误：\n$e'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('确定'),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildServerConfigCard() {
    return Card(
      color: context.theme.cardColor,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.r),
        side: BorderSide(color: context.theme.dividerColor.withValues(alpha: 0.1)),
      ),
      child: Padding(
        padding: EdgeInsets.all(16.r),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('后端服务地址', style: context.textTheme.bodyLarge),
            SizedBox(height: 8.h),
            Text(
              '填入你自己部署的服务器地址（必填，AI 功能依赖此配置）',
              style: context.textTheme.bodySmall,
            ),
            SizedBox(height: 16.h),
            TextField(
              controller: _customDomainController,
              decoration: InputDecoration(
                labelText: '服务器地址',
                hintText: 'https://your-server.com 或 http://192.168.1.100:8080',
                prefixIcon: const Icon(Icons.cloud),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.r),
                ),
              ),
              maxLines: 1,
              keyboardType: TextInputType.url,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProxyCard() {
    return Card(
      color: context.theme.cardColor,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.r),
        side: BorderSide(color: context.theme.dividerColor.withValues(alpha: 0.1)),
      ),
      child: Padding(
        padding: EdgeInsets.all(16.r),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 启用开关
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('启用代理', style: context.textTheme.bodyLarge),
              subtitle: Text(
                _proxyEnabled ? '代理已启用' : '代理已禁用',
                style: context.textTheme.bodySmall,
              ),
              value: _proxyEnabled,
              onChanged: (value) {
                setState(() => _proxyEnabled = value);
              },
            ),

            if (_proxyEnabled) ...[
              Divider(height: 32.h),

              // 代理主机
              TextField(
                controller: _proxyHostController,
                decoration: InputDecoration(
                  labelText: '代理主机',
                  hintText: '127.0.0.1',
                  prefixIcon: const Icon(Icons.computer),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                ),
              ),
              SizedBox(height: 16.h),

              // 代理端口
              TextField(
                controller: _proxyPortController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: '代理端口',
                  hintText: '7890',
                  prefixIcon: const Icon(Icons.settings_ethernet),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildApiKeyCard() {
    return Card(
      color: context.theme.cardColor,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.r),
        side: BorderSide(color: context.theme.dividerColor.withValues(alpha: 0.1)),
      ),
      child: Padding(
        padding: EdgeInsets.all(16.r),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('API Key', style: context.textTheme.bodyLarge),
            SizedBox(height: 8.h),
            Text(
              '用于国外网站（X/Twitter/YouTube）链接预览',
              style: context.textTheme.bodySmall,
            ),
            SizedBox(height: 16.h),
            TextField(
              controller: _apiKeyController,
              decoration: InputDecoration(
                hintText: '输入 LinkPreview.net API Key',
                hintStyle: context.textTheme.bodySmall,
                prefixIcon: const Icon(Icons.vpn_key),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.r),
                ),
              ),
              maxLines: 1,
            ),
            Divider(height: 32.h),
            Text(
              '获取的meta元数据进行本地缓存,减少对应api的开销',
              style: context.textTheme.bodySmall,
            ),
            SizedBox(height: 16.h),
            TextField(
              controller: _meteCacheTimeController,
              decoration: InputDecoration(
                hintText: '输入缓存的时间（天)',
                hintStyle: context.textTheme.bodySmall,
                prefixIcon: const Icon(Icons.timer),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.r),
                ),
              ),
              maxLines: 1,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Card(
      color: context.colorScheme.surfaceContainerHighest.withValues(alpha: 0.1),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
      child: Padding(
        padding: EdgeInsets.all(16.r),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: context.colorScheme.surfaceContainerHighest,
                  size: 20.sp,
                ),
                SizedBox(width: 8.w),
                Text(
                  '使用说明',
                  style: context.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12.h),
            _buildInfoItem('• 代理设置', '启用代理后，国外网站的图片才能正常抓取'),
            SizedBox(height: 8.h),
            _buildInfoItem(
              '• API Key',
              '从 linkpreview.net 获取，用于国外网站链接预览',
            ),
            SizedBox(height: 8.h),
            _buildInfoItem('• 国内网站', '国内网站无需代理，自动使用直连方式'),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: context.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: context.colorScheme.surfaceContainerHighest,
          ),
        ),
        SizedBox(height: 4.h),
        Text(content, style: context.textTheme.bodySmall),
      ],
    );
  }
}
