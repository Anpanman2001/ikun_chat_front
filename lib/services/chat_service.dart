import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import '../config.dart';

class ChatService {
  static String get baseUrl => AppConfig.serverUrl;
  static String get wsUrl => AppConfig.serverUrl;
  static const Duration _timeout = Duration(seconds: 10);
  static const int _maxRetries = 3;

  /// ngrok 免费版需要此 header 跳过浏览器警告页
  static Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'ngrok-skip-browser-warning': 'true',
      };

  // ---- HTTP ----

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
          return data
              .map((json) => types.TextMessage(
                    author: types.User(
                        id: json['user_id'] ?? '',
                        firstName: json['user_name'] ?? ''),
                    createdAt: DateTime.tryParse(json['created_at'] ?? '')
                            ?.millisecondsSinceEpoch ??
                        0,
                    id: (json['id'] ?? '').toString(),
                    text: json['text'] ?? '',
                  ))
              .toList();
        }
        throw Exception('HTTP ${response.statusCode}');
      } catch (e) {
        lastError = e is Exception ? e : Exception(e.toString());
        if (i < _maxRetries - 1) {
          await Future.delayed(Duration(seconds: i + 1)); // 递增等待
        }
      }
    }
    throw lastError ?? Exception('加载消息失败');
  }

  /// 发送消息（带重试）
  static Future<types.TextMessage> sendMessage({
    required String text,
    required String userId,
    required String userName,
  }) async {
    Exception? lastError;
    for (int i = 0; i < _maxRetries; i++) {
      try {
        final response = await http
            .post(
              Uri.parse('$baseUrl/api/messages'),
              headers: _headers,
              body: jsonEncode({
                'text': text,
                'user_id': userId,
                'user_name': userName,
              }),
            )
            .timeout(_timeout);

        if (response.statusCode == 201) {
          final json = jsonDecode(response.body);
          return types.TextMessage(
            author:
                types.User(id: json['user_id'], firstName: json['user_name']),
            createdAt:
                DateTime.parse(json['created_at']).millisecondsSinceEpoch,
            id: json['id'].toString(),
            text: json['text'],
          );
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
