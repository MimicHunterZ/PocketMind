import 'package:isar_community/isar.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../service/notification_service.dart';
import '../service/scraper/platform_scraper_service.dart';

part 'infrastructure_providers.g.dart';

/// Isar 实例 Provider
@Riverpod(keepAlive: true)
Isar isar(Ref ref) {
  throw UnimplementedError('isarProvider must be overridden in main()');
}

/// 通知服务 Provider - 全局单例
@Riverpod(keepAlive: true)
NotificationService notificationService(Ref ref) {
  return NotificationService();
}

/// 平台爬虫服务 Provider - 全局单例
@Riverpod(keepAlive: true)
PlatformScraperService platformScraperService(Ref ref) {
  return PlatformScraperService();
}
