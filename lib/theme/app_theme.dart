import 'package:flutter/material.dart';

/// 旅记 App 设计令牌
/// 与高保真设计稿（8 屏，Ardot 文件）逐值对齐，修改需同步设计稿。
class AppColors {
  AppColors._();

  // 基础色
  static const bg = Color(0xFFF5F6F8); // 页面背景
  static const card = Color(0xFFFFFFFF); // 卡片背景
  static const primary = Color(0xFF2F6BED); // 主色（按钮/链接/路线）
  static const primaryDark = Color(0xFF1E40AF);
  static const text = Color(0xFF16181D); // 主文本
  static const secondary = Color(0xFF6B7280); // 次要文本
  static const faint = Color(0xFF9CA3AF); // 辅助文本
  static const border = Color(0xFFE8EAEF); // 描边/分割线

  // 语义色
  static const green = Color(0xFF16A46A); // 成功/已购/已验票
  static const red = Color(0xFFE5484D); // 目的地 pin/超支
  static const amber = Color(0xFFD97706); // 待购/待办/围栏
  static const purple = Color(0xFF7C5CFC); // 闹钟类图标
  static const meituanYellow = Color(0xFFFFD100); // 美团领券按钮

  // 图标浅色底
  static const blueTint = Color(0xFFE8F1FE);
  static const greenTint = Color(0xFFE8F7EF);
  static const amberTint = Color(0xFFFDF3E3);
  static const purpleTint = Color(0xFFEEF0FE);

  // 地图手绘色
  static const mapBase = Color(0xFFE8EEF9);
  static const mapWater = Color(0xFFBFD8F5);
  static const mapLand = Color(0xFFDCE7F7);
  static const mapBlock = Color(0xFFF3EFE6);
}

/// 圆角 / 间距 / 阴影令牌
class AppDimens {
  AppDimens._();

  static const radiusCard = 16.0;
  static const radiusButton = 14.0;
  static const radiusSmall = 8.0;
  static const radiusPill = 22.0;

  static const screenPadding = 20.0; // 内容左右安全边距
  static const cardPadding = 16.0;
  static const gapCard = 14.0; // 卡片间距
  static const gapList = 10.0; // 列表间距

  static const statusBarHeight = 62.0;
  static const headerHeight = 44.0;
}

class AppShadows {
  AppShadows._();

  /// 白卡投影：0,4 / 16 / 6% 黑
  static const card = BoxShadow(
    color: Color(0x0F0D1233),
    offset: Offset(0, 4),
    blurRadius: 16,
  );

  /// 主按钮投影：0,6 / 16 / 28% 主色
  static const primaryButton = BoxShadow(
    color: Color(0x472F6BED),
    offset: Offset(0, 6),
    blurRadius: 16,
  );
}

class AppTheme {
  AppTheme._();

  static ThemeData get light {
    final base = ThemeData(
      useMaterial3: false,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.bg,
      // 字体留空：iOS 自动 PingFang SC，Android 自动 Noto Sans CJK
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
    );
    return base.copyWith(
      colorScheme: base.colorScheme.copyWith(
        primary: AppColors.primary,
        secondary: AppColors.primary,
        surface: AppColors.card,
      ),
      textTheme: base.textTheme.apply(
        bodyColor: AppColors.text,
        displayColor: AppColors.text,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),
    );
  }
}
