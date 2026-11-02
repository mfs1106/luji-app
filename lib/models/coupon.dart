/// 优惠券（本地记录；美团待使用券统一跳订单中心，见 MeituanLauncher.openOrderCenter）
class Coupon {
  final int? id;
  final int tripId;
  final String name;
  final String value; // 面额/折扣，如「减 ¥15」
  final String scope; // 适用范围
  final DateTime validFrom;
  final DateTime validTo;
  final String? code;
  final String? deepLink; // 跳转美团使用

  const Coupon({
    this.id,
    required this.tripId,
    required this.name,
    required this.value,
    required this.scope,
    required this.validFrom,
    required this.validTo,
    this.code,
    this.deepLink,
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'trip_id': tripId,
        'name': name,
        'value': value,
        'scope': scope,
        'valid_from': validFrom.toIso8601String(),
        'valid_to': validTo.toIso8601String(),
        'code': code,
        'deep_link': deepLink,
      };

  static Coupon fromMap(Map<String, Object?> m) => Coupon(
        id: m['id'] as int?,
        tripId: m['trip_id'] as int,
        name: m['name'] as String,
        value: m['value'] as String? ?? '',
        scope: m['scope'] as String? ?? '',
        validFrom: DateTime.parse(m['valid_from'] as String),
        validTo: DateTime.parse(m['valid_to'] as String),
        code: m['code'] as String?,
        deepLink: m['deep_link'] as String?,
      );
}
