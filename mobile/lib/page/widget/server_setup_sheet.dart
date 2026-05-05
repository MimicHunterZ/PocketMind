import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:pocketmind/providers/app_config_provider.dart';
import 'package:pocketmind/util/theme_data.dart';

/// 服务器地址首次配置引导底部弹窗
///
/// 当用户点击 AI Tab 但尚未配置服务器地址时弹出。
/// 用户填入地址并确认后，关闭弹窗，外部逻辑继续跳转到 AI 页面。
class ServerSetupSheet extends ConsumerStatefulWidget {
  const ServerSetupSheet({super.key});

  @override
  ConsumerState<ServerSetupSheet> createState() => _ServerSetupSheetState();
}

class _ServerSetupSheetState extends ConsumerState<ServerSetupSheet> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _isSaving = false;
  String? _errorText;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  String? _validate(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '请填入服务器地址';
    if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
      return '地址需以 http:// 或 https:// 开头';
    }
    return null;
  }

  Future<void> _confirm() async {
    final trimmed = _controller.text.trim();
    final error = _validate(trimmed);
    if (error != null) {
      setState(() => _errorText = error);
      return;
    }

    setState(() {
      _isSaving = true;
      _errorText = null;
    });

    await ref.read(appConfigProvider.notifier).setCustomDomain(trimmed);

    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      // 避免键盘遮挡
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(24.w, 28.h, 24.w, 16.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 拖动指示器
              Center(
                child: Container(
                  width: 36.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: context.theme.dividerColor.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
              ),
              SizedBox(height: 24.h),

              // 标题区域
              Row(
                children: [
                  Icon(
                    Icons.cloud_outlined,
                    size: 28.sp,
                    color: context.colorScheme.primary,
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '配置服务器',
                          style: context.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          '填入你部署的 PocketMind 服务器地址后即可使用 AI 功能',
                          style: context.textTheme.bodySmall?.copyWith(
                            color: context.theme.hintColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 24.h),

              // 地址输入框
              TextField(
                controller: _controller,
                focusNode: _focusNode,
                autofocus: true,
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _confirm(),
                decoration: InputDecoration(
                  labelText: '服务器地址',
                  hintText: 'https://your-server.com',
                  prefixIcon: const Icon(Icons.link),
                  errorText: _errorText,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                ),
                onChanged: (_) {
                  if (_errorText != null) setState(() => _errorText = null);
                },
              ),
              SizedBox(height: 8.h),
              Text(
                '支持域名或 IP，例如 https://pm.example.com 或 http://192.168.1.100:8080',
                style: context.textTheme.bodySmall?.copyWith(
                  color: context.theme.hintColor,
                ),
              ),
              SizedBox(height: 24.h),

              // 确认按钮
              FilledButton(
                onPressed: _isSaving ? null : _confirm,
                style: FilledButton.styleFrom(
                  minimumSize: Size(double.infinity, 48.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                ),
                child: _isSaving
                    ? SizedBox(
                        width: 20.w,
                        height: 20.w,
                        child: const CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('开始使用'),
              ),
              SizedBox(height: 8.h),
            ],
          ),
        ),
      ),
    );
  }
}

/// 弹出服务器配置引导弹窗，返回 true 表示用户已完成配置
Future<bool> showServerSetupSheet(BuildContext context) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => const ServerSetupSheet(),
  );
  return result == true;
}
