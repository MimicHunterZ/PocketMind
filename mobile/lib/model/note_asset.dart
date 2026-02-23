import 'package:isar_community/isar.dart';

part 'note_asset.g.dart';

/// 笔记资产（图片/PDF/视频等），对应后端 assets 表。
///
/// 设计原则：
/// - [noteUuid] 关联所属笔记（不用 Isar 关系，避免跨 isolate 问题）
/// - [metadataJson] 存放格式相关属性，按 type 区分：
///   image → {"width":1920,"height":1080}
///   pdf   → {"pageCount":42}
///   video → {"durationSeconds":120,"width":1280,"height":720}
/// - 展示优先级：localPath → serverUrl → 骨架屏占位
@collection
class NoteAsset {
  Id id = Isar.autoIncrement;

  /// 所属笔记 UUID
  @Index()
  late String noteUuid;

  /// 后端 assets.uuid，上传成功后写入
  @Index(unique: true)
  late String assetUuid;

  /// 格式分类：'image' | 'pdf' | 'video' | 'audio' | 'file'
  late String type;

  /// MIME 类型，如 image/jpeg、image/webp
  late String mime;

  /// 文件字节数
  int fileSize = 0;

  /// 画廊排序（0 = 无序/默认），同笔记下按升序排列
  int sortOrder = 0;

  /// 本地副本相对路径（如 "pocket_images/uuid.webp"），null = 无本地文件
  String? localPath;

  /// 后端 serve URL（如 "/api/assets/images/{uuid}"），null = 尚未同步
  String? serverUrl;

  /// 格式相关元数据 JSON 字符串
  String? metadataJson;

  @Index()
  DateTime createdAt = DateTime.now();
}
