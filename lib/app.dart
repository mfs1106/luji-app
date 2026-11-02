import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'services/reminder_service.dart';
import 'theme/app_theme.dart';

/// 旅记 App 根组件
class LujiApp extends StatelessWidget {
  const LujiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '旅记',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const HomeScreen(),
    );
  }
}

/// 应用启动时初始化本地提醒通道
/// 在 main() 之后由 HomeScreen 首帧触发，避免阻塞启动
Future<void> initReminderChannel() => ReminderService.instance.init();
