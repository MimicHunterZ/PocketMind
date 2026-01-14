import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:pocketmind/api/http_client.dart';
import 'package:pocketmind/providers/http_providers.dart';
import 'package:pocketmind/providers/pm_service_providers.dart';
import 'package:pocketmind/providers/shared_preferences_provider.dart';
import 'package:pocketmind/util/logger_service.dart';

part 'auth_providers.g.dart';

const String _tag = 'AuthController';
const String _keyAuthToken = 'auth_token';
const String _keyAuthUserId = 'auth_user_id';
const String _keyAuthExpiry = 'auth_token_expiry';

class AuthSessionState {
  final String? userId;
  final String? token;
  final DateTime? expiryTime;

  const AuthSessionState({this.userId, this.token, this.expiryTime});

  bool get isLoggedIn =>
      token != null &&
      token!.isNotEmpty &&
      (expiryTime == null || !expiryTime!.isBefore(DateTime.now()));

  AuthSessionState copyWith({
    String? userId,
    String? token,
    DateTime? expiryTime,
  }) {
    return AuthSessionState(
      userId: userId ?? this.userId,
      token: token ?? this.token,
      expiryTime: expiryTime ?? this.expiryTime,
    );
  }
}

@Riverpod(keepAlive: true)
class AuthController extends _$AuthController {
  @override
  AuthSessionState build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final token = prefs.getString(_keyAuthToken);
    final userId = prefs.getString(_keyAuthUserId);
    final expiryMs = prefs.getInt(_keyAuthExpiry);
    final expiryTime = expiryMs != null
        ? DateTime.fromMillisecondsSinceEpoch(expiryMs)
        : null;

    final http = ref.read(httpClientProvider);

    // 设置 401 回调
    http.onUnauthorized = () {
      PMlog.w(_tag, 'Unauthorized! Logging out...');
      logout();
    };

    // 启动时自动恢复 token（未登录则不设置，不影响本地功能）
    if (token != null && token.isNotEmpty) {
      // 检查是否已过期
      if (expiryTime != null && expiryTime.isBefore(DateTime.now())) {
        PMlog.w(_tag, 'Token expired at startup');
        // 延迟清理，避免在 build 中直接修改 state
        Future.microtask(() => logout());
      } else {
        http.setToken(token);
        PMlog.d(_tag, 'Token restored');
      }
    }

    return AuthSessionState(
      userId: userId,
      token: token,
      expiryTime: expiryTime,
    );
  }

  Future<void> login({
    required String username,
    required String password,
  }) async {
    final auth = ref.read(authPmServiceProvider);
    final prefs = ref.read(sharedPreferencesProvider);
    final http = ref.read(httpClientProvider);

    final res = await auth.login(username: username, password: password);
    final expiryTime = DateTime.now().add(
      Duration(seconds: res.expiresInSeconds),
    );

    await prefs.setString(_keyAuthToken, res.token);
    await prefs.setString(_keyAuthUserId, res.userId);
    await prefs.setInt(_keyAuthExpiry, expiryTime.millisecondsSinceEpoch);

    http.setToken(res.token);

    state = AuthSessionState(
      userId: res.userId,
      token: res.token,
      expiryTime: expiryTime,
    );
  }

  Future<void> register({
    required String username,
    required String password,
  }) async {
    final auth = ref.read(authPmServiceProvider);
    final prefs = ref.read(sharedPreferencesProvider);
    final http = ref.read(httpClientProvider);

    final res = await auth.register(username: username, password: password);
    final expiryTime = DateTime.now().add(
      Duration(seconds: res.expiresInSeconds),
    );

    await prefs.setString(_keyAuthToken, res.token);
    await prefs.setString(_keyAuthUserId, res.userId);
    await prefs.setInt(_keyAuthExpiry, expiryTime.millisecondsSinceEpoch);

    http.setToken(res.token);

    state = AuthSessionState(
      userId: res.userId,
      token: res.token,
      expiryTime: expiryTime,
    );
  }

  Future<void> logout() async {
    final prefs = ref.read(sharedPreferencesProvider);
    final HttpClient http = ref.read(httpClientProvider);

    await prefs.remove(_keyAuthToken);
    await prefs.remove(_keyAuthUserId);
    await prefs.remove(_keyAuthExpiry);

    http.clearToken();
    state = const AuthSessionState();
  }
}
