import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';

class AuthService {
  static const _keyToken = 'auth_token';
  static const _keyUserId = 'user_id';
  static const _keyUserName = 'user_name';
  static const _keyNickname = 'user_nickname';
  static const _keyAvatar = 'user_avatar';

  static String? _cachedToken;
  static String? _cachedUserId;
  static String? _cachedUserName;
  static String? _cachedNickname;
  static String? _cachedAvatar;

  // ---- Token & User 管理 ----

  static String? get token => _cachedToken;
  static String? get userId => _cachedUserId;
  static String? get userName => _cachedUserName;
  static String? get nickname => _cachedNickname ?? _cachedUserName;
  static String? get avatarUrl => _cachedAvatar;

  /// 从本地存储加载已保存的登录信息
  static Future<bool> loadSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _cachedToken = prefs.getString(_keyToken);
      _cachedUserId = prefs.getString(_keyUserId);
      _cachedUserName = prefs.getString(_keyUserName);
      _cachedNickname = prefs.getString(_keyNickname);
      _cachedAvatar = prefs.getString(_keyAvatar);
      return _cachedToken != null;
    } catch (_) {
      return false;
    }
  }

  /// 保存登录信息到本地
  static Future<void> _saveSession({
    required String token,
    required String userId,
    required String userName,
    required String nickname,
    String? avatarUrl,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyToken, token);
    await prefs.setString(_keyUserId, userId);
    await prefs.setString(_keyUserName, userName);
    await prefs.setString(_keyNickname, nickname);
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      await prefs.setString(_keyAvatar, avatarUrl);
    } else {
      await prefs.remove(_keyAvatar);
    }
    _cachedToken = token;
    _cachedUserId = userId;
    _cachedUserName = userName;
    _cachedNickname = nickname;
    _cachedAvatar = avatarUrl;
  }

  /// 更新缓存的昵称
  static Future<void> updateNickname(String nickname) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyNickname, nickname);
    _cachedNickname = nickname;
  }

  /// 更新缓存的头像
  static Future<void> updateAvatar(String? avatarUrl) async {
    final prefs = await SharedPreferences.getInstance();
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      await prefs.setString(_keyAvatar, avatarUrl);
    } else {
      await prefs.remove(_keyAvatar);
    }
    _cachedAvatar = avatarUrl;
  }

  /// 退出登录，清除本地存储
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyToken);
    await prefs.remove(_keyUserId);
    await prefs.remove(_keyUserName);
    await prefs.remove(_keyNickname);
    await prefs.remove(_keyAvatar);
    _cachedToken = null;
    _cachedUserId = null;
    _cachedUserName = null;
    _cachedNickname = null;
    _cachedAvatar = null;
  }

  // ---- API ----

  static String get _baseUrl => AppConfig.serverUrl;

  static Map<String, String> get _headers => {
        'ngrok-skip-browser-warning': 'true',
        'Content-Type': 'application/json',
      };

  /// 注册
  static Future<AuthResult> register({
    required String username,
    required String password,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/api/register'),
            headers: _headers,
            body: jsonEncode({
              'username': username,
              'password': password,
            }),
          )
          .timeout(const Duration(seconds: 15));

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 201) {
        await _saveSession(
          token: body['token'],
          userId: body['user']['id'],
          userName: body['user']['username'],
          nickname: body['user']['nickname'] ?? username,
          avatarUrl: body['user']['avatar_url'],
        );
        return AuthResult.success();
      }
      return AuthResult.failure(body['error'] ?? '注册失败');
    } catch (e) {
      return AuthResult.failure('网络连接失败，请检查网络');
    }
  }

  /// 登录
  static Future<AuthResult> login({
    required String username,
    required String password,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/api/login'),
            headers: _headers,
            body: jsonEncode({
              'username': username,
              'password': password,
            }),
          )
          .timeout(const Duration(seconds: 15));

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200) {
        await _saveSession(
          token: body['token'],
          userId: body['user']['id'],
          userName: body['user']['username'],
          nickname: body['user']['nickname'] ?? username,
          avatarUrl: body['user']['avatar_url'],
        );
        return AuthResult.success();
      }
      return AuthResult.failure(body['error'] ?? '登录失败');
    } catch (e) {
      return AuthResult.failure('网络连接失败，请检查网络');
    }
  }
}

class AuthResult {
  final bool isSuccess;
  final String? errorMessage;

  AuthResult._({required this.isSuccess, this.errorMessage});

  factory AuthResult.success() => AuthResult._(isSuccess: true);
  factory AuthResult.failure(String error) =>
      AuthResult._(isSuccess: false, errorMessage: error);
}
