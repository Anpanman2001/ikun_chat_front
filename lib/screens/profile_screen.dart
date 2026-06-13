import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../config.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../models/user_model.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  final String userName;

  const ProfileScreen({super.key, required this.userName});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  UserModel? _profile;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await ChatService.getUserProfile();
      setState(() {
        _profile = profile;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = '加载失败，下拉刷新重试';
      });
    }
  }

  // ---- 修改昵称 ----
  Future<void> _editNickname() async {
    final controller = TextEditingController(text: _profile?.nickname ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('修改昵称'),
        content: TextField(
          controller: controller,
          maxLength: 20,
          decoration: const InputDecoration(
            hintText: '2-20 个字符',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('确定'),
          ),
        ],
      ),
    );

    if (result == null || result.isEmpty || !mounted) return;
    if (result.length < 2 || result.length > 20) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('昵称长度需在 2-20 个字符之间')),
        );
      }
      return;
    }

    try {
      final newNickname = await ChatService.updateNickname(result);
      await AuthService.updateNickname(newNickname);
      setState(() {
        _profile = UserModel(
          id: _profile!.id,
          username: _profile!.username,
          nickname: newNickname,
          avatarUrl: _profile?.avatarUrl,
        );
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('昵称修改成功'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('修改失败: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ---- 修改头像（从相册或拍照） ----
  Future<void> _editAvatar() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('从相册选择'),
              onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('拍照'),
              onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
            ),
            if (_profile?.avatarUrl != null)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('移除头像', style: TextStyle(color: Colors.red)),
                onTap: () => Navigator.of(ctx).pop(null),
              ),
          ],
        ),
      ),
    );

    // source==null 表示"移除"或"取消"；只有原有头像时才是移除操作
    if (source != null) {
      // 选择图片
      await _pickAndUploadAvatar(source);
    } else if (_profile?.avatarUrl != null) {
      // 移除头像
      await _updateAvatarUrl(null);
    }
    // 否则：用户取消，不操作
  }

  Future<void> _pickAndUploadAvatar(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
      if (picked == null || !mounted) {
        debugPrint('[头像] 用户取消选择');
        return;
      }

      debugPrint('[头像] 已选择图片: ${picked.path}');
      debugPrint('[头像] 开始上传...');

      final uploadResult = await ChatService.uploadImage(picked.path);
      debugPrint('[头像] 上传结果: $uploadResult');

      final relativeUrl = uploadResult['image_url'] as String;
      final fullUrl = '$baseUrl$relativeUrl';
      debugPrint('[头像] 完整URL: $fullUrl');

      debugPrint('[头像] 正在保存到用户资料...');
      await _updateAvatarUrl(fullUrl);
      debugPrint('[头像] 保存成功');
    } catch (e, stack) {
      debugPrint('[头像] 上传失败: $e');
      debugPrint('[头像] 堆栈: $stack');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('上传失败: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _updateAvatarUrl(String? avatarUrl) async {
    try {
      final updated = await ChatService.updateAvatar(avatarUrl);
      await AuthService.updateAvatar(updated);
      setState(() {
        _profile = UserModel(
          id: _profile!.id,
          username: _profile!.username,
          nickname: _profile!.nickname,
          avatarUrl: updated,
        );
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('头像修改成功'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('修改失败: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  static String get baseUrl => AppConfig.serverUrl;

  // ---- 退出 ----
  Future<void> _handleLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('退出登录'),
        content: const Text('确定要退出登录吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('确定退出'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    await AuthService.logout();

    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('我的'),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, style: const TextStyle(color: Colors.grey)),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () {
                          setState(() => _loading = true);
                          _loadProfile();
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text('重试'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadProfile,
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
                    children: [
                      // 头像（点击修改）
                      GestureDetector(
                        onTap: _editAvatar,
                        child: Center(
                          child: Stack(
                            children: [
                              CircleAvatar(
                                radius: 52,
                                backgroundImage: _profile?.avatarUrl != null
                                    ? NetworkImage(_profile!.avatarUrl!)
                                    : null,
                                backgroundColor: _profile?.avatarUrl != null
                                    ? null
                                    : Theme.of(context).colorScheme.primaryContainer,
                                child: _profile?.avatarUrl != null
                                    ? null
                                    : Icon(
                                        Icons.person,
                                        size: 52,
                                        color: Theme.of(context).colorScheme.primary,
                                      ),
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.primary,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.edit,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Center(
                        child: Text(
                          '点击修改头像',
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ),
                      const SizedBox(height: 32),

                      // 昵称（点击修改）
                      _ProfileRow(
                        icon: Icons.badge_outlined,
                        label: '昵称',
                        value: _profile?.nickname ?? '',
                        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                        onTap: _editNickname,
                      ),
                      const Divider(height: 1),

                      // 账号（只读）
                      _ProfileRow(
                        icon: Icons.person_outline,
                        label: '账号',
                        value: _profile?.username ?? widget.userName,
                      ),
                      const Divider(height: 32),

                      // 退出登录
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: OutlinedButton.icon(
                          onPressed: () => _handleLogout(context),
                          icon: const Icon(Icons.logout, color: Colors.red),
                          label: const Text(
                            '退出登录',
                            style: TextStyle(color: Colors.red, fontSize: 16),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.red),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}

/// 个人资料行组件
class _ProfileRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _ProfileRow({
    required this.icon,
    required this.label,
    required this.value,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label, style: const TextStyle(color: Colors.grey, fontSize: 14)),
      subtitle: Text(value, style: const TextStyle(fontSize: 16)),
      trailing: trailing,
      onTap: onTap,
    );
  }
}

