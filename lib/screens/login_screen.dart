import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:video_player/video_player.dart';
import '../services/auth_service.dart';
import '../utils/lottie_helper.dart';
import 'register_screen.dart';
import 'main_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  String? _usernameError;
  String? _passwordError;

  late final AnimationController _shakeController;
  late final VideoPlayerController _videoController;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _videoController = VideoPlayerController.asset('assets/kunkun.mp4')
      ..initialize().then((_) {
        setState(() {});
        _videoController.setLooping(true);
        _videoController.play();
      });
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _shakeController.dispose();
    _videoController.dispose();
    super.dispose();
  }

  void _triggerShake() {
    _shakeController.forward(from: 0);
  }

  bool _validate() {
    bool valid = true;
    setState(() {
      if (_usernameController.text.trim().isEmpty) {
        _usernameError = '请输入坤名';
        valid = false;
      } else if (_usernameController.text.trim().length < 2) {
        _usernameError = '用户名至少 2 个字符';
        valid = false;
      } else {
        _usernameError = null;
      }

      if (_passwordController.text.isEmpty) {
        _passwordError = '请输入密码';
        valid = false;
      } else {
        _passwordError = null;
      }
    });
    return valid;
  }

  Future<void> _login() async {
    if (!_validate()) return;

    setState(() => _isLoading = true);

    final result = await AuthService.login(
      username: _usernameController.text.trim(),
      password: _passwordController.text,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result.isSuccess) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => MainScreen(
            userId: AuthService.userId!,
            userName: AuthService.userName!,
          ),
        ),
      );
    } else {
      _triggerShake();
      if (mounted) {
        showFToast(
          context: context,
          variant: FToastVariant.destructive,
          title: Text(result.errorMessage!),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = FTheme.of(context);
    final isVideoReady = _videoController.value.isInitialized;

    return FScaffold(
      child: Stack(
        children: [
          // 视频背景
          if (isVideoReady)
            Positioned.fill(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _videoController.value.size.width,
                  height: _videoController.value.size.height,
                  child: VideoPlayer(_videoController),
                ),
              ),
            )
          else
            // 视频加载前显示纯色背景
            Positioned.fill(
              child: Container(color: theme.colors.background),
            ),

          // 半透明遮罩
          Positioned.fill(
            child: Container(
              color: Colors.black.withValues(alpha: 0.45),
            ),
          ),

          // 登录内容
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Logo Lottie 动画
                    SizedBox(
                      height: 120,
                      child: LottieHelper.network(
                        LottieHelper.chatBubble,
                        placeholder: Icon(
                          FIcons.messagesSquare,
                          size: 80,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'IKUN',
                      textAlign: TextAlign.center,
                      style: theme.typography.xl3.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '黑子和陈老表不能用',
                      textAlign: TextAlign.center,
                      style: theme.typography.sm.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 40),

                    // 用户名
                    FTextField(
                      control: FTextFieldControl.managed(
                          controller: _usernameController),
                      label: const Text('坤名'),
                      hint: '请输入坤名ID，要English',
                      error: _usernameError != null
                          ? Text(_usernameError!)
                          : null,
                      textInputAction: TextInputAction.next,
                      prefixBuilder: (context, style, variants) =>
                          const Icon(FIcons.user),
                    ),
                    const SizedBox(height: 16),

                    // 密码
                    FTextField.password(
                      control: FTextFieldControl.managed(
                          controller: _passwordController),
                      label: const Text('密码'),
                      hint: '请输入密码',
                      error: _passwordError != null
                          ? Text(_passwordError!)
                          : null,
                      textInputAction: TextInputAction.done,
                      onSubmit: (_) => _login(),
                    ),
                    const SizedBox(height: 24),

                    // 登录按钮（失败抖动）
                    AnimatedBuilder(
                      animation: _shakeController,
                      builder: (context, child) {
                        final offset =
                            (_shakeController.value * 2 - 1) *
                                6 *
                                (1 - _shakeController.value).abs();
                        return Transform.translate(
                          offset: Offset(offset, 0),
                          child: child,
                        );
                      },
                      child: SizedBox(
                        height: 48,
                        child: FButton(
                          onPress: _isLoading ? null : _login,
                          size: FButtonSizeVariant.lg,
                          child: _isLoading
                              ? LottieHelper.loadingIndicator(size: 28)
                              : const Text('登 录',
                                  style: TextStyle(fontSize: 16)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 注册入口
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          '还没有账号？',
                          style: TextStyle(color: Colors.white70),
                        ),
                        FButton(
                          variant: FButtonVariant.ghost,
                          onPress: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const RegisterScreen(),
                              ),
                            );
                          },
                          child: const Text('立即注册'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
