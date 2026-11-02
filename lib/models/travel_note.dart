/// 旅途随手记
class TravelNote {
  final int? id;
  final int tripId;
  final int dayIndex;
  final String content;
  final List<String> photos; // 本地路径或 OSS 地址
  final DateTime createdAt;

  const TravelNote({
    this.id,
    required this.tripId,
    required this.dayIndex,
    required this.content,
    this.photos = const [],
    required this.createdAt,
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'trip_id': tripId,
        'day_index': dayIndex,
        'content': content,
        'photos': photos.join('|||'), // 简单序列化；生产建议 JSON
        'created_at': createdAt.toIso8601String(),
      };

  static TravelNote fromMap(Map<String, Object?> m) => TravelNote(
        id: m['id'] as int?,
        tripId: m['trip_id'] as int,
        dayIndex: m['day_index'] as int,
        content: m['content'] as String,
        photos: (m['photos'] as String? ?? '')
            .split('|||')
            .where((s) => s.isNotEmpty)
            .toList(),
        createdAt: DateTime.parse(m['created_at'] as String),
      );
}
