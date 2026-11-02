/// 定点提醒：定时闹钟 / 地理围栏 / 事件开售 / 行程出发
class Reminder {
  final int? id;
  final int tripId;
  final String type; // alarm 闹钟 / geofence 围栏 / onsale 开售 / depart 出发
  final String title;
  final String subtitle;
  final DateTime? triggerTime; // 定时类触发时间
  final String? repeatRule; // daily 等
  final double? geoLat; // 围栏中心
  final double? geoLon;
  final double? geoRadius; // 围栏半径（米）
  final int advanceMinutes; // 提前量（分钟）
  final bool enabled;

  const Reminder({
    this.id,
    required this.tripId,
    required this.type,
    required this.title,
    required this.subtitle,
    this.triggerTime,
    this.repeatRule,
    this.geoLat,
    this.geoLon,
    this.geoRadius,
    this.advanceMinutes = 0,
    this.enabled = true,
  });

  bool get isGeo => type == 'geofence';

  String get typeLabel {
    switch (type) {
      case 'alarm':
        return '闹钟';
      case 'geofence':
        return '地理围栏';
      case 'onsale':
        return '开售提醒';
      case 'depart':
        return '出发提醒';
      default:
        return type;
    }
  }

  Reminder copyWith({
    int? id,
    int? tripId,
    String? type,
    String? title,
    String? subtitle,
    DateTime? triggerTime,
    String? repeatRule,
    double? geoLat,
    double? geoLon,
    double? geoRadius,
    int? advanceMinutes,
    bool? enabled,
  }) {
    return Reminder(
      id: id ?? this.id,
      tripId: tripId ?? this.tripId,
      type: type ?? this.type,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      triggerTime: triggerTime ?? this.triggerTime,
      repeatRule: repeatRule ?? this.repeatRule,
      geoLat: geoLat ?? this.geoLat,
      geoLon: geoLon ?? this.geoLon,
      geoRadius: geoRadius ?? this.geoRadius,
      advanceMinutes: advanceMinutes ?? this.advanceMinutes,
      enabled: enabled ?? this.enabled,
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'trip_id': tripId,
        'type': type,
        'title': title,
        'subtitle': subtitle,
        'trigger_time': triggerTime?.toIso8601String(),
        'repeat_rule': repeatRule,
        'geo_lat': geoLat,
        'geo_lon': geoLon,
        'geo_radius': geoRadius,
        'advance_minutes': advanceMinutes,
        'enabled': enabled ? 1 : 0,
      };

  static Reminder fromMap(Map<String, Object?> m) => Reminder(
        id: m['id'] as int?,
        tripId: m['trip_id'] as int,
        type: m['type'] as String,
        title: m['title'] as String,
        subtitle: m['subtitle'] as String? ?? '',
        triggerTime: m['trigger_time'] == null
            ? null
            : DateTime.parse(m['trigger_time'] as String),
        repeatRule: m['repeat_rule'] as String?,
        geoLat: (m['geo_lat'] as num?)?.toDouble(),
        geoLon: (m['geo_lon'] as num?)?.toDouble(),
        geoRadius: (m['geo_radius'] as num?)?.toDouble(),
        advanceMinutes: m['advance_minutes'] as int? ?? 0,
        enabled: (m['enabled'] as int? ?? 1) == 1,
      );
}
