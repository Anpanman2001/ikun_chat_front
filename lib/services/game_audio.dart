import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 游戏音频服务 — 通过 MethodChannel 调用 Android 原生 MediaPlayer
class GameAudio {
  static const _channel = MethodChannel('com.example.chatfront/audio');

  /// 循环播放 assets 中的音乐文件
  /// [assetPath] 例如 'assets/music/ikunmusic.mp3'
  static Future<void> play(String assetPath) async {
    try {
      debugPrint('GameAudio: play() -> $assetPath');
      await _channel.invokeMethod('play', {'asset': assetPath});
      debugPrint('GameAudio: play() 调用成功');
    } catch (e) {
      debugPrint('GameAudio: play() 失败 - $e');
    }
  }

  /// 停止播放
  static Future<void> stop() async {
    try {
      debugPrint('GameAudio: stop()');
      await _channel.invokeMethod('stop');
    } catch (e) {
      debugPrint('GameAudio: stop() 失败 - $e');
    }
  }

  /// 释放资源
  static Future<void> release() async {
    try {
      debugPrint('GameAudio: release()');
      await _channel.invokeMethod('release');
    } catch (e) {
      debugPrint('GameAudio: release() 失败 - $e');
    }
  }
}
