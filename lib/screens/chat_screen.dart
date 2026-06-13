import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:image_picker/image_picker.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:uuid/uuid.dart';
import '../services/chat_service.dart';
import '../services/auth_service.dart';

class ChatScreen extends StatefulWidget {
  final String userId;
  final String userName;

  const ChatScreen({
    super.key,
    required this.userId,
    required this.userName,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final List<types.Message> _messages = [];
  late types.User _currentUser;
  late io.Socket _socket;
  bool _initialized = false;
  bool _connected = false;
  String? _errorMessage;
  final _uuid = const Uuid();
  final Set<String> _seenIds = {};
  Timer? _pollTimer;
  final _imagePicker = ImagePicker();
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _currentUser = _buildCurrentUser();
    _init();
  }

  types.User _buildCurrentUser() {
    final nickname = AuthService.nickname ?? widget.userName;
    final avatar = AuthService.avatarUrl;
    return types.User(
      id: widget.userId,
      firstName: nickname,
      imageUrl: avatar != null && avatar.isNotEmpty
          ? (avatar.startsWith('/') ? '${ChatService.baseUrl}$avatar' : avatar)
          : null,
    );
  }

  Future<void> _init() async {
    await _loadMessages();
    _connectSocket();
    _startPolling();
    setState(() => _initialized = true);
  }

  void _sortMessages() {
    _messages.sort((a, b) => (b.createdAt ?? 0).compareTo(a.createdAt ?? 0));
  }

  Future<void> _loadMessages() async {
    try {
      final messages = await ChatService.fetchMessages();
      setState(() {
        _messages.clear();
        _seenIds.clear();
        for (final m in messages) {
          _seenIds.add(m.id);
        }
        _messages.addAll(messages);
        _sortMessages();
        _errorMessage = null;
      });
    } catch (e) {
      debugPrint('加载消息失败: $e');
      if (_messages.isEmpty) {
        setState(() => _errorMessage = '无法连接到服务器，请检查网络');
      }
    }
  }

  // ---- Socket.io ----
  void _connectSocket() {
    _socket = io.io(ChatService.wsUrl);

    _socket.onConnect((_) {
      setState(() => _connected = true);
    });

    _socket.onConnectError((err) {
      debugPrint('Socket 连接失败(将用轮询): $err');
    });

    _socket.on('new_message', (data) {
      if (data == null) return;
      _addIncomingMessage(data);
    });

    _socket.onDisconnect((_) {
      setState(() => _connected = false);
    });

    _socket.onReconnect((_) {
      _pollLatest();
    });
  }

  // ---- HTTP 轮询 ----
  void _startPolling() {
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) => _pollLatest());
  }

  Future<void> _pollLatest() async {
    try {
      final latest = await ChatService.fetchMessages();
      for (final msg in latest) {
        if (!_seenIds.contains(msg.id)) {
          _seenIds.add(msg.id);
          setState(() {
            _messages.add(msg);
            _sortMessages();
          });
        }
      }
      if (_errorMessage != null && _messages.isNotEmpty) {
        setState(() => _errorMessage = null);
      }
    } catch (_) {}
  }

  void _addIncomingMessage(dynamic data) {
    final json = Map<String, dynamic>.from(data);
    final serverId = json['id'].toString();
    if (_seenIds.contains(serverId)) return;
    _seenIds.add(serverId);

    final msg = _parseIncomingMessage(json, serverId);
    setState(() {
      _messages.add(msg);
      _sortMessages();
    });
  }

  types.Message _parseIncomingMessage(Map<String, dynamic> json, String id) {
    final nickname = json['sender_nickname'] ?? json['user_name'] ?? '';
    var avatarUrl = json['sender_avatar'] as String?;
    if (avatarUrl != null && avatarUrl.startsWith('/')) {
      avatarUrl = '${ChatService.baseUrl}$avatarUrl';
    }
    final author = types.User(
      id: json['user_id'] ?? '',
      firstName: nickname,
      imageUrl: avatarUrl,
    );
    final createdAt =
        DateTime.parse(json['created_at']).millisecondsSinceEpoch;
    final rawImageUrl = json['image_url'] as String?;

    if (rawImageUrl != null && rawImageUrl.isNotEmpty) {
      final fullUrl = rawImageUrl.startsWith('/')
          ? '${ChatService.baseUrl}$rawImageUrl'
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

  // ---- 发送文字消息 ----
  void _handleSendPressed(types.PartialText message) {
    final text = message.text.trim();
    if (text.isEmpty) return;

    final tempId = _uuid.v4();
    final localMsg = types.TextMessage(
      author: _currentUser,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      id: tempId,
      text: text,
    );
    setState(() {
      _messages.add(localMsg);
      _sortMessages();
    });

    ChatService.sendMessage(text: text).then((serverMsg) {
      setState(() {
        final idx = _messages.indexWhere((m) => m.id == tempId);
        if (idx != -1) {
          _messages[idx] = serverMsg;
          _seenIds.add(serverMsg.id);
        }
      });
    }).catchError((e) {
      debugPrint('发送消息失败: $e');
      setState(() {
        final idx = _messages.indexWhere((m) => m.id == tempId);
        if (idx != -1) {
          _messages[idx] = (_messages[idx] as types.TextMessage).copyWith(
            metadata: {'failed': true},
          );
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('发送失败，请重试'), duration: Duration(seconds: 2)),
        );
      }
    });
  }

  // ---- 发送图片消息 ----
  Future<void> _handleAttachmentPressed() async {
    if (_isUploading) return;

    final XFile? pickedFile = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1920,
      maxHeight: 1920,
    );

    if (pickedFile == null || !mounted) return;

    final file = File(pickedFile.path);
    final fileName = pickedFile.name;

    final tempId = _uuid.v4();
    final localMsg = types.ImageMessage(
      author: _currentUser,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      id: tempId,
      uri: pickedFile.path,
      name: fileName,
      size: await file.length(),
    );
    setState(() {
      _messages.add(localMsg);
      _sortMessages();
    });

    setState(() => _isUploading = true);

    try {
      final uploadResult = await ChatService.uploadImage(pickedFile.path);
      final imageUrl = uploadResult['image_url'] as String;

      final serverMsg = await ChatService.sendMessage(imageUrl: imageUrl);

      setState(() {
        final idx = _messages.indexWhere((m) => m.id == tempId);
        if (idx != -1) {
          _messages[idx] = serverMsg;
          _seenIds.add(serverMsg.id);
        }
      });
    } catch (e) {
      debugPrint('图片上传失败: $e');
      setState(() {
        final idx = _messages.indexWhere((m) => m.id == tempId);
        if (idx != -1) {
          _messages[idx] = (_messages[idx] as types.ImageMessage).copyWith(
            metadata: {'failed': true},
          );
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('图片发送失败，请重试'), duration: Duration(seconds: 2)),
        );
      }
    } finally {
      setState(() => _isUploading = false);
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _socket.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('聊天室'),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Icon(
              Icons.circle,
              size: 12,
              color: _connected ? Colors.green : Colors.orange,
            ),
          ),
        ],
      ),
      body: _errorMessage != null && _messages.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(_errorMessage!, style: const TextStyle(color: Colors.grey)),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() => _errorMessage = null);
                      _loadMessages();
                      if (!_socket.connected) _socket.connect();
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('重试'),
                  ),
                ],
              ),
            )
          : Chat(
              messages: _messages,
              onSendPressed: _handleSendPressed,
              onAttachmentPressed: _handleAttachmentPressed,
              user: _currentUser,
              showUserAvatars: true,
              showUserNames: true,
            ),
    );
  }
}
