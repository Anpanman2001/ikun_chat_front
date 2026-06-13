import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import '../config.dart';
import '../models/user_model.dart';
import 'auth_service.dart';

class ChatService {
  static String get baseUrl => AppConfig.serverUrl;
  static String get wsUrl => AppConfig.serverUrl;
  static const Duration _timeout = Duration(seconds: 30);
  static const int _maxRetries = 3;

  /// ngrok 免费版需要此 header 跳过浏览器警告页
  static Map<String, String> get _headers {
    final headers = <String, String>{
      'ngrok-skip-browser-warning': 'true',
    };
    final token = AuthService.token;
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  // ---- HTTP ----

  /// 解析服务器返回的消息，使用 sender_nickname / sender_avatar
  static types.Message _parseMessage(Map<String, dynamic> json) {
    final nickname = json['sender_nickname'] ?? json['user_name'] ?? '';
    final avatarUrl = _toAbsoluteUrl(json['sender_avatar']);
    final author = types.User(
      id: json['user_id'] ?? '',
      firstName: nickname,
      imageUrl: avatarUrl,
    );
    final createdAt = DateTime.tryParse(json['created_at'] ?? '')
            ?.millisecondsSinceEpoch ??
        0;
    final id = (json['id'] ?? '').toString();
    final rawImageUrl = json['image_url'] as String?;

    if (rawImageUrl != null && rawImageUrl.isNotEmpty) {
      final fullUrl = _toAbsoluteUrl(rawImageUrl) ?? rawImageUrl;
      return types.ImageMessage(
        author: author,
        createdAt: createdAt,
        id: id,
        uri: fullUrl,
        name: rawImageUrl.split('/').last,
        size: 0,
      );
    }

    return types.TextMessage(
      author: author,
      createdAt: createdAt,
      id: id,
      text: json['text'] ?? '',
    );
  }

  /// 相对路径转绝对 URL
  static String? _toAbsoluteUrl(dynamic path) {
    if (path == null || (path is String && path.isEmpty)) return null;
    final s = path.toString();
    return s.startsWith('/') ? '$baseUrl$s' : s;
  }

  /// 获取历史消息（带重试）
  static Future<List<types.Message>> fetchMessages() async {
    Exception? lastError;
    for (int i = 0; i < _maxRetries; i++) {
      try {
        final response = await http
            .get(
              Uri.parse('$baseUrl/api/messages'),
              headers: _headers,
            )
            .timeout(_timeout);
        if (response.statusCode == 200) {
          final List<dynamic> data = jsonDecode(response.body);
          return data.map((json) {
            final map = Map<String, dynamic>.from(json);
            return _parseMessage(map);
          }).toList();
        }
        throw Exception('HTTP ${response.statusCode}');
      } catch (e) {
        lastError = e is Exception ? e : Exception(e.toString());
        if (i < _maxRetries - 1) {
          await Future.delayed(Duration(seconds: i + 1));
        }
      }
    }
    throw lastError ?? Exception('加载消息失败');
  }

  /// 上传图片到服务器
  static Future<Map<String, dynamic>> uploadImage(String filePath) async {
    Exception? lastError;
    for (int i = 0; i < _maxRetries; i++) {
      try {
        final request = http.MultipartRequest(
          'POST',
          Uri.parse('$baseUrl/api/upload'),
        );
        request.headers.addAll(_headers);
        request.files.add(
          await http.MultipartFile.fromPath('image', filePath),
        );

        final streamedResponse = await request.send().timeout(_timeout);
        final response = await http.Response.fromStream(streamedResponse);

        if (response.statusCode == 200) {
          return jsonDecode(response.body) as Map<String, dynamic>;
        }
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      } catch (e) {
        lastError = e is Exception ? e : Exception(e.toString());
        if (i < _maxRetries - 1) {
          await Future.delayed(Duration(seconds: i + 1));
        }
      }
    }
    throw lastError ?? Exception('图片上传失败');
  }

  /// 发送消息（带重试），服务器自动从 token 获取用户信息
  static Future<types.Message> sendMessage({
    String? text,
    String? imageUrl,
  }) async {
    Exception? lastError;
    for (int i = 0; i < _maxRetries; i++) {
      try {
        final body = <String, dynamic>{};
        if (text != null && text.isNotEmpty) body['text'] = text;
        if (imageUrl != null && imageUrl.isNotEmpty) body['image_url'] = imageUrl;

        final response = await http
            .post(
              Uri.parse('$baseUrl/api/messages'),
              headers: {
                ..._headers,
                'Content-Type': 'application/json',
              },
              body: jsonEncode(body),
            )
            .timeout(_timeout);

        if (response.statusCode == 201) {
          final json = Map<String, dynamic>.from(jsonDecode(response.body));
          return _parseMessage(json);
        }
        throw Exception('HTTP ${response.statusCode}');
      } catch (e) {
        lastError = e is Exception ? e : Exception(e.toString());
        if (i < _maxRetries - 1) {
          await Future.delayed(Duration(seconds: i + 1));
        }
      }
    }
    throw lastError ?? Exception('发送消息失败');
  }

  // ---- 用户资料 API ----

  /// 获取当前用户资料
  static Future<UserModel> getUserProfile() async {
    for (int i = 0; i < _maxRetries; i++) {
      try {
        final response = await http
            .get(
              Uri.parse('$baseUrl/api/user/profile'),
              headers: _headers,
            )
            .timeout(_timeout);
        if (response.statusCode == 200) {
          return UserModel.fromJson(jsonDecode(response.body));
        }
        throw Exception('HTTP ${response.statusCode}');
      } catch (e) {
        if (i >= _maxRetries - 1) rethrow;
        await Future.delayed(Duration(seconds: i + 1));
      }
    }
    throw Exception('获取用户信息失败');
  }

  /// 修改昵称
  static Future<String> updateNickname(String nickname) async {
    for (int i = 0; i < _maxRetries; i++) {
      try {
        final response = await http
            .put(
              Uri.parse('$baseUrl/api/user/nickname'),
              headers: {
                ..._headers,
                'Content-Type': 'application/json',
              },
              body: jsonEncode({'nickname': nickname}),
            )
            .timeout(_timeout);
        if (response.statusCode == 200) {
          final json = jsonDecode(response.body);
          return json['nickname'] as String;
        }
        final body = jsonDecode(response.body);
        throw Exception(body['error'] ?? '修改昵称失败');
      } catch (e) {
        if (i >= _maxRetries - 1) rethrow;
        await Future.delayed(Duration(seconds: i + 1));
      }
    }
    throw Exception('修改昵称失败');
  }

  /// 修改头像 URL
  static Future<String?> updateAvatar(String? avatarUrl) async {
    for (int i = 0; i < _maxRetries; i++) {
      try {
        final response = await http
            .put(
              Uri.parse('$baseUrl/api/user/avatar'),
              headers: {
                ..._headers,
                'Content-Type': 'application/json',
              },
              body: jsonEncode({'avatar_url': avatarUrl}),
            )
            .timeout(_timeout);
        if (response.statusCode == 200) {
          final json = jsonDecode(response.body);
          return json['avatar_url'] as String?;
        }
        final body = jsonDecode(response.body);
        throw Exception(body['error'] ?? '修改头像失败');
      } catch (e) {
        if (i >= _maxRetries - 1) rethrow;
        await Future.delayed(Duration(seconds: i + 1));
      }
    }
    throw Exception('修改头像失败');
  }
}
