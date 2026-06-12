import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:uuid/uuid.dart';
import '../services/chat_service.dart';

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
  late final types.User _currentUser;
  late io.Socket _socket;
  bool _initialized = false;
  bool _connected = false;
  String? _errorMessage;
  final _uuid = const Uuid();
  final Set<String> _seenIds = {};
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _currentUser = types.User(id: widget.userId, firstName: widget.userName);
    _init();
  }

  Future<void> _init() async {
    await _loadMessages();
    _connectSocket();
    _startPolling();
    setState(() => _initialized = true);
  }

  void _sortMessages() {
    _messages.sort((a, b) => b.createdAt!.compareTo(a.createdAt!));
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

  // ---- Socket.io（Edge/Web 可用，Android adb reverse 下可能超时） ----
  void _connectSocket() {
    _socket = io.io(ChatService.wsUrl);

    _socket.onConnect((_) {
      debugPrint('Socket 已连接, id=${_socket.id}');
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
      debugPrint('Socket 已重连');
      _pollLatest();
    });
  }

  // ---- HTTP 轮询（Socket 不可用时的备选方案） ----
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
    } catch (_) {
      // 轮询失败静默忽略，下次重试
    }
  }

  // ---- 公共消息处理 ----
  void _addIncomingMessage(dynamic data) {
    final json = Map<String, dynamic>.from(data);
    final serverId = json['id'].toString();
    if (_seenIds.contains(serverId)) return;
    _seenIds.add(serverId);

    final msg = types.TextMessage(
      author: types.User(id: json['user_id'], firstName: json['user_name']),
      createdAt: DateTime.parse(json['created_at']).millisecondsSinceEpoch,
      id: serverId,
      text: json['text'],
    );
    setState(() {
      _messages.add(msg);
      _sortMessages();
    });
  }

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

    ChatService.sendMessage(
      text: text,
      userId: widget.userId,
      userName: widget.userName,
    ).then((serverMsg) {
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
              user: _currentUser,
              showUserAvatars: true,
              showUserNames: true,
            ),
    );
  }
}
