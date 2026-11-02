/// 行程主表：一次旅行（如「厦门 3 天 2 晚」）
class Trip {
  final int? id;
  final String title; // 行程标题
  final String city; // 目的地城市
  final DateTime startDate;
  final DateTime endDate;
  final int days;
  final double budgetTotal; // 总预算（元）
  final String status; // planned / ongoing / finished

  const Trip({
    this.id,
    required this.title,
    required this.city,
    required this.startDate,
    required this.endDate,
    required this.days,
    required this.budgetTotal,
    this.status = 'ongoing',
  });

  int get spentDays =>
      endDate.difference(startDate).inDays + 1 > 0 ? days : 1;

  Trip copyWith({
    int? id,
    String? title,
    String? city,
    DateTime? startDate,
    DateTime? endDate,
    int? days,
    double? budgetTotal,
    String? status,
  }) {
    return Trip(
      id: id ?? this.id,
      title: title ?? this.title,
      city: city ?? this.city,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      days: days ?? this.days,
      budgetTotal: budgetTotal ?? this.budgetTotal,
      status: status ?? this.status,
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'title': title,
        'city': city,
        'start_date': startDate.toIso8601String(),
        'end_date': endDate.toIso8601String(),
        'days': days,
        'budget_total': budgetTotal,
        'status': status,
      };

  static Trip fromMap(Map<String, Object?> m) => Trip(
        id: m['id'] as int?,
        title: m['title'] as String,
        city: m['city'] as String,
        startDate: DateTime.parse(m['start_date'] as String),
        endDate: DateTime.parse(m['end_date'] as String),
        days: m['days'] as int,
        budgetTotal: (m['budget_total'] as num).toDouble(),
        status: m['status'] as String? ?? 'ongoing',
      );
}
