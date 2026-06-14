import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'chat_screen.dart';
import 'game_screen.dart';
import 'profile_screen.dart';

class MainScreen extends StatefulWidget {
  final String userId;
  final String userName;

  const MainScreen({
    super.key,
    required this.userId,
    required this.userName,
  });

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      ChatScreen(userId: widget.userId, userName: widget.userName),
      const GameScreen(),
      ProfileScreen(userName: widget.userName),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: FScaffold(
        footer: FBottomNavigationBar(
          index: _currentIndex,
          onChange: (index) {
            setState(() => _currentIndex = index);
          },
          children: const [
            FBottomNavigationBarItem(
              icon: Icon(FIcons.messagesSquare),
              label: Text('聊天'),
            ),
            FBottomNavigationBarItem(
              icon: Icon(FIcons.gamepad2),
              label: Text('游戏'),
            ),
            FBottomNavigationBarItem(
              icon: Icon(FIcons.user),
              label: Text('我的'),
            ),
          ],
        ),
        child: IndexedStack(
          index: _currentIndex,
          children: _pages,
        ),
      ),
    );
  }
}
