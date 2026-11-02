/// 景点/餐饮/住宿点
class Spot {
  final int? id;
  final int tripId;
  final String name;
  final String? poiId; // 高德 POI ID（缓存）
  final double lat;
  final double lon;
  final String city;
  final String category; // spot 景点 / food 餐饮 / hotel 住宿
  final String openTime; // 开放时间说明
  final int stayMinutes; // 建议游玩时长（分钟）
  final double? ticketPrice; // 门票参考价
  final String ticketStatus; // none 无需购票 / pending 待购 / paid 已购
  final int dayIndex; // 归属第几天（1 起）
  final String? desc; // 等级等描述，如「5A 景区」
  final String? bookingUrl; // 可选的景点官方/美团具体商品链接

  const Spot({
    this.id,
    required this.tripId,
    required this.name,
    this.poiId,
    required this.lat,
    required this.lon,
    required this.city,
    required this.category,
    required this.openTime,
    required this.stayMinutes,
    this.ticketPrice,
    this.ticketStatus = 'none',
    this.dayIndex = 1,
    this.desc,
    this.bookingUrl,
  });

  Spot copyWith({
    int? id,
    int? tripId,
    String? name,
    String? poiId,
    double? lat,
    double? lon,
    String? city,
    String? category,
    String? openTime,
    int? stayMinutes,
    double? ticketPrice,
    String? ticketStatus,
    int? dayIndex,
    String? desc,
    String? bookingUrl,
  }) {
    return Spot(
      id: id ?? this.id,
      tripId: tripId ?? this.tripId,
      name: name ?? this.name,
      poiId: poiId ?? this.poiId,
      lat: lat ?? this.lat,
      lon: lon ?? this.lon,
      city: city ?? this.city,
      category: category ?? this.category,
      openTime: openTime ?? this.openTime,
      stayMinutes: stayMinutes ?? this.stayMinutes,
      ticketPrice: ticketPrice ?? this.ticketPrice,
      ticketStatus: ticketStatus ?? this.ticketStatus,
      dayIndex: dayIndex ?? this.dayIndex,
      desc: desc ?? this.desc,
      bookingUrl: bookingUrl ?? this.bookingUrl,
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'trip_id': tripId,
        'name': name,
        'poi_id': poiId,
        'lat': lat,
        'lon': lon,
        'city': city,
        'category': category,
        'open_time': openTime,
        'stay_minutes': stayMinutes,
        'ticket_price': ticketPrice,
        'ticket_status': ticketStatus,
        'day_index': dayIndex,
        'desc': desc,
        'booking_url': bookingUrl,
      };

  static Spot fromMap(Map<String, Object?> m) => Spot(
        id: m['id'] as int?,
        tripId: m['trip_id'] as int,
        name: m['name'] as String,
        poiId: m['poi_id'] as String?,
        lat: (m['lat'] as num).toDouble(),
        lon: (m['lon'] as num).toDouble(),
        city: m['city'] as String,
        category: m['category'] as String,
        openTime: m['open_time'] as String? ?? '',
        stayMinutes: m['stay_minutes'] as int? ?? 60,
        ticketPrice: (m['ticket_price'] as num?)?.toDouble(),
        ticketStatus: m['ticket_status'] as String? ?? 'none',
        dayIndex: m['day_index'] as int? ?? 1,
        desc: m['desc'] as String?,
        bookingUrl: m['booking_url'] as String?,
      );
}
