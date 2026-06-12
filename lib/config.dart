/// 聊天服务器地址配置
/// 开发时使用 localhost，需要公网时改为 ngrok 地址
///
/// 获取 ngrok 地址：
/// 1. 下载 ngrok: https://ngrok.com/download
/// 2. 注册: https://dashboard.ngrok.com/signup
/// 3. 运行: ngrok http 3000
/// 4. 将 HTTPS 地址填入下方
class AppConfig {
  /// 服务器地址（不含末尾斜杠）
  static const String serverUrl = 'https://sharpener-hydrated-mammogram.ngrok-free.dev';
}
