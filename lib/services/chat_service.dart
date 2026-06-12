import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import '../config.dart';

class ChatService {
  static String get baseUrl => AppConfig.serverUrl;
  static String get wsUrl => AppConfig.serverUrl;
  static const Duration _timeout = Duration(seconds: 30);
  static const int _maxRetries = 3;

  /// ngrok 免费版需要此 header 跳过浏览器警告页
  static Map<String, String> get _headers => {
        'ngrok-skip-browser-warning': 'true',
      };

  // ---- HTTP ----

  /// 解析服务器返回的消息，同时支持 text 和 image_url
  static types.Message _parseMessage(Map<String, dynamic> json) {
    final author = types.User(
      id: json['user_id'] ?? '',
      firstName: json['user_name'] ?? '',
    );
    final createdAt = DateTime.tryParse(json['created_at'] ?? '')
            ?.millisecondsSinceEpoch ??
        0;
    final id = (json['id'] ?? '').toString();
    final rawImageUrl = json['image_url'] as String?;

    if (rawImageUrl != null && rawImageUrl.isNotEmpty) {
      // 相对路径转绝对 URL，兼容 localhost / ngrok / 生产环境
      final fullUrl = rawImageUrl.startsWith('/')
          ? '$baseUrl$rawImageUrl'
          : rawImageUrl;
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
        request.headers.addAll({'ngrok-skip-browser-warning': 'true'});
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

  /// 发送消息（带重试），支持纯文本和图片消息
  static Future<types.Message> sendMessage({
    String? text,
    String? imageUrl,
    required String userId,
    required String userName,
  }) async {
    Exception? lastError;
    for (int i = 0; i < _maxRetries; i++) {
      try {
        final body = <String, dynamic>{
          'user_id': userId,
          'user_name': userName,
        };
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
}
