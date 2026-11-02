/// 日程项：某一天中的一个安排（对应 S3 时间轴 / S6 可拖拽日程）
class ItineraryItem {
  final int? id;
  final int tripId;
  final int dayIndex; // 第几天（1 起）
  final int? spotId; // 关联景点
  final String name; // 未关联景点时直接填名称
  final String startTime; // "08:30"
  final String endTime; // "10:00"
  final String transport; // start 起点 / walk 步行 / bus 公交 / car 驾车 / train 火车
  final int transportMinutes; // 交通耗时（分钟）
  final int sortOrder; // 排序
  final String? note; // 备注，如「待购票」「美团可领券」

  const ItineraryItem({
    this.id,
    required this.tripId,
    required this.dayIndex,
    this.spotId,
    required this.name,
    required this.startTime,
    required this.endTime,
    this.transport = 'walk',
    this.transportMinutes = 0,
    this.sortOrder = 0,
    this.note,
  });

  /// 交通徽章文案，如「步行 8 分钟」
  String get transportLabel {
    switch (transport) {
      case 'start':
        return '起点';
      case 'walk':
        return '步行 $transportMinutes 分钟';
      case 'bus':
        return '公交 $transportMinutes 分钟';
      case 'car':
        return '驾车 $transportMinutes 分钟';
      case 'train':
        return '火车 $transportMinutes 分钟';
      default:
        return '步行 $transportMinutes 分钟';
    }
  }

  ItineraryItem copyWith({
    int? id,
    int? tripId,
    int? dayIndex,
    int? spotId,
    String? name,
    String? startTime,
    String? endTime,
    String? transport,
    int? transportMinutes,
    int? sortOrder,
    String? note,
  }) {
    return ItineraryItem(
      id: id ?? this.id,
      tripId: tripId ?? this.tripId,
      dayIndex: dayIndex ?? this.dayIndex,
      spotId: spotId ?? this.spotId,
      name: name ?? this.name,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      transport: transport ?? this.transport,
      transportMinutes: transportMinutes ?? this.transportMinutes,
      sortOrder: sortOrder ?? this.sortOrder,
      note: note ?? this.note,
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'trip_id': tripId,
        'day_index': dayIndex,
        'spot_id': spotId,
        'name': name,
        'start_time': startTime,
        'end_time': endTime,
        'transport': transport,
        'transport_minutes': transportMinutes,
        'sort_order': sortOrder,
        'note': note,
      };

  static ItineraryItem fromMap(Map<String, Object?> m) => ItineraryItem(
        id: m['id'] as int?,
        tripId: m['trip_id'] as int,
        dayIndex: m['day_index'] as int,
        spotId: m['spot_id'] as int?,
        name: m['name'] as String,
        startTime: m['start_time'] as String,
        endTime: m['end_time'] as String,
        transport: m['transport'] as String? ?? 'walk',
        transportMinutes: m['transport_minutes'] as int? ?? 0,
        sortOrder: m['sort_order'] as int? ?? 0,
        note: m['note'] as String?,
      );
}
