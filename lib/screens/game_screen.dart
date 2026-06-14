import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/chat_service.dart';
import '../services/game_audio.dart';
import '../models/game_score.dart';
import '../utils/lottie_helper.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with TickerProviderStateMixin {
  static const int _totalTime = 60;
  static const int _holeCount = 9;
  static const int _pointsPerHit = 10;

  bool _playing = false;
  int _score = 0;
  int _timeLeft = _totalTime;
  int _bestScore = 0;

  // 每个洞的地鼠状态：0=空, 1=冒出中, 2=等待被敲, 3=被打中, 4=缩回中
  final List<int> _moleStates = List.filled(_holeCount, 0);
  Timer? _timer;
  Timer? _moleTimer;

  int _moleVisibleMs = 800;
  int _moleIntervalMs = 1500;

  final Random _random = Random();

  // 得分飘字动画
  int _popupScore = 0;
  Timer? _popupTimer;

  // 连击
  int _combo = 0;
  int _comboDisplay = 0;
  Timer? _comboTimer;

  // 背景音乐
  bool _bgmPlaying = false;

  @override
  void initState() {
    super.initState();
    _loadBestScore();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _moleTimer?.cancel();
    _popupTimer?.cancel();
    _comboTimer?.cancel();
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
      _combo = 0;
      for (int i = 0; i < _holeCount; i++) {
        _moleStates[i] = 0;
      }
    });

    // 播放背景音乐
    _playBgm();

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_playing) return;
      setState(() {
        _timeLeft--;
        if (_timeLeft <= 0) _endGame();
      });
    });

    _scheduleMole();
  }

  void _playBgm() {
    if (_bgmPlaying) return;
    GameAudio.play('assets/music/ikunmusic.mp3');
    _bgmPlaying = true;
  }

  void _stopBgm() {
    GameAudio.stop();
    _bgmPlaying = false;
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
      if (_moleStates[i] == 0) emptyHoles.add(i);
    }
    if (emptyHoles.isEmpty) {
      _scheduleMole();
      return;
    }

    final hole = emptyHoles[_random.nextInt(emptyHoles.length)];
    setState(() => _moleStates[hole] = 1); // 冒出中

    // 冒出动画结束后进入等待状态
    Future.delayed(const Duration(milliseconds: 200), () {
      if (!_playing || _moleStates[hole] != 1) return;
      setState(() => _moleStates[hole] = 2); // 等待被敲
    });

    _moleTimer = Timer(Duration(milliseconds: _moleVisibleMs), () {
      if (!_playing) return;
      if (_moleStates[hole] == 2 || _moleStates[hole] == 1) {
        setState(() => _moleStates[hole] = 4); // 缩回中
        _combo = 0;
        Future.delayed(const Duration(milliseconds: 200), () {
          if (_moleStates[hole] == 4) setState(() => _moleStates[hole] = 0);
        });
      }
      _scheduleMole();
    });
  }

  void _whack(int hole) {
    if (!_playing || _moleStates[hole] != 2) return;

    _combo++;
    final points = _pointsPerHit * (_combo >= 10 ? 3 : _combo >= 5 ? 2 : 1);

    setState(() {
      _moleStates[hole] = 3; // 被打中
      _score += points;

      // 连击显示
      if (_combo >= 3) {
        _comboDisplay = _combo;
        _comboTimer?.cancel();
        _comboTimer = Timer(const Duration(seconds: 1), () {
          setState(() => _comboDisplay = 0);
        });
      }

      // 得分飘字
      _popupScore = points;
      _popupTimer?.cancel();
      _popupTimer = Timer(const Duration(milliseconds: 600), () {
        if (mounted) setState(() => _popupScore = 0);
      });

      // 难度递增
      if (_score % 50 == 0) {
        _moleIntervalMs = max(500, _moleIntervalMs - 100);
        _moleVisibleMs = max(400, _moleVisibleMs - 50);
      }
    });

    // 被打动画后恢复
    Future.delayed(const Duration(milliseconds: 300), () {
      if (_moleStates[hole] == 3) setState(() => _moleStates[hole] = 0);
    });
  }

  void _endGame() {
    _timer?.cancel();
    _moleTimer?.cancel();
    _stopBgm();
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
        title: const Center(child: Text('游戏结束！')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 奖杯 Lottie 动画
            SizedBox(
              height: 100,
              child: LottieHelper.network(
                LottieHelper.trophy,
                placeholder: const Icon(
                  Icons.emoji_events,
                  size: 64,
                  color: Colors.amber,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '本次得分：$_score',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '历史最高：$_bestScore',
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: _submitScore,
            child: const Text('提交分数'),
          ),
          TextButton(
            onPressed: _showLeaderboard,
            child: const Text('查看排行榜'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _startGame();
            },
            child: const Text('再来一局'),
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
            content: Text('分数提交成功！'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('提交失败: $e'), backgroundColor: Colors.red),
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
        title: const Text('打地鼠'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Stack(
            children: [
              Column(
                children: [
                  // 顶部状态栏
                  Row(
                    children: [
                      Text(
                        '分数: $_score',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w600),
                      ),
                      const Spacer(),
                      // 倒计时（最后10秒心跳动画）
                      if (_playing && _timeLeft <= 10)
                        SizedBox(
                          width: 36,
                          height: 36,
                          child: LottieHelper.network(
                            LottieHelper.heartBeat,
                            width: 36,
                            height: 36,
                          ),
                        ),
                      Text(
                        '时间: ${_timeLeft}s',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: _timeLeft <= 10 ? Colors.red : null,
                        ),
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
                          child: _buildCell(i),
                        );
                      }),
                    ),
                  ),

                  // 底部
                  if (!_playing) ...[
                    Text(
                      '最高分: $_bestScore',
                      style: const TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _startGame,
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('开始游戏'),
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

              // 得分飘字
              if (_popupScore > 0)
                Positioned(
                  top: MediaQuery.of(context).size.height * 0.25,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 1.4, end: 1.0),
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.elasticOut,
                      builder: (context, scale, child) => Transform.scale(
                        scale: scale,
                        child: child,
                      ),
                      child: Text(
                        '+$_popupScore',
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                    ),
                  ),
                ),

              // 连击显示
              if (_comboDisplay >= 3)
                Positioned(
                  top: MediaQuery.of(context).size.height * 0.65,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Text(
                      'Combo x$_comboDisplay',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: _comboDisplay >= 10
                            ? Colors.purple
                            : _comboDisplay >= 5
                                ? Colors.red
                                : Colors.orange,
                        shadows: const [
                          Shadow(color: Colors.black26, blurRadius: 4),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCell(int index) {
    final state = _moleStates[index];
    if (state == 0) return _buildHole();

    // 地鼠用 AnimatedSwitcher 实现四种状态过渡
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: _buildMole(state, key: ValueKey('mole_${index}_$state')),
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

  Widget _buildMole(int state, {Key? key}) {
    final size = _moleSize(state);
    final opacity = _moleOpacity(state);
    final angle = _moleAngle(state);
    final widget = Container(
      key: key,
      decoration: BoxDecoration(
        color: state == 3 ? Colors.orange[300] : Colors.brown[400],
        shape: BoxShape.circle,
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Center(
        child: state == 3
            ? const Text('💥', style: TextStyle(fontSize: 32))
            : const Text('🐹', style: TextStyle(fontSize: 32)),
      ),
    );

    return Transform.scale(
      scale: size,
      child: Opacity(
        opacity: opacity,
        child: Transform.rotate(
          angle: angle,
          child: widget,
        ),
      ),
    );
  }

  // ---- 地鼠状态动画参数 ----
  double _moleSize(int state) {
    switch (state) {
      case 1: return 1.15; // 冒出中弹性放大
      case 2: return 1.0;  // 正常
      case 3: return 0.7;  // 被打中缩小旋转
      case 4: return 0.2;  // 缩回中变小
      default: return 1.0;
    }
  }

  double _moleOpacity(int state) {
    switch (state) {
      case 4: return 0.2;
      default: return 1.0;
    }
  }

  double _moleAngle(int state) {
    switch (state) {
      case 3: return 0.3;  // 被打微微倾斜
      default: return 0;
    }
  }
}

// ================================================================
//  排行榜弹窗（不变）
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
      title: const Center(child: Text('排行榜')),
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
                        child: const Text('重试'),
                      ),
                    ],
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_list != null) ..._list!.map(_buildRow),
                      if (_list == null || _list!.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            '暂无数据',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      if (_myRank != null) ...[
                        const Divider(height: 24),
                        Text(
                          '我的排名：第${_myRank!['rank']}名  分数 ${_myRank!['score']}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ],
                  ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('关闭'),
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
          Text('${item.score}',
              style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
