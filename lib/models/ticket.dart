/// 电子票夹票据
class Ticket {
  final int? id;
  final int tripId;
  final String type; // ticket 景点门票 / flight 机票 / train 火车票 / hotel 酒店
  final String name;
  final DateTime useTime; // 使用时间
  final String? code; // 票号/券码
  final String qrContent; // 二维码内容（本地生成）
  final String source; // ocr 截图识别 / manual 手动录入 / import 订单导入
  final String status; // pending 待使用 / used 已使用 / refunded 已退
  final String? deepLink; // 原始订单深链（点击跳转第三方）

  const Ticket({
    this.id,
    required this.tripId,
    required this.type,
    required this.name,
    required this.useTime,
    this.code,
    required this.qrContent,
    this.source = 'manual',
    this.status = 'pending',
    this.deepLink,
  });

  String get typeLabel {
    switch (type) {
      case 'ticket':
        return '景点门票';
      case 'flight':
        return '机票';
      case 'train':
        return '火车票';
      case 'hotel':
        return '酒店';
      default:
        return type;
    }
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'trip_id': tripId,
        'type': type,
        'name': name,
        'use_time': useTime.toIso8601String(),
        'code': code,
        'qr_content': qrContent,
        'source': source,
        'status': status,
        'deep_link': deepLink,
      };

  static Ticket fromMap(Map<String, Object?> m) => Ticket(
        id: m['id'] as int?,
        tripId: m['trip_id'] as int,
        type: m['type'] as String,
        name: m['name'] as String,
        useTime: DateTime.parse(m['use_time'] as String),
        code: m['code'] as String?,
        qrContent: m['qr_content'] as String? ?? '',
        source: m['source'] as String? ?? 'manual',
        status: m['status'] as String? ?? 'pending',
        deepLink: m['deep_link'] as String?,
      );
}
