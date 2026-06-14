import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import '../services/auth_service.dart';
import '../utils/lottie_helper.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with SingleTickerProviderStateMixin {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;

  String? _usernameError;
  String? _passwordError;
  String? _confirmError;

  late final AnimationController _shakeController;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  void _triggerShake() {
    _shakeController.forward(from: 0);
  }

  bool _validate() {
    bool valid = true;
    setState(() {
      final username = _usernameController.text.trim();

      if (username.isEmpty) {
        _usernameError = '请输入用户名';
        valid = false;
      } else if (username.length < 2) {
        _usernameError = '用户名至少 2 个字符';
        valid = false;
      } else if (username.length > 32) {
        _usernameError = '用户名最多 32 个字符';
        valid = false;
      } else {
        _usernameError = null;
      }

      final password = _passwordController.text;
      if (password.isEmpty) {
        _passwordError = '请输入密码';
        valid = false;
      } else if (password.length < 6) {
        _passwordError = '密码至少 6 位';
        valid = false;
      } else {
        _passwordError = null;
      }

      if (_confirmPasswordController.text.isEmpty) {
        _confirmError = '请再次输入密码';
        valid = false;
      } else if (_confirmPasswordController.text != password) {
        _confirmError = '两次密码输入不一致';
        valid = false;
      } else {
        _confirmError = null;
      }
    });
    return valid;
  }

  Future<void> _register() async {
    if (!_validate()) return;

    setState(() => _isLoading = true);

    final result = await AuthService.register(
      username: _usernameController.text.trim(),
      password: _passwordController.text,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result.isSuccess) {
      if (mounted) {
        showFToast(
          context: context,
          title: const Text('注册成功，请登录'),
        );
        Navigator.of(context).pop();
      }
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

    return FScaffold(
      header: FHeader.nested(
        title: const Text('注册账号'),
        titleAlignment: Alignment.center,
        prefixes: [
          FHeaderAction.back(
            onPress: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Lottie 动画
                SizedBox(
                  height: 100,
                  child: LottieHelper.network(
                    LottieHelper.chatBubble,
                    placeholder: Icon(
                      FIcons.userPlus,
                      size: 72,
                      color: theme.colors.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '创建新账号',
                  textAlign: TextAlign.center,
                  style: theme.typography.xl2.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 32),

                // 用户名
                FTextField(
                  control: FTextFieldControl.managed(
                      controller: _usernameController),
                  label: const Text('用户名'),
                  hint: '2-32 个字符',
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
                  hint: '至少 6 位',
                  error: _passwordError != null
                      ? Text(_passwordError!)
                      : null,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),

                // 确认密码
                FTextField.password(
                  control: FTextFieldControl.managed(
                      controller: _confirmPasswordController),
                  label: const Text('确认密码'),
                  hint: '请再次输入密码',
                  error: _confirmError != null
                      ? Text(_confirmError!)
                      : null,
                  textInputAction: TextInputAction.done,
                  onSubmit: (_) => _register(),
                ),
                const SizedBox(height: 24),

                // 注册按钮（失败抖动）
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
                      onPress: _isLoading ? null : _register,
                      size: FButtonSizeVariant.lg,
                      child: _isLoading
                          ? LottieHelper.loadingIndicator(size: 28)
                          : const Text('注 册',
                              style: TextStyle(fontSize: 16)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // 返回登录
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '已有账号？',
                      style: TextStyle(color: theme.colors.mutedForeground),
                    ),
                    FButton(
                      variant: FButtonVariant.ghost,
                      onPress: () => Navigator.of(context).pop(),
                      child: const Text('返回登录'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
