import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:pocketmind/page/widget/creative_toast.dart';
import 'package:pocketmind/page/widget/pm_app_bar.dart';
import 'package:pocketmind/providers/auth_providers.dart';

class AuthPage extends ConsumerStatefulWidget {
  const AuthPage({super.key});

  @override
  ConsumerState<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends ConsumerState<AuthPage> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoginMode = true;
  bool _submitting = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;

    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    if (username.isEmpty || password.isEmpty) {
      CreativeToast.error(
        context,
        title: '信息不完整',
        message: '请输入用户名和密码',
        direction: ToastDirection.bottom,
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final notifier = ref.read(authControllerProvider.notifier);
      if (_isLoginMode) {
        await notifier.login(username: username, password: password);
        if (mounted) {
          CreativeToast.success(
            context,
            title: '登录成功',
            message: '已完成登录',
            direction: ToastDirection.bottom,
          );
        }
      } else {
        await notifier.register(username: username, password: password);
        if (mounted) {
          CreativeToast.success(
            context,
            title: '注册成功',
            message: '已完成注册并登录',
            direction: ToastDirection.bottom,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        CreativeToast.error(
          context,
          title: '操作失败',
          message: e.toString(),
          direction: ToastDirection.bottom,
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final session = ref.watch(authControllerProvider);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: const PMAppBar(title: Text('账号')),
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (session.isLoggedIn) ...[
                  _buildLoggedInView(theme, session),
                ] else ...[
                  _buildAuthForm(theme),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoggedInView(ThemeData theme, AuthSessionState session) {
    return Card(
      color: theme.cardColor,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24.r),
        side: BorderSide(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(32.r),
        child: Column(
          children: [
            Container(
              width: 80.r,
              height: 80.r,
              decoration: BoxDecoration(
                color: theme.colorScheme.tertiary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.person_rounded,
                size: 40.r,
                color: theme.colorScheme.tertiary,
              ),
            ),
            SizedBox(height: 24.h),
            Text(
              '已登录',
              style: theme.textTheme.titleLarge?.copyWith(fontSize: 24.sp),
            ),
            SizedBox(height: 8.h),
            Text(
              '用户ID：${session.userId ?? ''}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.secondary,
              ),
            ),
            SizedBox(height: 32.h),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _submitting
                    ? null
                    : () => ref.read(authControllerProvider.notifier).logout(),
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 16.h),
                  side: BorderSide(color: theme.colorScheme.outline),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
                child: Text(
                  '退出登录',
                  style: TextStyle(
                    color: theme.colorScheme.error,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAuthForm(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          _isLoginMode ? '欢迎回来' : '创建账号',
          style: theme.textTheme.titleLarge?.copyWith(
            fontSize: 32.sp,
            color: theme.colorScheme.primary,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 12.h),
        Text(
          _isLoginMode ? '登录以同步您的第二大脑数据' : '注册账号，开启您的知识管理之旅',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.secondary,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 48.h),

        // 用户名输入框
        _buildTextField(
          theme,
          controller: _usernameController,
          label: '用户名',
          icon: Icons.person_outline_rounded,
          textInputAction: TextInputAction.next,
        ),
        SizedBox(height: 16.h),

        // 密码输入框
        _buildTextField(
          theme,
          controller: _passwordController,
          label: '密码',
          icon: Icons.lock_outline_rounded,
          obscureText: true,
          onSubmitted: (_) => _submit(),
        ),

        SizedBox(height: 32.h),

        // 提交按钮
        FilledButton(
          onPressed: _submitting ? null : _submit,
          style: FilledButton.styleFrom(
            backgroundColor: theme.colorScheme.tertiary,
            foregroundColor: theme.colorScheme.onTertiary,
            padding: EdgeInsets.symmetric(vertical: 16.h),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16.r),
            ),
            elevation: 0,
          ),
          child: _submitting
              ? SizedBox(
                  height: 20.r,
                  width: 20.r,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: theme.colorScheme.onTertiary,
                  ),
                )
              : Text(
                  _isLoginMode ? '登录' : '注册',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),

        SizedBox(height: 24.h),

        // 切换模式按钮
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _isLoginMode ? '还没有账号？' : '已有账号？',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.secondary,
              ),
            ),
            TextButton(
              onPressed: _submitting
                  ? null
                  : () {
                      setState(() {
                        _isLoginMode = !_isLoginMode;
                        _usernameController.clear();
                        _passwordController.clear();
                      });
                    },
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.tertiary,
              ),
              child: Text(
                _isLoginMode ? '立即注册' : '直接登录',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),

        if (_isLoginMode) ...[
          SizedBox(height: 48.h),
          Center(
            child: Text(
              '未登录时依然可以使用全部本地功能\n登录后将启用后端资源抓取/分析能力',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.secondary.withValues(alpha: 0.5),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTextField(
    ThemeData theme, {
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    TextInputAction? textInputAction,
    void Function(String)? onSubmitted,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        textInputAction: textInputAction,
        onSubmitted: onSubmitted,
        style: theme.textTheme.bodyLarge,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: theme.colorScheme.secondary),
          prefixIcon: Icon(icon, color: theme.colorScheme.secondary),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16.r),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16.r),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16.r),
            borderSide: BorderSide(
              color: theme.colorScheme.tertiary.withValues(alpha: 0.5),
              width: 1.5,
            ),
          ),
          filled: true,
          fillColor: theme.cardColor,
          contentPadding: EdgeInsets.symmetric(
            horizontal: 20.w,
            vertical: 16.h,
          ),
        ),
      ),
    );
  }
}
