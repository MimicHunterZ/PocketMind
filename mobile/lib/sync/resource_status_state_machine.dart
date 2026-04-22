import 'package:pocketmind/core/constants.dart';

enum ResourceStatusEvent {
  localCreatedWithUrl,
  fetchStarted,
  fetchSucceeded,
  fetchFailed,
  userForceComplete,
  serverSnapshot,
}

abstract final class ResourceStatusStateMachine {
  static String? reduce({
    required String? current,
    required ResourceStatusEvent event,
    String? incoming,
  }) {
    final normalizedCurrent = _normalize(current);
    final normalizedIncoming = _normalize(incoming);

    if (normalizedCurrent == AppConstants.resourceStatusCrawled) {
      return AppConstants.resourceStatusCrawled;
    }

    switch (event) {
      case ResourceStatusEvent.localCreatedWithUrl:
        return AppConstants.resourceStatusPending;
      case ResourceStatusEvent.fetchStarted:
        if (normalizedCurrent == AppConstants.resourceStatusFailed) {
          return AppConstants.resourceStatusFailed;
        }
        return AppConstants.resourceStatusScraping;
      case ResourceStatusEvent.fetchSucceeded:
        return AppConstants.resourceStatusCrawled;
      case ResourceStatusEvent.fetchFailed:
        if (normalizedCurrent == AppConstants.resourceStatusCrawled) {
          return AppConstants.resourceStatusCrawled;
        }
        return AppConstants.resourceStatusFailed;
      case ResourceStatusEvent.userForceComplete:
        if (normalizedCurrent == AppConstants.resourceStatusCrawled) {
          return AppConstants.resourceStatusCrawled;
        }
        return AppConstants.resourceStatusFailed;
      case ResourceStatusEvent.serverSnapshot:
        if (normalizedIncoming == null) {
          return normalizedCurrent;
        }
        if (normalizedCurrent == AppConstants.resourceStatusFailed &&
            normalizedIncoming != AppConstants.resourceStatusCrawled) {
          return AppConstants.resourceStatusFailed;
        }
        return normalizedIncoming;
    }
  }

  static String? _normalize(String? status) {
    if (status == null) return null;
    final value = status.trim();
    if (value.isEmpty) return null;
    switch (value) {
      case AppConstants.resourceStatusPending:
      case AppConstants.resourceStatusScraping:
      case AppConstants.resourceStatusCrawled:
      case AppConstants.resourceStatusFailed:
        return value;
      default:
        return null;
    }
  }
}
