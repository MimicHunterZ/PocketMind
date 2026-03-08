import 'package:isar_community/isar.dart';

part 'category.g.dart';

@collection
class Category {
  Id? id;

  /// 全局唯一标识符 (UUID v4)，用于跨设备同步
  @Index(unique: true)
  String? uuid;

  @Index(unique: true)
  late String name; // 分类名称，唯一索引

  String? description; // 分类描述

  /// 分类图标路径，如 'assets/icons/bilibili.svg'
  String? iconPath;

  DateTime? createdTime; // 创建时间

  /// 最后更新时间戳（毫秒），用于增量同步和冲突解决
  @Index()
  int updatedAt = 0;

  /// 软删除标记，true 表示已删除
  bool isDeleted = false;

  /// 服务端分配的单调递增版本号，null 表示本地新建尚未推送
  int? serverVersion;

  Category copyWith({
    Id? id,
    String? uuid,
    String? name,
    String? description,
    String? iconPath,
    DateTime? createdTime,
    int? updatedAt,
    bool? isDeleted,
    int? serverVersion,
  }) {
    return Category()
      ..id = id ?? this.id
      ..uuid = uuid ?? this.uuid
      ..name = name ?? this.name
      ..description = description ?? this.description
      ..iconPath = iconPath ?? this.iconPath
      ..createdTime = createdTime ?? this.createdTime
      ..updatedAt = updatedAt ?? this.updatedAt
      ..isDeleted = isDeleted ?? this.isDeleted
      ..serverVersion = serverVersion ?? this.serverVersion;
  }
}
