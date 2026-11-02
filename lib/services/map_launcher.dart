import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// 第三方地图唤起服务（F1 智能地图）
/// 方案：URL Scheme 超链接唤起；未安装则引导前往应用商店。
/// 坐标统一使用 GCJ-02（火星坐标）。
///
/// 起点策略：fromLat/fromLon 不传时省略起点参数，
/// 由地图 App 使用设备实时定位作为「我的位置」——
/// 旅记只负责预填终点（目的地名称 + 经纬度），
/// 打车/选路/开始导航等操作全部在第三方地图 App 内由用户完成。
class MapLauncher {
  const MapLauncher._();

  static const _appName = '旅记';

  /// 高德路线规划：amapuri://route/plan/?...
  /// t: 0 驾车 / 1 公交 / 2 步行 / 3 骑行
  static Uri amapRoute({
    double? fromLat,
    double? fromLon,
    String? fromName,
    required double toLat,
    required double toLon,
    required String toName,
    int mode = 0,
  }) {
    final from = (fromLat != null && fromLon != null)
        ? '&slat=$fromLat&slon=$fromLon&sname=${Uri.encodeComponent(fromName ?? '我的位置')}'
        : '';
    return Uri.parse(
      'amapuri://route/plan/?sourceApplication=$_appName'
      '$from'
      '&dlat=$toLat&dlon=$toLon&dname=${Uri.encodeComponent(toName)}'
      '&dev=0&t=$mode',
    );
  }

  /// 高德网页版兜底（H5 导航）
  static Uri amapWeb({
    double? fromLat,
    double? fromLon,
    required double toLat,
    required double toLon,
    required String toName,
    int mode = 0,
  }) {
    final modeStr = ['car', 'bus', 'walk', 'ride'][mode];
    final from = (fromLat != null && fromLon != null)
        ? 'from=$fromLon,$fromLat,${Uri.encodeComponent('我的位置')}&'
        : '';
    return Uri.parse(
      'https://uri.amap.com/navigation?${from}to=$toLon,$toLat,'
      '${Uri.encodeComponent(toName)}&mode=$modeStr&policy=1&src=$_appName',
    );
  }

  /// 百度地图路线规划：baidumap://map/direction?...
  static Uri baiduRoute({
    double? fromLat,
    double? fromLon,
    required double toLat,
    required double toLon,
    int mode = 0,
  }) {
    final modeStr = ['driving', 'transit', 'walking', 'riding'][mode];
    final origin =
        (fromLat != null && fromLon != null) ? 'origin=$fromLat,$fromLon&' : '';
    return Uri.parse(
      'baidumap://map/direction?${origin}destination=$toLat,$toLon'
      '&coord_type=gcj02&mode=$modeStr&src=$_appName',
    );
  }

  /// 通用唤起：已安装直接打开，未安装回调引导
  static Future<bool> launchOrGuide(
    BuildContext context,
    Uri uri, {
    required String appName,
    required String storeUrl,
  }) async {
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (ok) return true;
    } catch (_) {
      // 部分机型对未注册 scheme 会抛异常，统一走引导
    }
    if (context.mounted) _showDownloadGuide(context, appName, storeUrl);
    return false;
  }

  /// 未安装引导浮层
  static void _showDownloadGuide(
      BuildContext context, String appName, String storeUrl) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('尚未安装$appName'),
        content: Text('安装$appName后即可一键导航，是否现在前往下载？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消', style: TextStyle(color: Color(0xFF6B7280))),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              launchUrl(Uri.parse(storeUrl),
                  mode: LaunchMode.externalApplication);
            },
            child: const Text('去下载',
                style: TextStyle(
                    color: Color(0xFF2F6BED), fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  /// 各应用商店地址
  static const amapStore = 'https://uri.amap.com/mobile';
  static const baiduStore =
      'https://map.baidu.com/mobile/webapp/index/index/foo=main';
}
