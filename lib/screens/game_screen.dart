import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/chat_service.dart';
import '../models/game_score.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  static const int _totalTime = 60;
  static const int _holeCount = 9;
  static const int _pointsPerHit = 10;

  bool _playing = false;
  int _score = 0;
  int _timeLeft = _totalTime;
  int _bestScore = 0;

  final List<bool> _moles = List.filled(_holeCount, false);
  Timer? _timer;
  Timer? _moleTimer;

  int _moleVisibleMs = 800;
  int _moleIntervalMs = 1500;

  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _loadBestScore();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _moleTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadBestScore() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _bestScore = prefs.getInt('game_best_score') ?? 0);
  }

  Future<void> _saveBestScore() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('game_best_score', _bestScore);
  }

  // ---- 游戏控制 ----

  void _startGame() {
    setState(() {
      _playing = true;
      _score = 0;
      _timeLeft = _totalTime;
      _moleVisibleMs = 800;
      _moleIntervalMs = 1500;
      for (int i = 0; i < _holeCount; i++) {
        _moles[i] = false;
      }
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_playing) return;
      setState(() {
        _timeLeft--;
        if (_timeLeft <= 0) _endGame();
      });
    });

    _scheduleMole();
  }

  void _scheduleMole() {
    if (!_playing) return;
    _moleTimer?.cancel();
    _moleTimer = Timer(Duration(milliseconds: _moleIntervalMs), _popMole);
  }

  void _popMole() {
    if (!_playing) return;

    final emptyHoles = <int>[];
    for (int i = 0; i < _holeCount; i++) {
      if (!_moles[i]) emptyHoles.add(i);
    }
    if (emptyHoles.isEmpty) {
      _scheduleMole();
      return;
    }

    final hole = emptyHoles[_random.nextInt(emptyHoles.length)];
    setState(() => _moles[hole] = true);

    _moleTimer = Timer(Duration(milliseconds: _moleVisibleMs), () {
      if (!_playing) return;
      if (_moles[hole]) setState(() => _moles[hole] = false);
      _scheduleMole();
    });
  }

  void _whack(int hole) {
    if (!_playing || !_moles[hole]) return;

    setState(() {
      _moles[hole] = false;
      _score += _pointsPerHit;

      if (_score % 50 == 0) {
        _moleIntervalMs = max(500, _moleIntervalMs - 100);
        _moleVisibleMs = max(400, _moleVisibleMs - 50);
      }
    });
  }

  void _endGame() {
    _timer?.cancel();
    _moleTimer?.cancel();
    setState(() => _playing = false);

    if (_score > _bestScore) {
      _bestScore = _score;
      _saveBestScore();
    }

    _showGameOverDialog();
  }

  // ---- 弹窗 ----

  void _showGameOverDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('\u6e38\u620f\u7ed3\u675f\uff01'), // 游戏结束！
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '\u672c\u6b21\u5f97\u5206\uff1a$_score', // 本次得分：X
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '\u5386\u53f2\u6700\u9ad8\uff1a$_bestScore', // 历史最高：X
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: _submitScore,
            child: const Text('\u63d0\u4ea4\u5206\u6570'), // 提交分数
          ),
          TextButton(
            onPressed: _showLeaderboard,
            child: const Text('\u67e5\u770b\u6392\u884c\u699c'), // 查看排行榜
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _startGame();
            },
            child: const Text('\u518d\u6765\u4e00\u5c40'), // 再来一局
          ),
        ],
      ),
    );
  }

  Future<void> _submitScore() async {
    try {
      await ChatService.submitScore(_score);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('\u5206\u6570\u63d0\u4ea4\u6210\u529f\uff01'), // 分数提交成功！
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('\u63d0\u4ea4\u5931\u8d25: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _showLeaderboard() async {
    showDialog(
      context: context,
      builder: (ctx) => const LeaderboardDialog(),
    );
  }

  // ---- UI ----

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('\u6253\u5730\u9f20'), // 打地鼠
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // 顶部状态栏
              Row(
                children: [
                  Text(
                    '\u5206\u6570: $_score', // 分数: X
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  Text(
                    '\u65f6\u95f4: ${_timeLeft}s', // 时间: Xs
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: _timeLeft / _totalTime,
                  minHeight: 6,
                  backgroundColor: colorScheme.surfaceContainerHighest,
                  color: _timeLeft > 10 ? colorScheme.primary : Colors.red,
                ),
              ),
              const SizedBox(height: 24),

              // 游戏区 3x3
              Expanded(
                child: GridView.count(
                  crossAxisCount: 3,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  children: List.generate(_holeCount, (i) {
                    return GestureDetector(
                      onTap: () => _whack(i),
                      child: _moles[i] ? _buildMole() : _buildHole(),
                    );
                  }),
                ),
              ),

              // 底部
              if (!_playing) ...[
                Text(
                  '\u6700\u9ad8\u5206: $_bestScore', // 最高分: X
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _startGame,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('\u5f00\u59cb\u6e38\u620f'), // 开始游戏
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      textStyle: const TextStyle(fontSize: 18),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHole() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[300],
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _buildMole() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.brown[400],
        shape: BoxShape.circle,
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: const Center(
        child: Text('\ud83d\udc39', style: TextStyle(fontSize: 32)), // 🐹
      ),
    );
  }
}

// ================================================================
//  排行榜弹窗
// ================================================================

class LeaderboardDialog extends StatefulWidget {
  const LeaderboardDialog({super.key});

  @override
  State<LeaderboardDialog> createState() => _LeaderboardDialogState();
}

class _LeaderboardDialogState extends State<LeaderboardDialog> {
  List<GameScore>? _list;
  Map<String, dynamic>? _myRank;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        ChatService.getLeaderboard(),
        ChatService.getMyRank(),
      ]);
      _list = results[0] as List<GameScore>;
      _myRank = results[1] as Map<String, dynamic>;
    } catch (e) {
      _error = e.toString();
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Center(child: Text('\u6392\u884c\u699c')), // 排行榜
      content: SizedBox(
        width: double.maxFinite,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _loading = true;
                            _error = null;
                          });
                          _load();
                        },
                        child: const Text('\u91cd\u8bd5'), // 重试
                      ),
                    ],
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_list != null)
                        ..._list!.map(_buildRow),
                      if (_list == null || _list!.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            '\u6682\u65e0\u6570\u636e', // 暂无数据
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      if (_myRank != null) ...[
                        const Divider(height: 24),
                        Text(
                          '\u6211\u7684\u6392\u540d\uff1a\u7b2c${_myRank!['rank']}\u540d  \u5206\u6570 ${_myRank!['score']}', // 我的排名：第X名 分数X
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ],
                  ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('\u5173\u95ed'), // 关闭
        ),
      ],
    );
  }

  Widget _buildRow(GameScore item) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: item.isFirst
            ? Colors.amber.shade100
            : item.isSecond
                ? Colors.grey.shade200
                : item.isThird
                    ? Colors.brown.shade100
                    : null,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 36,
            child: Text(
              item.medalEmoji,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(item.nickname)),
          Text('${item.score}', style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
