import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:any_link_preview/any_link_preview.dart';

import '../../model/note.dart';

/// 源信息组件，用于显示域名和发布日期
/// 支持本地内容显示 "本地"
class SourceInfo extends StatelessWidget {
  final String? url;
  final String? publishDate;

  const SourceInfo({
    super.key,
    this.url,
    this.publishDate,
  });

  bool get isLocal => url == null || url!.isEmpty;

  String _getDomain(String? url) {
    if (url == null || url.isEmpty) return '本地';
    try {
      final uri = Uri.parse(url);
      String temp = uri.host.replaceFirst('www.', '');
      switch (temp) {
        case 'mp.weixin.qq.com':
          temp = '微信';
          break;
        case 'xiaohongshu.com' || 'xhslink.com':
          temp = '小红书';
          break;
        case 'douyin.com':
          temp = '抖音';
          break;
        case 'zhihu.com':
          temp = '知乎';
          break;
        case 'bilibili.com' || 'b23.tv':
          temp = 'bilibili';
          break;
      }
      return temp;
    } catch (e) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // 域名 • 日期
    final domain = isLocal ? '本地' : _getDomain(url);
    return Row(
      children: [
        Expanded(
          child: Text(
            domain,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: colorScheme.primary.withValues(alpha: 0.7),
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
        if (publishDate != null) ...[
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 6.w),
            child: Text(
              '•',
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.secondary.withValues(alpha: 0.5),
              ),
            ),
          ),
          Text(
            publishDate!,
            style: TextStyle(
              fontSize: 12,
              color: colorScheme.secondary.withValues(alpha: 0.7),
            ),
          ),
        ],
      ],
    );
  }
}
