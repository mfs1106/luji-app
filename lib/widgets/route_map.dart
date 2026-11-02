import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 手绘风格示意地图（S2 智能地图 / S7 围栏地图）
/// 说明：自绘示意图，非精确比例；正式版接入高德地图 SDK 后由 SDK 渲染
class SketchMap extends StatelessWidget {
  final double width;
  final double height;
  final List<MapPin> pins; // 编号 pin
  final MapPin? destination; // 红色目的地 pin
  final List<GeoCircle> geoCircles; // 地理围栏虚线圆
  final bool showUserLocation;
  final String? overlayText; // 摘要浮层文案

  const SketchMap({
    super.key,
    this.width = 326,
    this.height = 356,
    this.pins = const [],
    this.destination,
    this.geoCircles = const [],
    this.showUserLocation = true,
    this.overlayText,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _SketchMapPainter(
                  pins: pins,
                  destination: destination,
                  geoCircles: geoCircles,
                  showUserLocation: showUserLocation,
                ),
              ),
            ),
            if (overlayText != null)
              Positioned(
                left: 12,
                bottom: 12,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.94),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                            color: AppColors.primary, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 6),
                      Text(overlayText!,
                          style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppColors.text)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class MapPin {
  final double x; // 0~1 相对坐标
  final double y;
  final int number;
  final Color color;

  const MapPin(this.x, this.y, this.number, {this.color = AppColors.primary});
}

class GeoCircle {
  final double x;
  final double y;
  final double radius; // 相对短边的比例
  final Color color;

  const GeoCircle(this.x, this.y, this.radius, {this.color = AppColors.primary});
}

class _SketchMapPainter extends CustomPainter {
  final List<MapPin> pins;
  final MapPin? destination;
  final List<GeoCircle> geoCircles;
  final bool showUserLocation;

