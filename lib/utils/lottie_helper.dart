import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

/// Lottie 动画工具类
/// 使用 LottieFiles 免费 CDN 的动画 JSON URL
class LottieHelper {
  // ---- 通用 ----
  static const String loading =
      'https://lottie.host/1e39ce44-1c93-45ea-a156-6d44a87d6f05/4lFQfuIWL1.json';

  static const String success =
      'https://lottie.host/da375614-3168-4ace-85f4-a05a23077282/GOx7MpI3OD.json';

  // ---- 聊天 ----
  static const String chatBubble =
      'https://lottie.host/85cb019b-d3d8-4e96-8706-5c0f94e7e67a/gG6Ib1qrUA.json';

  static const String sendPlane =
      'https://lottie.host/56de2805-20d3-41a0-9bfa-e7f1710fdebb/RFjmXlARqF.json';

  // ---- 游戏 ----
  static const String moleIdle =
      'https://lottie.host/e94cc42a-49a5-44b5-93fa-d2a2a6c90bdb/VtCdbDGFcG.json';

  static const String scorePopup =
      'https://lottie.host/8d3077d5-0d4f-49e6-bffe-6c20f9eaaf55/DAr7YfBvN1.json';

  static const String trophy =
      'https://lottie.host/4383d2ed-0ce3-484c-a73d-3ae33b8e6aaa/lg3rn2Yztv.json';

  static const String heartBeat =
      'https://lottie.host/98ae2197-b6de-4df4-9a07-a0676e221754/XvQiWc0d3X.json';

  // ---- 个人中心 ----
  static const String avatarSpin =
      'https://lottie.host/3c4009f4-dee2-49af-ad63-8d4689a2a287/kfQ8QRvDzG.json';

  static const String exitDoor =
      'https://lottie.host/bb834b0b-c7cf-4bad-80ec-d2a747fd6feb/SOlySvuHeD.json';

  // ================================================================
  //  工厂方法
  // ================================================================

  /// 基础 Lottie 组件（含加载中占位符）
  static Widget network(
    String url, {
    double? width,
    double? height,
    BoxFit fit = BoxFit.contain,
    bool repeat = true,
    Widget? placeholder,
  }) {
    return Lottie.network(
      url,
      width: width,
      height: height,
      fit: fit,
      repeat: repeat,
      animate: true,
      errorBuilder: (context, error, stackTrace) {
        return placeholder ??
            const SizedBox(
              width: 48,
              height: 48,
              child: Center(
                child: Icon(Icons.animation, color: Colors.grey),
              ),
            );
      },
      frameBuilder: (context, child, composition) {
        if (composition == null) {
          return placeholder ??
              const SizedBox(
                width: 48,
                height: 48,
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              );
        }
        return child;
      },
    );
  }

  /// 加载转圈（替代 CircularProgressIndicator）
  static Widget loadingIndicator({double size = 48}) {
    return SizedBox(
      width: size,
      height: size,
      child: Lottie.network(
        loading,
        width: size,
        height: size,
        fit: BoxFit.contain,
        repeat: true,
      ),
    );
  }

  /// 聊天 loading 占位
  static Widget chatLoading({double size = 80}) {
    return Center(
      child: Lottie.network(
        chatBubble,
        width: size,
        height: size,
        repeat: true,
      ),
    );
  }
}
