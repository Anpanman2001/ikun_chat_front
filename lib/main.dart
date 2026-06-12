import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'screens/chat_screen.dart';

const _uuid = Uuid();

void main() {
  runApp(const ChatApp());
}

class ChatApp extends StatelessWidget {
  const ChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chat App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: ChatScreen(
        userId: 'user-${_uuid.v4().substring(0, 8)}',
        userName: '用户${_uuid.v4().substring(0, 4)}',
      ),
    );
  }
}
