# 1. 启动后端
cd D:\WorkSpace\Flutter\chat\chat-backend
node src/server.js

# 2. 启动 ngrok（固定域名，不会变）
ngrok http --domain=sharpener-hydrated-mammogram.ngrok-free.dev 3000

# 3. 启动前端（config.dart 不用改，直接 run）
cd D:\WorkSpace\Flutter\chat\chat-front
flutter run

# 4. 启动mysql
sc query MySQL57

# 5. TODO
rules tests