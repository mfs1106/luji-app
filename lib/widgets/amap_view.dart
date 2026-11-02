import 'package:amap_flutter_base_plus/amap_flutter_base_plus.dart';
import 'package:amap_flutter_map_plus_x/amap_flutter_map.dart';
import 'package:flutter/material.dart';

import '../config/amap_config.dart';
import '../services/privacy_consent_service.dart';
import '../theme/app_theme.dart';
import 'route_map.dart';

/// 地图演示点位（真实经纬度）
/// 同时驱动两种渲染：高德真地图的 Marker 与手绘降级图的编号 pin
class AmapSpot {
  const AmapSpot(this.name, this.lat, this.lon, {this.isDestination = false});

  final String name;
  final double lat;
  final double lon;
  final bool isDestination;
}

/// S2 智能地图卡的地图区域——三态渲染：
/// ① 未配置高德 Key       → 手绘示意地图 + 「配置 Key 后显示实时地图」提示
/// ② 已配 Key 未同意隐私   → 手绘示意地图 + 首次进入弹隐私政策（同意后才初始化 SDK）
/// ③ 已配 Key 且已同意     → 高德实时地图（路况 / 定位蓝点 / 景点 Marker / 摘要浮层 / 审图号）
///
/// Key 申请后填入 lib/config/amap_config.dart 即可，无需改动本文件。
class AmapRouteMap extends StatefulWidget {
  const AmapRouteMap({
    super.key,
    this.height = 220,
    this.myLat,
    this.myLon,
    this.showMyLocation = false,
    required this.spots,
    required this.summaryText,
    this.onMapTap,
    this.onPoiTap,
  });

  final double height;
  final double? myLat;
  final double? myLon;
  final bool showMyLocation;
  final List<AmapSpot> spots;
  final String summaryText;
  final void Function(double lat, double lon)? onMapTap;
  final void Function(AMapPoi poi)? onPoiTap;

  @override
  State<AmapRouteMap> createState() => _AmapRouteMapState();
}

class _AmapRouteMapState extends State<AmapRouteMap> {
  bool _agreed = false;
  String? _approvalNo; // 高德审图号（合规要求：地图界面需标注）

  @override
  void initState() {
    super.initState();
    if (AmapConfig.hasKey) _loadConsent();
  }

