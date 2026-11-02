import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 环形图（CustomPainter）：消费构成占比
/// 与设计稿 S4 一致：分段弧 + 中心留白
class DonutChart extends StatelessWidget {
  final List<DonutSegment> segments;
  final double size;
  final double strokeWidth;

  const DonutChart({
    super.key,
    required this.segments,
    this.size = 72,
    this.strokeWidth = 8,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _DonutPainter(segments, strokeWidth)),
    );
  }
}

class DonutSegment {
  final double value; // 数值（用于计算占比）
  final Color color;

  const DonutSegment(this.value, this.color);
}

class _DonutPainter extends CustomPainter {
  final List<DonutSegment> segments;
  final double strokeWidth;

  _DonutPainter(this.segments, this.strokeWidth);

  @override
  void paint(Canvas canvas, Size size) {
    final total = segments.fold<double>(0, (s, e) => s + e.value);
    if (total <= 0) return;
    final rect = Rect.fromLTWH(
      strokeWidth / 2,
      strokeWidth / 2,
      size.width - strokeWidth,
      size.height - strokeWidth,
    );
    // 背景圆环
    final bgPaint = Paint()
      ..color = const Color(0xFFF0F2F5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawArc(rect, 0, math.pi * 2, false, bgPaint);

    var start = -math.pi / 2; // 12 点方向起笔
    for (final seg in segments) {
      final sweep = seg.value / total * math.pi * 2;
      final paint = Paint()
        ..color = seg.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(rect, start, sweep, false, paint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) =>
      old.segments != segments || old.strokeWidth != strokeWidth;
}

/// 环形图中心文字（62% / 预算已用）
class DonutCenterLabel extends StatelessWidget {
  final String value;
  final String label;

  const DonutCenterLabel({super.key, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(value,
            style: const TextStyle(
                fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text)),
        const SizedBox(height: 1),
        Text(label,
            style: const TextStyle(fontSize: 9, color: AppColors.secondary)),
      ],
    );
  }
}
