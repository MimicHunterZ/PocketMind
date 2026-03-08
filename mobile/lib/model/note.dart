import 'package:isar_community/isar.dart';
import 'category.dart';

part 'note.g.dart';

@collection
class Note {
  Id? id;

  /// 全局唯一标识符 (UUID v4)，用于跨设备同步
  @Index(unique: true)
  String? uuid;

  String? title;

  String? content;

  @Index()
  String? url;

  DateTime? time;

  /// 最后更新时间戳（毫秒），用于增量同步和冲突解决
  @Index()
  int updatedAt = 0;

  /// 软删除标记，true 表示已删除
  bool isDeleted = false;

  // 没有的话都需要默认给 1 即 home 目录
  int categoryId = 1;

  // 定义到Category的关系
  // 也不会有多少浪费，这样不需要再进行转化了
  final category = IsarLink<Category>();

  /// 标签列表
  List<String> tags = [];

  /// 链接/爬虫抓取后的首张预览图路径（用于卡片封面展示），多图存 NoteAsset 集合
  String? previewImageUrl;

  /// 链接预览标题
  String? previewTitle;

  /// 链接预览描述
  String? previewDescription;

  /// 后端返回解析后的 Markdown 正文
  String? previewContent;

  /// 资源抓取状态：SCRAPING / PENDING / CRAWLED / EMBEDDED / FAILED
  ///
  /// 注意：失败时仍保持 previewContent 为 null，遵循"失败静默"。
  String? resourceStatus;

  /// AI 生成的摘要
  String? aiSummary;

  /// 服务端分配的单调递增版本号，null 表示本地新建尚未推送
  int? serverVersion;

  Note copyWith({
    Id? id,
    String? uuid,
    String? title,
    String? content,
    String? url,
    DateTime? time,
    int? updatedAt,
    bool? isDeleted,
    int? categoryId,
    List<String>? tags,
    String? previewImageUrl,
    String? previewTitle,
    String? previewDescription,
    String? previewContent,
    String? resourceStatus,
    String? aiSummary,
    int? serverVersion,
  }) {
    return Note()
      ..id = id ?? this.id
      ..uuid = uuid ?? this.uuid
      ..title = title ?? this.title
      ..content = content ?? this.content
      ..url = url ?? this.url
      ..time = time ?? this.time
      ..updatedAt = updatedAt ?? this.updatedAt
      ..isDeleted = isDeleted ?? this.isDeleted
      ..categoryId = categoryId ?? this.categoryId
      ..tags = tags ?? this.tags
      ..previewImageUrl = previewImageUrl ?? this.previewImageUrl
      ..previewTitle = previewTitle ?? this.previewTitle
      ..previewDescription = previewDescription ?? this.previewDescription
      ..previewContent = previewContent ?? this.previewContent
      ..resourceStatus = resourceStatus ?? this.resourceStatus
      ..aiSummary = aiSummary ?? this.aiSummary
      ..serverVersion = serverVersion ?? this.serverVersion;
  }
}