  Future<void> _loadConsent() async {
    final agreed = await PrivacyConsentService.isAmapAgreed();
    if (!mounted) return;
    setState(() => _agreed = agreed);
    if (!agreed) {
      // 首帧后弹隐私政策（合规：先告知并取得同意，再初始化地图 SDK）
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showPrivacyDialog();
      });
    }
  }

  Future<void> _showPrivacyDialog() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const _PrivacyDialog(),
    );
    if (result == true) {
      await PrivacyConsentService.agreeAmap();
      if (!mounted) return;
      setState(() => _agreed = true);
    }
  }

  void _onMapCreated(AMapController controller) {
    controller.getMapContentApprovalNumber().then((no) {
      if (mounted && no != null && no.isNotEmpty) {
        setState(() => _approvalNo = no);
      }
    });
  }

  // ---------- 手绘降级 + 提示 ----------
  Widget _sketchWithHint({required String hint, VoidCallback? onHintTap}) {
    final spots = widget.spots;
    AmapSpot? dest;
    for (final s in spots) {
      if (s.isDestination) dest = s;
    }
    // 由真实经纬度归一化出手绘相对坐标（含 6% 边距防贴边）
    double minLat = dest?.lat ?? 0, maxLat = dest?.lat ?? 0;
    double minLon = dest?.lon ?? 0, maxLon = dest?.lon ?? 0;
    for (final s in spots) {
      if (s.lat < minLat) minLat = s.lat;
      if (s.lat > maxLat) maxLat = s.lat;
      if (s.lon < minLon) minLon = s.lon;
      if (s.lon > maxLon) maxLon = s.lon;
    }

    double frac(double v, double min, double max) {
      if (max - min < 1e-9) return 0.5;
      return ((v - min) / (max - min)).clamp(0.06, 0.94);
    }

    final pins = <MapPin>[];
    var i = 0;
    for (final s in spots) {
      if (s.isDestination) continue;
      pins.add(MapPin(
          frac(s.lon, minLon, maxLon), 1 - frac(s.lat, minLat, maxLat), ++i));
    }
    MapPin? destPin;
    if (dest != null) {
      destPin = MapPin(frac(dest.lon, minLon, maxLon),
          1 - frac(dest.lat, minLat, maxLat), 3);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SketchMap(
          width: double.infinity,
          height: widget.height,
          pins: pins,
          destination: destPin,
          geoCircles: destPin == null
              ? const []
              : [GeoCircle(destPin.x, destPin.y, 0.18)],
          overlayText: widget.summaryText,
        ),
        _hintBar(hint, onTap: onHintTap),
      ],
    );
  }

  Widget _hintBar(String text, {VoidCallback? onTap}) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F7FE),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.map_outlined, size: 16, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    fontSize: 11, color: AppColors.secondary, height: 1.4)),
          ),
          if (onTap != null)
            GestureDetector(
              onTap: onTap,
              child: const Text('查看',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary)),
            ),
        ],
      ),
    );
  }

  // ---------- 高德实时地图 ----------
  Widget _amapView() {
    final markers = <Marker>{};
    for (final s in widget.spots) {
      markers.add(Marker(
        position: LatLng(s.lat, s.lon),
        icon: s.isDestination
            ? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed)
            : BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        infoWindow: InfoWindow(
            title: s.name, snippet: s.isDestination ? '目的地' : '行程地点'),
      ));
    }
    final lines = widget.spots.length < 2
        ? <Polyline>{}
        : <Polyline>{
            Polyline(
              points: [for (final s in widget.spots) LatLng(s.lat, s.lon)],
              width: 5,
              color: AppColors.primary,
            )
          };

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        height: widget.height,
        width: double.infinity,
        child: Stack(
          children: [
            // 平台视图需显式撑满 Stack（松散约束下不会自动展开）
            Positioned.fill(
              child: AMapWidget(
                key: ValueKey(
                    '${widget.myLat}:${widget.myLon}:${widget.spots.length}'),
                apiKey: AmapConfig.apiKey,
                // 高德 SDK 合规：已在隐私政策中告知并取得用户同意后才置 true
                privacyStatement: const AMapPrivacyStatement(
                    hasContains: true, hasShow: true, hasAgree: true),
                // The map must be usable before the user grants GPS permission.
                // This is only the browse viewport, never a claimed position.
                initialCameraPosition: CameraPosition(
                    target: LatLng(
                        widget.myLat ??
                            (widget.spots.isEmpty
                                ? 35.0
                                : widget.spots.first.lat),
                        widget.myLon ??
                            (widget.spots.isEmpty
                                ? 105.0
                                : widget.spots.first.lon)),
                    zoom:
                        widget.myLat == null && widget.spots.isEmpty ? 4 : 12),
                trafficEnabled: true, // 实时路况
                myLocationStyleOptions: MyLocationStyleOptions(
                  widget.showMyLocation &&
                      widget.myLat != null &&
                      widget.myLon != null,
                  circleFillColor: AppColors.primary.withOpacity(0.10),
                  circleStrokeColor: AppColors.primary,
                  circleStrokeWidth: 1,
                ),
                markers: markers,
                polylines: lines,
                onMapCreated: _onMapCreated,
                onTap: (point) =>
                    widget.onMapTap?.call(point.latitude, point.longitude),
                touchPoiEnabled: true,
                onPoiTouched: widget.onPoiTap,
              ),
            ),
            // 实时路况角标
            const Positioned(right: 12, top: 12, child: _TrafficBadge()),
            // 摘要浮层（与设计稿一致）
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
                    Text(widget.summaryText,
                        style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppColors.text)),
                  ],
                ),
              ),
            ),
            // 审图号（高德合规要求：地图界面需标注）
            if (_approvalNo != null)
              Positioned(
                right: 8,
                bottom: 4,
                child: Text(_approvalNo!,
                    style:
                        const TextStyle(fontSize: 8, color: AppColors.faint)),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!AmapConfig.hasKey) {
      return _sketchWithHint(
          hint: '配置高德 Key 后（lib/config/amap_config.dart），这里将显示实时地图与实时路况');
    }
    if (!_agreed) {
      return _sketchWithHint(
        hint: '同意隐私政策后，即可启用高德实时地图',
        onHintTap: _showPrivacyDialog,
      );
    }
    return _amapView();
  }
}

/// 实时路况角标
class _TrafficBadge extends StatelessWidget {
  const _TrafficBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.94),
        borderRadius: BorderRadius.circular(11),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.traffic_outlined, size: 12, color: AppColors.green),
          SizedBox(width: 4),
          Text('实时路况',
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text)),
        ],
      ),
    );
  }
}

/// 高德地图隐私政策对话框（首次进入地图页且已配置 Key 时弹出）
class _PrivacyDialog extends StatelessWidget {
  const _PrivacyDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('隐私政策与地图服务',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text('旅记是一款本地优先的旅行规划工具，你的行程、账目、笔记数据仅保存在本机，不会上传服务器。',
                  style: TextStyle(fontSize: 13, height: 1.6)),
              SizedBox(height: 10),
              Text('为提供「智能地图」功能，App 需接入高德地图 SDK（由高德开放平台提供）：',
                  style: TextStyle(fontSize: 13, height: 1.6)),
              SizedBox(height: 6),
              Text('1. 使用目的：在地图页展示实时地图、路况与你的当前位置；',
                  style: TextStyle(fontSize: 12, height: 1.6)),
              Text('2. 信息范围：仅使用设备定位信息用于地图展示，不采集、不上传你的行程与账目数据；',
                  style: TextStyle(fontSize: 12, height: 1.6)),
              Text(
                  '3. 第三方政策：高德地图 SDK 将按其隐私政策处理相关数据（lbs.amap.com/pages/privacy）。',
                  style: TextStyle(fontSize: 12, height: 1.6)),
              SizedBox(height: 10),
              Text('你也可以选择不同意，App 将改用内置手绘示意地图，其余功能不受任何影响。',
                  style: TextStyle(
                      fontSize: 12, height: 1.6, color: AppColors.secondary)),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child:
              const Text('暂不同意', style: TextStyle(color: AppColors.secondary)),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('同意并启用',
              style: TextStyle(
                  color: AppColors.primary, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}
