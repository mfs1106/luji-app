/// 账目：一笔花费（手动记录 / 账单导入 / 预订预估）
class Expense {
  final int? id;
  final int tripId;
  final String city; // 归属城市
  final String category; // ticket 门票 / food 餐饮 / hotel 住宿 / transport 交通
  final double amount; // 金额（元）
  final bool isEstimated; // true=预订预估，false=实付
  final String
      source; // booking 预订自动带出 / meituan 美团团购券 / manual 手动记录 / wechat 微信 / alipay 支付宝 / 12306
  final String? tradeNo; // 交易单号（导入去重）
  final DateTime spentAt;
  final String? note;
  final String placeName;
  final String itemName;
  final String paymentMethod;

  const Expense({
    this.id,
    required this.tripId,
    required this.city,
    required this.category,
    required this.amount,
    this.isEstimated = false,
    required this.source,
    this.tradeNo,
    required this.spentAt,
    this.note,
    this.placeName = '',
    this.itemName = '',
    this.paymentMethod = '',
  });

  String get categoryLabel {
    switch (category) {
      case 'ticket':
        return '门票';
      case 'food':
        return '餐饮';
      case 'hotel':
        return '住宿';
      case 'transport':
        return '交通';
      default:
        return '其他';
    }
  }

  String get sourceLabel {
    switch (source) {
      case 'booking':
        return '预订自动带出';
      case 'meituan':
        return '美团团购券';
      case 'manual':
        return '手动记录';
      case 'wechat':
        return '微信账单导入';
      case 'alipay':
        return '支付宝账单导入';
      case '12306':
        return '12306';
      default:
        return source;
    }
  }

  Expense copyWith({
    int? id,
    int? tripId,
    String? city,
    String? category,
    double? amount,
    bool? isEstimated,
    String? source,
    String? tradeNo,
    DateTime? spentAt,
    String? note,
    String? placeName,
    String? itemName,
    String? paymentMethod,
  }) {
    return Expense(
      id: id ?? this.id,
      tripId: tripId ?? this.tripId,
      city: city ?? this.city,
      category: category ?? this.category,
      amount: amount ?? this.amount,
      isEstimated: isEstimated ?? this.isEstimated,
      source: source ?? this.source,
      tradeNo: tradeNo ?? this.tradeNo,
      spentAt: spentAt ?? this.spentAt,
      note: note ?? this.note,
      placeName: placeName ?? this.placeName,
      itemName: itemName ?? this.itemName,
      paymentMethod: paymentMethod ?? this.paymentMethod,
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'trip_id': tripId,
        'city': city,
        'category': category,
        'amount': amount,
        'is_estimated': isEstimated ? 1 : 0,
        'source': source,
        'trade_no': tradeNo,
        'spent_at': spentAt.toIso8601String(),
        'note': note,
        'place_name': placeName,
        'item_name': itemName,
        'payment_method': paymentMethod,
      };

  static Expense fromMap(Map<String, Object?> m) => Expense(
        id: m['id'] as int?,
        tripId: m['trip_id'] as int,
        city: m['city'] as String,
        category: m['category'] as String,
        amount: (m['amount'] as num).toDouble(),
        isEstimated: (m['is_estimated'] as int? ?? 0) == 1,
        source: m['source'] as String,
        tradeNo: m['trade_no'] as String?,
        spentAt: DateTime.parse(m['spent_at'] as String),
        note: m['note'] as String?,
        placeName: m['place_name'] as String? ?? '',
        itemName: m['item_name'] as String? ?? '',
        paymentMethod: m['payment_method'] as String? ?? '',
      );
}