  _SketchMapPainter({
    required this.pins,
    required this.destination,
    required this.geoCircles,
    required this.showUserLocation,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // 1. 基底 + 水域（右上岛屿）
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, w, h), const Radius.circular(10)),
      Paint()..color = AppColors.mapBase,
    );
    final water = Path()
      ..moveTo(w * 0.71, 0)
      ..lineTo(w, 0)
      ..lineTo(w, h * 0.39)
      ..cubicTo(w * 0.92, h * 0.47, w * 0.82, h * 0.49, w * 0.72, h * 0.45)
      ..cubicTo(w * 0.66, h * 0.42, w * 0.61, h * 0.34, w * 0.61, h * 0.2)
      ..cubicTo(w * 0.61, h * 0.1, w * 0.66, h * 0.03, w * 0.71, 0)
      ..close();
    canvas.drawPath(water, Paint()..color = AppColors.mapWater);

    // 2. 底部水岸
    final shore = Path()
      ..moveTo(0, h * 0.77)
      ..cubicTo(w * 0.12, h * 0.72, w * 0.22, h * 0.76, w * 0.3, h * 0.83)
      ..cubicTo(w * 0.38, h * 0.91, w * 0.49, h * 0.93, w * 0.6, h * 0.89)
      ..cubicTo(w * 0.72, h * 0.85, w * 0.86, h * 0.88, w, h * 0.83)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(shore, Paint()..color = AppColors.mapLand);

    // 3. 街区
    final block = Paint()..color = AppColors.mapBlock;
    void drawBlock(double x, double y, double bw, double bh) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(w * x, h * y, w * bw, h * bh), const Radius.circular(4)),
        block);
    }

    drawBlock(0.07, 0.1, 0.18, 0.17);
    drawBlock(0.29, 0.1, 0.14, 0.17);
    drawBlock(0.07, 0.36, 0.14, 0.15);
    drawBlock(0.29, 0.36, 0.18, 0.15);
    drawBlock(0.07, 0.6, 0.18, 0.13);
    drawBlock(0.29, 0.6, 0.14, 0.13);

    // 4. 道路
    final road = Paint()
      ..color = Colors.white
      ..strokeWidth = 7
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(0, h * 0.32), Offset(w, h * 0.32), road);
    canvas.drawLine(Offset(0, h * 0.55), Offset(w, h * 0.55), road);
    canvas.drawLine(Offset(w * 0.27, 0), Offset(w * 0.27, h), road);
    final road2 = Paint()
      ..color = Colors.white
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(0, h * 0.76), Offset(w, h * 0.67), road2);

    // 5. 地理围栏虚线圆
    for (final g in geoCircles) {
      final c = Offset(w * g.x, h * g.y);
      final r = math.min(w, h) * g.radius;
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..color = g.color.withOpacity(0.1)
          ..style = PaintingStyle.fill,
      );
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..color = g.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..strokeJoin = StrokeJoin.round,
      );
      // 虚线效果：用 pathEffect 需要引入 dart:ui，这里用短弧拼接近似
      _drawDashedCircle(canvas, c, r, g.color);
    }

    // 6. 路线（蓝色虚线）
    if (pins.length >= 2) {
      final route = Paint()
        ..color = AppColors.primary
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      final path = Path()
        ..moveTo(w * pins[0].x, h * pins[0].y);
      for (var i = 1; i < pins.length; i++) {
        path.lineTo(w * pins[i].x, h * pins[i].y);
      }
      canvas.drawPath(path, route);
    }

    // 7. 我的定位点
    if (showUserLocation) {
      final c = Offset(w * 0.2, h * 0.76);
      canvas.drawCircle(c, 7, Paint()..color = AppColors.primary);
      canvas.drawCircle(c, 2.6, Paint()..color = Colors.white);
    }

    // 8. 编号 pin
    for (final pin in pins) {
      _drawNumberPin(canvas, Offset(w * pin.x, h * pin.y), pin.number, pin.color);
    }

    // 9. 红色目的地 pin
    if (destination != null) {
      _drawDestinationPin(
          canvas, Offset(w * destination!.x, h * destination!.y), destination!.number);
    }
  }

  void _drawDashedCircle(Canvas canvas, Offset c, double r, Color color) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    const dash = 6.0;
    const gap = 5.0;
    final circumference = 2 * math.pi * r;
    final step = dash + gap;
    var drawn = 0.0;
    var angle = 0.0;
    while (drawn < circumference) {
      final sweep = math.min(dash / r, (circumference - drawn) / r);
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r),
        angle,
        sweep,
        false,
        paint,
      );
      angle += (dash + gap) / r;
      drawn += step;
    }
  }

  void _drawNumberPin(Canvas canvas, Offset c, int number, Color color) {
    // 白底彩色描边圆 + 编号
    canvas.drawCircle(c, 12, Paint()..color = Colors.white);
    canvas.drawCircle(
      c,
      12,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    final tp = TextPainter(
      text: TextSpan(
        text: '$number',
        style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w700, color: color),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(c.dx - tp.width / 2, c.dy - tp.height / 2));
  }

  void _drawDestinationPin(Canvas canvas, Offset c, int number) {
    canvas.drawCircle(c, 12, Paint()..color = AppColors.red);
    final tp = TextPainter(
      text: TextSpan(
        text: '$number',
        style: const TextStyle(
            fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(c.dx - tp.width / 2, c.dy - tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _SketchMapPainter old) => true;
}

/// 迷你路线图（S3）：竖向串联景点/餐饮/住宿节点 + 图例
class MiniRouteMap extends StatelessWidget {
  final double width;
  final double height;

  const MiniRouteMap({super.key, this.width = 326, this.height = 96});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: width,
        height: height,
        child: CustomPaint(painter: _MiniRouteMapPainter()),
      ),
    );
  }
}

class _MiniRouteMapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, w, h), const Radius.circular(10)),
      Paint()..color = const Color(0xFFF4F7FE),
    );

    // 串联路线
    final nodes = <Offset>[
      Offset(w * 0.12, h * 0.5),
      Offset(w * 0.35, h * 0.28),
      Offset(w * 0.58, h * 0.68),
      Offset(w * 0.82, h * 0.38),
    ];
    final path = Path()..moveTo(nodes.first.dx, nodes.first.dy);
    for (var i = 1; i < nodes.length; i++) {
      path.lineTo(nodes[i].dx, nodes[i].dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = AppColors.primary
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // 节点：景点(蓝)/餐饮(橙)/住宿(紫)
    final colors = [
      AppColors.primary,
      AppColors.amber,
      AppColors.purple,
      AppColors.primary,
    ];
    for (var i = 0; i < nodes.length; i++) {
      canvas.drawCircle(nodes[i], 6, Paint()..color = colors[i]);
      canvas.drawCircle(nodes[i], 2.4, Paint()..color = Colors.white);
    }

    // 图例
    _legend(canvas, Offset(w * 0.06, h - 14), AppColors.primary, '景点');
    _legend(canvas, Offset(w * 0.24, h - 14), AppColors.amber, '餐饮');
    _legend(canvas, Offset(w * 0.42, h - 14), AppColors.purple, '住宿');
  }

  void _legend(Canvas canvas, Offset pos, Color color, String text) {
    canvas.drawCircle(Offset(pos.dx + 4, pos.dy + 4), 4, Paint()..color = color);
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(fontSize: 10, color: AppColors.secondary),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(pos.dx + 11, pos.dy));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
