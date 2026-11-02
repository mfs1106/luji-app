import 'package:shared_preferences/shared_preferences.dart';

/// 隐私同意状态服务
///
/// 高德地图 SDK 合规要求：App 首次启动需向用户展示隐私政策并取得同意后，
/// 才能初始化地图 SDK（AMapWidget 的 privacyStatement 三个标志位均为 true，
/// 任一为 false 都会导致地图白屏）。
/// 同意状态持久化在本机（shared_preferences），不会重复弹窗。
class PrivacyConsentService {
  const PrivacyConsentService._();

  static const _kAmapPrivacyAgreed = 'amap_privacy_agreed_v1';

  /// 高德地图隐私政策是否已取得用户同意
  static Future<bool> isAmapAgreed() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kAmapPrivacyAgreed) ?? false;
  }

  /// 记录用户已同意高德地图隐私政策
  static Future<void> agreeAmap() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kAmapPrivacyAgreed, true);
  }

  /// 重置同意状态（调试 / 用户撤回同意时调用）
  static Future<void> resetAmap() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kAmapPrivacyAgreed);
  }
}
