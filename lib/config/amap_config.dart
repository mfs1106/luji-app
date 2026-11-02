import 'package:amap_flutter_base_plus/amap_flutter_base_plus.dart';
import 'package:flutter/foundation.dart';

/// 高德地图 SDK 配置（F1 智能地图 · App 内实时地图与路况）
///
/// Key 申请方式见 `docs/打包指南.md`「高德实时地图接入」一节：
///   - Android Key：lbs.amap.com → 创建应用 → Android 平台 → 包名 + SHA1
///   - iOS Key：lbs.amap.com → 创建应用 → iOS 平台 → Bundle ID
///
/// 两端 Key 均留空时，地图页自动降级为内置手绘示意地图（SketchMap），
/// 唤起导航、记账、提醒等其余功能完全不受影响；
/// 构建时通过 --dart-define 提供 Key；不要把 Key 写进公开仓库。
class AmapConfig {
  const AmapConfig._();

  /// 高德 Android Key（构建参数 AMAP_ANDROID_KEY）
  static const String androidKey =
      String.fromEnvironment('AMAP_ANDROID_KEY');

  /// 高德 iOS Key（构建参数 AMAP_IOS_KEY）
  static const String iosKey = String.fromEnvironment('AMAP_IOS_KEY');

  /// 当前平台的 Key 是否已配置。
  static bool get hasKey {
    if (kIsWeb) return false;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return androidKey.trim().isNotEmpty;
      case TargetPlatform.iOS:
        return iosKey.trim().isNotEmpty;
      default:
        return false;
    }
  }

  /// 传给 AMapWidget 的 Key（仅 hasKey == true 时使用）
  static AMapApiKey get apiKey => AMapApiKey(
        androidKey: androidKey.trim(),
        iosKey: iosKey.trim(),
      );
}
