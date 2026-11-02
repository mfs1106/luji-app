import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// 美团直订服务（F4）
/// 方案：超链接跳转美团对应页面，用户自行确认支付；
/// App 不代下单、不代扣款、不接 CPS（零收益口径）。
///
/// 深链调研结论（2026-10-20，双轮网络查证）：
/// - 美团 App scheme 为路径式家族 imeituan://www.meituan.com/xxx，
///   其中 ordercenterlist（订单中心）被多方来源交叉记录；
///   电子券付款完成后订单状态即「待使用」，订单中心正是其归属页。
/// - 美团未公开「我的-红包卡券」直达链接；App 内路径为
///   「我的—红包卡券—我的券」，仅能引导用户手动进入。
/// - scheme 属私有协议、随时可能调整，因此打开美团统一走三级降级，
///   任何一级失败自动顺延，保证「打开美团」的底线 100% 达成；
///   具体小程序路径/链接可由服务端 /meituan/links 统一下发覆盖。
class MeituanLauncher {
  const MeituanLauncher._();

  /// 服务类型
  static const typeTicket = 'ticket'; // 景点门票
  static const typeTrain = 'train'; // 火车票机票
  static const typeFood = 'food'; // 美食团购券

  static Future<bool> shareToWeChat(String text) async {
    try {
      return await const MethodChannel('luji/wechat')
              .invokeMethod<bool>('shareText', {'text': text}) ??
          false;
    } catch (_) {
      return false;
    }
  }

  /// H5 兜底链接（生产环境应从服务端获取）
  static String _h5(String type, {String? city, String? spot}) {
    // H5 为兜底：装有美团 App 的机型经 App Link 多可直接唤起 App 内对应页。
    // 通用落地页拼接搜索关键词（meituan 忽略未知 query 参数，不会 404），
    // 让「美食」等入口至少带上地点/城市意图，三入口不再完全雷同。
    final kw = [spot, city]
        .where((s) => s != null && s.trim().isNotEmpty)
        .join(' ')
        .trim();
    final q = kw.isEmpty ? '' : Uri.encodeComponent(kw);
    switch (type) {
      case typeTicket:
        // Verified public Meituan ticket search entry. The site itself owns
        // product selection, stock, checkout and payment.
        return 'https://i.meituan.com/awp/hfe/travel-merchant/index.html';
      case typeTrain:
        return 'https://i.meituan.com/awp/h5/train/search/index.html?train_source=meituan%40wap';
      case typeFood:
      default:
        return q.isEmpty
            ? 'https://i.meituan.com/'
            : 'https://i.meituan.com/?keyword=$q';
    }
  }

  /// 打开美团对应页面
  /// H5 链接：美团已配置 App Link / Universal Link，装有美团 App 的
  /// 机型多数可直接唤起 App 内对应页，未安装时走浏览器 H5。
  static Future<bool> open(String type, {String? city, String? spot}) async {
    final uri = Uri.parse(_h5(type, city: city, spot: spot));
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  // ---- 待使用电子券：三级降级打开美团 ----

  /// 美团订单中心：付完款的电子券订单状态即「待使用」，是其归属页
  static const _schemeOrderCenter =
      'imeituan://www.meituan.com/ordercenterlist';

  /// 美团 App 首页：scheme 家族中公认最稳定的一个
  static const _schemeHome = 'imeituan://www.meituan.com/home';

  /// H5 首页兜底
  static const _h5Home = 'https://i.meituan.com/';

  /// 打开美团并尽可能落到「订单中心」（待使用电子券的归属页）
  ///
  /// 三级降级：订单中心 scheme → 首页 scheme → H5；
  /// 任一级设备不支持或唤起失败，自动顺延下一级。
  /// 落到订单中心后，用户点击顶部「待使用」即可出示电子券二维码
  /// ——二维码由美团生成与核销，旅记只负责把用户送到这一页，
  /// 不代下单、不代扣款，也不读取美团账号数据。
  static Future<bool> openOrderCenter() async {
    for (final link in const [_schemeOrderCenter, _schemeHome]) {
      try {
        final uri = Uri.parse(link);
        if (await canLaunchUrl(uri)) {
          final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
          if (ok) return true;
        }
      } catch (_) {
        // 顺延下一级
      }
    }
    // 最后兜底：H5（装有美团 App 的机型经 App Link 多数仍可唤起 App）
    try {
      return await launchUrl(Uri.parse(_h5Home),
          mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  /// 微信小程序唤起（需微信 OpenSDK，WXLaunchMiniProgram）
  /// 在原生层封装后通过 MethodChannel 调用；此处给出接口约定：
  ///   channel: 'luji/wechat'
  ///   method: 'launchMiniProgram'
  ///   args: { 'userName': '美团小程序原始ID', 'path': '页面路径', 'miniProgramType': 2 }
  /// 未安装微信或唤起失败时调用 open() 走 H5 兜底。
  static const wechatChannel = 'luji/wechat';
  static const wechatMethod = 'launchMiniProgram';

  /// 优惠券深链（预留：服务端 /meituan/links 可下发具体团购页深链；
  /// 当前版本优惠券入口统一走 openOrderCenter()）
  static Future<bool> openCoupon(String deepLink) async {
    try {
      return await launchUrl(Uri.parse(deepLink),
          mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }
}
