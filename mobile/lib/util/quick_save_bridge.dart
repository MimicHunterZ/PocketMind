import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:pocketmind/core/constants.dart';
import 'package:pocketmind/service/category_service.dart';
import 'package:pocketmind/service/note_service.dart';
import 'package:pocketmind/util/logger_service.dart';
import 'package:pocketmind/util/storage_paths.dart';
import 'package:pocketmind/util/url_helper.dart';

/// iOS「保存到 PocketMind」快捷指令(App Intent)与主 App 之间的桥接。
///
/// ## 背景
/// 快捷指令进程为了「不拉起主 App、做完即走」(openAppWhenRun=false),
/// 无法直接写 Isar(Isar 由主 App 的 Flutter 引擎持有)。因此原生侧
/// (QuickSaveQueue.swift) 只把 `{url, note, categoryId, ts}` 追加写进
/// App Group 容器里的 [_queueFileName];主 App 启动 / 前台时由本桥接
/// [drainQuickSaveQueue] 排空 → addNote(PENDING) → ResourceFetchScheduler
/// 自动续抓。提醒时间不走这条队列,由 Swift 侧在跑指令的那一刻直接注册进系统。
///
/// 反向:[exportCategories] 把当前分类列表导出成 [_categoriesFileName],
/// 供快捷指令填写框的「选分类」展示。
///
/// 仅 iOS 有意义;其它平台所有方法直接 no-op。
class QuickSaveBridge {
  static const String _tag = 'QuickSaveBridge';
  static const String _queueFileName = 'quick_save_queue.json';
  static const String _categoriesFileName = 'categories.json';

  /// 把当前分类导出到 App Group 容器,供快捷指令填写框读取。
  /// 形状与 Swift 侧 QuickSaveCategory 对齐:`[{"id": int, "name": string}]`。
  static Future<void> exportCategories(CategoryService categoryService) async {
    if (!Platform.isIOS) return;
    try {
      final categories = await categoryService.getAllCategories();
      final payload = categories
          .where((c) => c.id != null && !c.isDeleted)
          .map((c) => {'id': c.id, 'name': c.name})
          .toList();

      final file = File(await _resolvePath(_categoriesFileName));
      await file.writeAsString(jsonEncode(payload), flush: true);
      PMlog.d(_tag, '已导出 ${payload.length} 个分类给快捷指令');
    } catch (e) {
      // 导出失败不影响主流程,填写框会回落到默认 home 分类。
      PMlog.w(_tag, '导出分类失败(忽略): $e');
    }
  }

  /// 排空快捷指令队列:逐条 addNote(带 url → 自动置 PENDING),完成后清空队列文件。
  /// 提醒通知已在快捷指令跑的那一刻由 Swift 侧直接注册进系统(见 QuickSaveQueue.swift
  /// 的 scheduleReminder),这里不用管提醒,只管落库。
  ///
  /// 失败安全:整体出错时不删队列,留待下次重试;单条解析失败则跳过该条。
  static Future<void> drainQuickSaveQueue(NoteService noteService) async {
    if (!Platform.isIOS) return;

    final File file;
    try {
      file = File(await _resolvePath(_queueFileName));
      if (!await file.exists()) return;

      final raw = await file.readAsString();
      if (raw.trim().isEmpty) {
        await file.delete();
        return;
      }

      final decoded = jsonDecode(raw);
      if (decoded is! List || decoded.isEmpty) {
        await file.delete();
        return;
      }

      var saved = 0;
      for (final entry in decoded) {
        if (entry is! Map) continue;
        // 快捷指令的「链接」参数其实是任意剪贴板内容,不一定是真 URL
        // (比如用户复制的是纯文字),需要像 main_share.dart 处理系统分享
        // 那样先提取真正的 URL,提取不到就整段当正文,避免被误判成链接笔记。
        final raw = (entry['url'] as String?)?.trim();
        if (raw == null || raw.isEmpty) continue;

        final extractedUrl = UrlHelper.extractHttpsUrl(raw);
        final rawText = extractedUrl != null ? UrlHelper.removeUrls(raw).trim() : raw;

        final note = (entry['note'] as String?)?.trim();
        final categoryId = _asInt(entry['categoryId']) ?? AppConstants.homeCategoryId;

        final contentParts = [
          if (rawText.isNotEmpty) rawText,
          if (note != null && note.isNotEmpty) note,
        ];

        await noteService.addNote(
          title: null,
          content: contentParts.isEmpty ? null : contentParts.join('\n'),
          url: extractedUrl,
          categoryId: categoryId,
        );
        saved++;
      }

      // 全部入库后再删除队列,避免中途失败丢数据。
      await file.delete();
      if (saved > 0) {
        PMlog.d(_tag, '排空快捷指令队列,落库 $saved 条 PENDING 笔记');
      }
    } catch (e) {
      PMlog.e(_tag, '排空快捷指令队列失败(保留队列待下次重试): $e');
    }
  }

  /// 拼出 App Group 容器内目标文件的绝对路径(与原生侧同目录)。
  static Future<String> _resolvePath(String fileName) async {
    final dir = await getSharedContainerPath();
    return p.join(dir, fileName);
  }

  static int? _asInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }
}
