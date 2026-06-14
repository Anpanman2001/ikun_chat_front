package com.example.chatfront;

import android.content.res.AssetFileDescriptor;
import android.media.MediaPlayer;
import android.util.Log;
import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;

public class GameMainActivity extends FlutterActivity {
    private static final String TAG = "GameAudio";
    private static final String CHANNEL = "com.example.chatfront/audio";
    private MediaPlayer mediaPlayer;

    @Override
    public void configureFlutterEngine(FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);
        Log.d(TAG, "=== configureFlutterEngine CALLED ===");

        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL)
            .setMethodCallHandler((call, result) -> {
                Log.d(TAG, "=== Method call: " + call.method + " ===");
                switch (call.method) {
                    case "play":
                        String asset = call.argument("asset");
                        Log.d(TAG, "play: " + asset);
                        playAudio(asset);
                        result.success(null);
                        break;
                    case "stop":
                        Log.d(TAG, "stop");
                        stopAudio();
                        result.success(null);
                        break;
                    case "release":
                        Log.d(TAG, "release");
                        releaseAudio();
                        result.success(null);
                        break;
                    default:
                        result.notImplemented();
                        break;
                }
            });
    }

    private void playAudio(String assetPath) {
        try {
            stopAudio();
            mediaPlayer = new MediaPlayer();

            String flutterPath = "flutter_assets/" + assetPath;
            Log.d(TAG, "尝试路径: " + flutterPath);

            try {
                String[] files = getAssets().list("flutter_assets/");
                if (files != null) {
                    Log.d(TAG, "flutter_assets/: " + String.join(", ", java.util.Arrays.asList(files)));
                }
            } catch (Exception ignored) {}

            AssetFileDescriptor afd = null;
            try {
                afd = getAssets().openFd(flutterPath);
                Log.d(TAG, "打开成功: " + flutterPath + " size=" + afd.getLength());
            } catch (Exception e) {
                Log.w(TAG, "失败: " + flutterPath + " -> " + e.getMessage());
                try {
                    afd = getAssets().openFd(assetPath);
                    Log.d(TAG, "打开成功(direct): " + assetPath);
                } catch (Exception e2) {
                    Log.w(TAG, "也失败: " + assetPath + " -> " + e2.getMessage());
                }
            }

            if (afd == null) {
                Log.e(TAG, "所有路径都失败了");
                return;
            }

            mediaPlayer.setDataSource(afd.getFileDescriptor(), afd.getStartOffset(), afd.getLength());
            afd.close();
            mediaPlayer.setLooping(true);
            mediaPlayer.prepare();
            mediaPlayer.start();
            Log.d(TAG, "=== MediaPlayer 开始播放，循环模式 ===");
        } catch (Exception e) {
            Log.e(TAG, "异常: " + e.getMessage(), e);
        }
    }

    private void stopAudio() {
        try {
            if (mediaPlayer != null) {
                if (mediaPlayer.isPlaying()) mediaPlayer.stop();
                mediaPlayer.release();
                Log.d(TAG, "MediaPlayer 已释放");
            }
        } catch (Exception e) {
            Log.w(TAG, "stopAudio: " + e.getMessage());
        }
        mediaPlayer = null;
    }

    private void releaseAudio() {
        stopAudio();
    }

    @Override
    protected void onDestroy() {
        releaseAudio();
        super.onDestroy();
    }
}
