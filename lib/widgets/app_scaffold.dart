import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// 页面骨架：状态栏（62px）+ 页头（44px）+ 可滚动内容
/// 与设计稿 S1–S8 的页面结构一致
class AppScaffold extends StatelessWidget {
  final String title;
  final String? headerAction;
  final VoidCallback? onHeaderAction;
  final bool showBack;
  final Widget? headerExtra; // 页头标题右侧的自定义内容
  final List<Widget> children;
  final List<Widget>? bottomBar; // 底部固定操作区
  final EdgeInsets? contentPadding;
  final double gap;

  const AppScaffold({
    super.key,
    required this.title,
    required this.children,
    this.headerAction,
    this.onHeaderAction,
    this.showBack = true,
    this.headerExtra,
    this.bottomBar,
    this.contentPadding,
    this.gap = 14,
  });

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        backgroundColor: AppColors.bg,
        body: SafeArea(
          top: false,
          child: Column(
            children: [
              AppStatusBar(),
              AppHeader(
                title: title,
                showBack: showBack,
                action: headerAction,
                onAction: onHeaderAction,
                extra: headerExtra,
              ),
              Expanded(
                child: ListView.separated(
                  padding: contentPadding ??
                      const EdgeInsets.fromLTRB(
                          AppDimens.screenPadding, 8, AppDimens.screenPadding, 20),
                  itemCount: children.length,
                  separatorBuilder: (_, __) => SizedBox(height: gap),
                  itemBuilder: (_, i) => children[i],
                ),
              ),
              if (bottomBar != null)
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  decoration: const BoxDecoration(
                    color: AppColors.bg,
                    border: Border(top: BorderSide(color: AppColors.border)),
                  ),
                  child: SafeArea(top: false, child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: bottomBar!,
                  )),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 状态栏：高 62，左时间右图标
class AppStatusBar extends StatelessWidget {
  const AppStatusBar({super.key});

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Container(
      height: AppDimens.statusBarHeight + top,
      padding: EdgeInsets.only(left: 24, right: 24, top: top),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text('9:41',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text)),
          Row(
            children: const [
              // 信号
              _SignalBars(),
              SizedBox(width: 6),
              // WiFi
              _WifiIcon(),
              SizedBox(width: 6),
              // 电量
              _BatteryIcon(),
            ],
          ),
        ],
      ),
    );
  }
}

class _SignalBars extends StatelessWidget {
  const _SignalBars();
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 18,
      height: 12,
      child: CustomPaint(painter: _SignalBarsPainter()),
    );
  }
}

class _SignalBarsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = AppColors.text;
    final bars = [
      [0.0, 0.66],
      [0.25, 0.5],
      [0.5, 0.33],
      [0.75, 0.08],
    ];
    for (final b in bars) {
      final x = size.width * b[0];
      final top = size.height * b[1];
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, top, 3, size.height - top),
          const Radius.circular(1),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _WifiIcon extends StatelessWidget {
  const _WifiIcon();
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 16,
      height: 12,
      child: CustomPaint(painter: _WifiPainter()),
    );
  }
}

class _WifiPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.text
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    final cx = size.width / 2;
    // 两段弧 + 圆点
    canvas.drawArc(
      Rect.fromLTWH(cx - 5, 1, 10, 10), -2.4, 4.8, false, paint);
    canvas.drawArc(
      Rect.fromLTWH(cx - 2.4, 4.4, 4.8, 4.8), -2.4, 4.8, false, paint);
    canvas.drawCircle(Offset(cx, size.height - 1.4), 1.3, Paint()..color = AppColors.text);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _BatteryIcon extends StatelessWidget {
  const _BatteryIcon();
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 25,
      height: 12,
      child: CustomPaint(painter: _BatteryPainter()),
    );
  }
}

class _BatteryPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final frame = Paint()
      ..color = AppColors.text
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0.5, 1.5, size.width - 3.5, size.height - 3),
        const Radius.circular(2.5),
      ),
      frame,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width - 2.5, 4.5, 2, 3.5),
        const Radius.circular(1),
      ),
      Paint()..color = AppColors.text,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(2.5, 4, 11, 4),
        const Radius.circular(1),
      ),
      Paint()..color = AppColors.green,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 页头：高 44，左圆形返回键，中标题，右操作
class AppHeader extends StatelessWidget {
  final String title;
  final bool showBack;
  final String? action;
  final VoidCallback? onAction;
  final Widget? extra;

  const AppHeader({
    required this.title,
    required this.showBack,
    this.action,
    this.onAction,
    this.extra,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: AppDimens.headerHeight,
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.screenPadding),
      child: Row(
        children: [
          if (showBack)
            GestureDetector(
              onTap: () => Navigator.of(context).maybePop(),
              child: Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: AppColors.card,
                  shape: BoxShape.circle,
                  boxShadow: [AppShadows.card],
                ),
                child: const Icon(Icons.chevron_left,
                    size: 26, color: AppColors.text),
              ),
            ),
          if (showBack) const SizedBox(width: 12),
          Text(title,
              style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text)),
          const Spacer(),
          if (extra != null) extra!,
          if (action != null)
            GestureDetector(
              onTap: onAction,
              child: Text(action!,
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.primary)),
            ),
        ],
      ),
    );
  }
}
