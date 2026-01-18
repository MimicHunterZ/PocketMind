import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:pocketmind/model/app_config_state.dart';
import 'package:pocketmind/providers/shared_preferences_provider.dart';

part 'app_config_provider.g.dart';

@Riverpod(keepAlive: true)
class AppConfig extends _$AppConfig {
  static const String _keyProxyEnabled = 'proxy_enabled';
  static const String _keyProxyHost = 'proxy_host';
  static const String _keyProxyPort = 'proxy_port';
  static const String _keyLinkPreviewApiKey = 'linkpreview_api_key';
  static const String _metaCacheTime = 'meta_cache_time';
  static const String _keyTitleEnabled = 'title_enabled';
  static const String _keyEnvironment = 'app_environment';
  static const String _isWaterfallLayout = 'waterfall_layout';
  static const String _keySyncAutoStart = 'sync_auto_start';
  static const String _keyReminderShortcuts = 'reminder_shortcuts';
  static const String _keyHighPrecisionNotification =
      'high_precision_notification';
  static const String _keyNotificationIntensity = 'notification_intensity';
  static const String _keyCustomDomain = 'custom_domain';

  @override
  AppConfigState build() {
    final prefs = ref.watch(sharedPreferencesProvider);

    // Load reminder shortcuts
    List<Map<String, String>> reminderShortcuts = [];
    final shortcutsValue = prefs.getString(_keyReminderShortcuts);
    if (shortcutsValue != null) {
      try {
        final List<dynamic> list = json.decode(shortcutsValue);
        reminderShortcuts = list
            .map((e) => Map<String, String>.from(e))
            .toList();
      } catch (e) {
        // ignore error
      }
    }

    // Load environment
    Environment environment = kReleaseMode
        ? Environment.production
        : Environment.development;
    final envString = prefs.getString(_keyEnvironment);
    if (envString == 'staging') {
      environment = Environment.staging;
    } else if (envString == 'production') {
      environment = Environment.production;
    }

    return AppConfigState(
      proxyEnabled: prefs.getBool(_keyProxyEnabled) ?? false,
      proxyHost: prefs.getString(_keyProxyHost) ?? '127.0.0.1',
      proxyPort: prefs.getInt(_keyProxyPort) ?? 7890,
      metaCacheTime: prefs.getInt(_metaCacheTime) ?? 10,
      titleEnabled: prefs.getBool(_keyTitleEnabled) ?? false,
      waterfallLayoutEnabled: prefs.getBool(_isWaterfallLayout) ?? true,
      syncAutoStart: prefs.getBool(_keySyncAutoStart) ?? false,
      reminderShortcuts: reminderShortcuts,
      highPrecisionNotification:
          prefs.getBool(_keyHighPrecisionNotification) ?? false,
      notificationIntensity: prefs.getInt(_keyNotificationIntensity) ?? 2,
      linkPreviewApiKey: prefs.getString(_keyLinkPreviewApiKey) ?? '',
      customDomain: prefs.getString(_keyCustomDomain) ?? '',
      environment: environment,
    );
  }

  Future<void> setProxyEnabled(bool enabled) async {
    await ref
        .read(sharedPreferencesProvider)
        .setBool(_keyProxyEnabled, enabled);
    state = state.copyWith(proxyEnabled: enabled);
  }

  Future<void> setProxyHost(String host) async {
    await ref.read(sharedPreferencesProvider).setString(_keyProxyHost, host);
    state = state.copyWith(proxyHost: host);
  }

  Future<void> setProxyPort(int port) async {
    await ref.read(sharedPreferencesProvider).setInt(_keyProxyPort, port);
    state = state.copyWith(proxyPort: port);
  }

  Future<void> setMetaCacheTime(int day) async {
    await ref.read(sharedPreferencesProvider).setInt(_metaCacheTime, day);
    state = state.copyWith(metaCacheTime: day);
  }

  Future<void> setTitleEnabled(bool enabled) async {
    await ref
        .read(sharedPreferencesProvider)
        .setBool(_keyTitleEnabled, enabled);
    state = state.copyWith(titleEnabled: enabled);
  }

  Future<void> setWaterFallLayout(bool enabled) async {
    await ref
        .read(sharedPreferencesProvider)
        .setBool(_isWaterfallLayout, enabled);
    state = state.copyWith(waterfallLayoutEnabled: enabled);
  }

  Future<void> setSyncAutoStart(bool enabled) async {
    await ref
        .read(sharedPreferencesProvider)
        .setBool(_keySyncAutoStart, enabled);
    state = state.copyWith(syncAutoStart: enabled);
  }

  Future<void> setHighPrecisionNotification(bool enabled) async {
    await ref
        .read(sharedPreferencesProvider)
        .setBool(_keyHighPrecisionNotification, enabled);
    state = state.copyWith(highPrecisionNotification: enabled);
  }

  Future<void> setNotificationIntensity(int level) async {
    await ref
        .read(sharedPreferencesProvider)
        .setInt(_keyNotificationIntensity, level);
    state = state.copyWith(notificationIntensity: level);
  }

  Future<void> setLinkPreviewApiKey(String apiKey) async {
    await ref
        .read(sharedPreferencesProvider)
        .setString(_keyLinkPreviewApiKey, apiKey);
    state = state.copyWith(linkPreviewApiKey: apiKey);
  }

  Future<void> setCustomDomain(String domain) async {
    await ref
        .read(sharedPreferencesProvider)
        .setString(_keyCustomDomain, domain);
    state = state.copyWith(customDomain: domain);
  }

  Future<void> setEnvironment(Environment env) async {
    final envString = env.toString().split('.').last;
    await ref
        .read(sharedPreferencesProvider)
        .setString(_keyEnvironment, envString);
    state = state.copyWith(environment: env);
  }

  Future<void> addReminderShortcut(String name, String time) async {
    final shortcuts = List<Map<String, String>>.from(state.reminderShortcuts);
    if (shortcuts.length >= 5) {
      shortcuts.removeAt(0);
    }
    shortcuts.add({'name': name, 'time': time});

    await ref
        .read(sharedPreferencesProvider)
        .setString(_keyReminderShortcuts, json.encode(shortcuts));
    state = state.copyWith(reminderShortcuts: shortcuts);
  }

  Future<void> removeReminderShortcut(int index) async {
    final shortcuts = List<Map<String, String>>.from(state.reminderShortcuts);
    if (index >= 0 && index < shortcuts.length) {
      shortcuts.removeAt(index);
      await ref
          .read(sharedPreferencesProvider)
          .setString(_keyReminderShortcuts, json.encode(shortcuts));
      state = state.copyWith(reminderShortcuts: shortcuts);
    }
  }

  Future<void> clearAll() async {
    await ref.read(sharedPreferencesProvider).clear();
    // Re-initialize state with defaults
    state = const AppConfigState();
  }
}
