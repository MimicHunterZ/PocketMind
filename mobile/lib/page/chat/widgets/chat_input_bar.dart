import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:pocketmind/util/theme_data.dart';

/// 聊天输入栏动作回调。
class ChatInputActions {
  final VoidCallback onCamera;
  final VoidCallback onVoiceStart;
  final VoidCallback onVoiceEnd;

  const ChatInputActions({
    required this.onCamera,
    required this.onVoiceStart,
    required this.onVoiceEnd,
  });
}

/// 底部输入栏。
class ChatInputBar extends StatelessWidget {
  final TextEditingController textController;
  final FocusNode focusNode;
  final bool isVoiceMode;
  final bool hasText;
  final bool isSending;
  final bool isEditMode;
  final VoidCallback onToggleVoice;
  final VoidCallback onSend;
  final ChatBubbleColors colors;
  final ChatInputActions actions;

  const ChatInputBar({
    super.key,
    required this.textController,
    required this.focusNode,
    required this.isVoiceMode,
    required this.hasText,
    required this.isSending,
    required this.isEditMode,
    required this.onToggleVoice,
    required this.onSend,
    required this.colors,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colors.inputBarBackground,
        border: Border(
          top: BorderSide(color: cs.outline.withValues(alpha: 0.2), width: 0.5),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 8.h),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _InputActionButton(
                icon: isVoiceMode
                    ? Icons.keyboard_rounded
                    : Icons.mic_none_rounded,
                onTap: onToggleVoice,
                color: cs.onSurfaceVariant,
              ),
              SizedBox(width: 6.w),
              Expanded(
                child: isVoiceMode
                    ? _VoiceHoldButton(cs: cs, actions: actions)
                    : _TextInput(
                        controller: textController,
                        focusNode: focusNode,
                        enabled: !isSending,
                        hintText: isSending
                            ? '正在回复中…'
                            : isEditMode
                            ? '修改内容后点发送…'
                            : '发消息…',
                        cs: cs,
                      ),
              ),
              SizedBox(width: 6.w),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                transitionBuilder: (child, anim) =>
                    ScaleTransition(scale: anim, child: child),
                child: hasText && !isVoiceMode
                    ? _SendButton(
                        key: const Key('send'),
                        onTap: onSend,
                        isSending: isSending,
                        cs: cs,
                      )
                    : _InputActionButton(
                        key: const Key('camera'),
                        icon: Icons.camera_alt_outlined,
                        onTap: actions.onCamera,
                        color: cs.onSurfaceVariant,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TextInput extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool enabled;
  final String hintText;
  final ColorScheme cs;

  const _TextInput({
    required this.controller,
    required this.focusNode,
    required this.enabled,
    required this.hintText,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      constraints: BoxConstraints(minHeight: 40.h, maxHeight: 120.h),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(22.r),
      ),
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 2.h),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        enabled: enabled,
        maxLines: null,
        textInputAction: TextInputAction.newline,
        style: textTheme.bodyLarge?.copyWith(color: cs.onSurface),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: textTheme.bodyLarge?.copyWith(
            color: cs.onSurfaceVariant.withValues(alpha: 0.6),
          ),
          border: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.symmetric(vertical: 10.h),
        ),
      ),
    );
  }
}

class _VoiceHoldButton extends StatelessWidget {
  final ColorScheme cs;
  final ChatInputActions actions;

  const _VoiceHoldButton({required this.cs, required this.actions});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return GestureDetector(
      onLongPressStart: (_) => actions.onVoiceStart(),
      onLongPressEnd: (_) => actions.onVoiceEnd(),
      child: Container(
        height: 40.h,
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(22.r),
        ),
        alignment: Alignment.center,
        child: Text(
          '按住说话',
          style: textTheme.bodyMedium?.copyWith(
            color: cs.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _InputActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color color;

  const _InputActionButton({
    super.key,
    required this.icon,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40.w,
      height: 40.w,
      child: IconButton(
        icon: Icon(icon, size: 24.sp, color: color),
        onPressed: onTap,
        padding: EdgeInsets.zero,
        splashRadius: 20.r,
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  final VoidCallback onTap;
  final bool isSending;
  final ColorScheme cs;

  const _SendButton({
    super.key,
    required this.onTap,
    required this.isSending,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40.w,
      height: 40.w,
      child: Material(
        color: cs.tertiary,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: isSending ? null : onTap,
          child: Center(
            child: isSending
                ? SizedBox(
                    width: 18.w,
                    height: 18.w,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: cs.onTertiary,
                    ),
                  )
                : Icon(
                    Icons.arrow_upward_rounded,
                    size: 20.sp,
                    color: cs.onTertiary,
                  ),
          ),
        ),
      ),
    );
  }
}
