import 'package:flutter/services.dart';

import '../data/app_db.dart';
import '../models/expense.dart';

/// Imports user-selected WeChat/Alipay CSV exports locally. No bill leaves the device.
class BillImportService {
  static const _files = MethodChannel('luji/files');

  static Future<int?> pickAndImport(
      {required int tripId,
      required String city,
      required String source,
      required DateTime startDate,
      required DateTime endDate}) async {
    final raw = await _files.invokeMethod<String>('pickCsv');
    if (raw == null) return null;
    final rows = _parseCsv(raw.replaceFirst('\uFEFF', ''));
    final headerIndex = rows.indexWhere((row) =>
        row.any((cell) => cell.contains('交易时间') || cell.contains('交易创建时间')));
    if (headerIndex < 0)
      throw const FormatException('找不到交易时间列，请选择微信或支付宝导出的 CSV 账单');
    final headers = rows[headerIndex];
    int column(List<String> names) =>
        headers.indexWhere((h) => names.any((name) => h.trim().contains(name)));
    final timeCol = column(['交易时间', '交易创建时间']);
    final amountCol = column(['金额(元)', '金额（元）', '金额']);
    final directionCol = column(['收/支', '收支类型', '交易类型']);
    final stateCol = column(['当前状态', '交易状态']);
    final nameCol = column(['商品', '交易对方', '商品说明']);
    final idCol = column(['交易单号', '交易号']);
    if (amountCol < 0) throw const FormatException('找不到金额列');
    var count = 0;
    for (final row in rows.skip(headerIndex + 1)) {
      String cell(int index) =>
          index >= 0 && index < row.length ? row[index].trim() : '';
      if (directionCol >= 0 && !cell(directionCol).contains('支出')) continue;
      if (stateCol >= 0 &&
          (cell(stateCol).contains('失败') ||
              cell(stateCol).contains('退款') ||
              cell(stateCol).contains('关闭'))) continue;
      final amount =
          double.tryParse(cell(amountCol).replaceAll(RegExp(r'[^0-9.]'), ''));
      if (amount == null || amount <= 0) continue;
      final time = DateTime.tryParse(cell(timeCol).replaceAll('/', '-'));
      if (time == null) continue;
      final day = DateTime(time.year, time.month, time.day);
      if (day.isBefore(
              DateTime(startDate.year, startDate.month, startDate.day)) ||
          day.isAfter(DateTime(endDate.year, endDate.month, endDate.day)))
        continue;
      final name = cell(nameCol);
      final tradeNo = cell(idCol);
      final inserted = await AppDb.instance.insertExpense(Expense(
          tripId: tripId,
          city: city,
          category: _category(name),
          amount: amount,
          source: source,
          tradeNo: tradeNo.isEmpty ? null : '$source:$tradeNo',
          spentAt: time,
          note: name));
      if (inserted > 0) count++;
    }
    return count;
  }

  static String _category(String name) {
    if (RegExp('门票|景区|博物馆').hasMatch(name)) return 'ticket';
    if (RegExp('酒店|民宿|住宿').hasMatch(name)) return 'hotel';
    if (RegExp('火车|机票|公交|地铁|打车|高铁').hasMatch(name)) return 'transport';
    if (RegExp('餐|饭|小吃|奶茶|咖啡').hasMatch(name)) return 'food';
    return 'other';
  }

  static List<List<String>> _parseCsv(String input) {
    final rows = <List<String>>[];
    var row = <String>[];
    final cell = StringBuffer();
    var quoted = false;
    for (var i = 0; i < input.length; i++) {
      final c = input[i];
      if (c == '"') {
        if (quoted && i + 1 < input.length && input[i + 1] == '"') {
          cell.write('"');
          i++;
        } else {
          quoted = !quoted;
        }
      } else if (c == ',' && !quoted) {
        row.add(cell.toString());
        cell.clear();
      } else if ((c == '\n' || c == '\r') && !quoted) {
        if (c == '\r' && i + 1 < input.length && input[i + 1] == '\n') i++;
        row.add(cell.toString());
        cell.clear();
        if (row.any((v) => v.isNotEmpty)) rows.add(row);
        row = <String>[];
      } else {
        cell.write(c);
      }
    }
    row.add(cell.toString());
    if (row.any((v) => v.isNotEmpty)) rows.add(row);
    return rows;
  }
}
