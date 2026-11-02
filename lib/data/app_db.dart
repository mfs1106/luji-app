import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/coupon.dart';
import '../models/expense.dart';
import '../models/itinerary_item.dart';
import '../models/reminder.dart';
import '../models/spot.dart';
import '../models/ticket.dart';
import '../models/travel_note.dart';
import '../models/trip.dart';

/// 本地数据库（sqflite）—— 本地优先架构的核心
/// 行程/景点/日程/票据/账目/提醒/笔记/券全部落本地库，联网后增量同步（见 API 文档 /sync/pull）
class AppDb {
  AppDb._();
  static final AppDb instance = AppDb._();

  static const _dbName = 'luji.db';
  static const _dbVersion = 4;

  Database? _db;
  Future<Database>? _opening;

  Future<Database> get db async {
    if (_db != null) return _db!;
    try {
      final opened = await (_opening ??= _open());
      _db = opened;
      return opened;
    } catch (_) {
      _opening = null;
      rethrow;
    }
  }

  Future<Database> _open() async {
    final dir = await getDatabasesPath();
    return openDatabase(
      p.join(dir, _dbName),
      version: _dbVersion,
      onUpgrade: (d, oldVersion, newVersion) async {
        if (oldVersion < 2) await _removeUntouchedDemo(d);
        if (oldVersion < 3) {
          await d.execute('ALTER TABLE spots ADD COLUMN booking_url TEXT');
        }
        if (oldVersion < 4) {
          await d.execute(
              "ALTER TABLE expenses ADD COLUMN place_name TEXT NOT NULL DEFAULT ''");
          await d.execute(
              "ALTER TABLE expenses ADD COLUMN item_name TEXT NOT NULL DEFAULT ''");
          await d.execute(
              "ALTER TABLE expenses ADD COLUMN payment_method TEXT NOT NULL DEFAULT ''");
        }
      },
      onCreate: (d, v) async {
        await d.execute('''
            CREATE TABLE trips(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              title TEXT NOT NULL,
              city TEXT NOT NULL,
              start_date TEXT NOT NULL,
              end_date TEXT NOT NULL,
              days INTEGER NOT NULL,
              budget_total REAL NOT NULL,
              status TEXT NOT NULL DEFAULT 'ongoing'
            )''');
        await d.execute('''
            CREATE TABLE spots(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              trip_id INTEGER NOT NULL,
              name TEXT NOT NULL,
              poi_id TEXT,
              lat REAL NOT NULL,
              lon REAL NOT NULL,
              city TEXT NOT NULL,
              category TEXT NOT NULL,
              open_time TEXT,
              stay_minutes INTEGER NOT NULL DEFAULT 60,
              ticket_price REAL,
              ticket_status TEXT NOT NULL DEFAULT 'none',
              day_index INTEGER NOT NULL DEFAULT 1,
              desc TEXT,
              booking_url TEXT
            )''');
        await d.execute('''
            CREATE TABLE itinerary_items(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              trip_id INTEGER NOT NULL,
              day_index INTEGER NOT NULL,
              spot_id INTEGER,
              name TEXT NOT NULL,
              start_time TEXT NOT NULL,
              end_time TEXT NOT NULL,
              transport TEXT NOT NULL DEFAULT 'walk',
              transport_minutes INTEGER NOT NULL DEFAULT 0,
              sort_order INTEGER NOT NULL DEFAULT 0,
              note TEXT
            )''');
        await d.execute('''
            CREATE TABLE tickets(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              trip_id INTEGER NOT NULL,
              type TEXT NOT NULL,
              name TEXT NOT NULL,
              use_time TEXT NOT NULL,
              code TEXT,
              qr_content TEXT,
              source TEXT NOT NULL DEFAULT 'manual',
              status TEXT NOT NULL DEFAULT 'pending',
              deep_link TEXT
            )''');
        await d.execute('''
            CREATE TABLE expenses(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              trip_id INTEGER NOT NULL,
              city TEXT NOT NULL,
              category TEXT NOT NULL,
              amount REAL NOT NULL,
              is_estimated INTEGER NOT NULL DEFAULT 0,
              source TEXT NOT NULL,
              trade_no TEXT UNIQUE,
              spent_at TEXT NOT NULL,
              note TEXT,
              place_name TEXT NOT NULL DEFAULT '',
              item_name TEXT NOT NULL DEFAULT '',
              payment_method TEXT NOT NULL DEFAULT ''
            )''');
        await d.execute('''
            CREATE TABLE reminders(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              trip_id INTEGER NOT NULL,
              type TEXT NOT NULL,
              title TEXT NOT NULL,
              subtitle TEXT,
              trigger_time TEXT,
              repeat_rule TEXT,
              geo_lat REAL,
              geo_lon REAL,
              geo_radius REAL,
              advance_minutes INTEGER NOT NULL DEFAULT 0,
              enabled INTEGER NOT NULL DEFAULT 1
            )''');
        await d.execute('''
            CREATE TABLE notes(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              trip_id INTEGER NOT NULL,
              day_index INTEGER NOT NULL,
              content TEXT NOT NULL,
              photos TEXT,
              created_at TEXT NOT NULL
            )''');
        await d.execute('''
            CREATE TABLE coupons(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              trip_id INTEGER NOT NULL,
              name TEXT NOT NULL,
              value TEXT,
              scope TEXT,
              valid_from TEXT NOT NULL,
              valid_to TEXT NOT NULL,
              code TEXT,
              deep_link TEXT
            )''');
      },
    );
  }

  /// Only remove the exact bundled demo on upgrade. Trips with changed item
  /// counts may contain user work and are deliberately left intact.
  Future<void> _removeUntouchedDemo(Database d) async {
    final candidates = await d.query('trips',
        where: 'title = ? AND city = ? AND start_date LIKE ?',
        whereArgs: ['厦门周末游', '厦门', '2026-10-18%']);
    for (final trip in candidates) {
      final id = trip['id'] as int;
      if (trip['days'] != 3 ||
          (trip['budget_total'] as num?)?.toDouble() != 3000 ||
          !(trip['end_date'] as String).startsWith('2026-10-20')) {
        continue;
      }
      const expected = {
        'spots': 6,
        'itinerary_items': 4,
        'tickets': 4,
        'expenses': 12,
        'reminders': 4,
        'notes': 2,
        'coupons': 2,
      };
      var untouched = true;
      for (final entry in expected.entries) {
        final count = Sqflite.firstIntValue(await d.rawQuery(
            'SELECT COUNT(*) FROM ${entry.key} WHERE trip_id = ?', [id]));
        if (count != entry.value) untouched = false;
      }
      final spent = Sqflite.firstIntValue(await d.rawQuery(
          'SELECT CAST(SUM(amount) AS INTEGER) FROM expenses WHERE trip_id = ?',
          [id]));
      if (spent != 1860) untouched = false;
      if (!untouched) continue;
      for (final table in expected.keys) {
        await d.delete(table, where: 'trip_id = ?', whereArgs: [id]);
      }
      await d.delete('trips', where: 'id = ?', whereArgs: [id]);
    }
  }

  // ---------------- Trip ----------------
  Future<int> insertTrip(Trip t) async => (await db).insert('trips', t.toMap());
  Future<List<Trip>> trips() async {
    final rows = await (await db).query('trips', orderBy: 'id DESC');
    return rows.map(Trip.fromMap).toList();
  }

  Future<int> updateTrip(Trip t) async =>
      (await db).update('trips', t.toMap(), where: 'id = ?', whereArgs: [t.id]);
  Future<void> reassignDaysAfterTripResize(int tripId, int lastDay) async {
    final d = await db;
    await d.transaction((txn) async {
      for (final table in ['spots', 'itinerary_items', 'notes']) {
        await txn.rawUpdate(
            'UPDATE $table SET day_index = ? WHERE trip_id = ? AND day_index > ?',
            [lastDay, tripId, lastDay]);
      }
    });
  }

  Future<void> deleteTrip(int id) async {
    final d = await db;
    await d.transaction((txn) async {
      for (final table in [
        'spots',
        'itinerary_items',
        'tickets',
        'expenses',
        'reminders',
        'notes',
        'coupons'
      ]) {
        await txn.delete(table, where: 'trip_id = ?', whereArgs: [id]);
      }
      await txn.delete('trips', where: 'id = ?', whereArgs: [id]);
    });
  }

  // ---------------- Spot ----------------
  Future<int> insertSpot(Spot s) async => (await db).insert('spots', s.toMap());
  Future<List<Spot>> spots(int tripId) async {
    final rows = await (await db)
        .query('spots', where: 'trip_id = ?', whereArgs: [tripId]);
    return rows.map(Spot.fromMap).toList();
  }

  Future<int> updateSpot(Spot s) async =>
      (await db).update('spots', s.toMap(), where: 'id = ?', whereArgs: [s.id]);
  Future<void> syncItemsForSpot(Spot s) async {
    await (await db).update(
        'itinerary_items', {'name': s.name, 'day_index': s.dayIndex},
        where: 'spot_id = ?', whereArgs: [s.id]);
  }

  Future<void> deleteSpot(int id) async {
    final d = await db;
    await d.transaction((txn) async {
      await txn
          .delete('itinerary_items', where: 'spot_id = ?', whereArgs: [id]);
      await txn.delete('spots', where: 'id = ?', whereArgs: [id]);
    });
  }

  // ---------------- ItineraryItem ----------------
  Future<int> insertItem(ItineraryItem i) async =>
      (await db).insert('itinerary_items', i.toMap());
  Future<List<ItineraryItem>> items(int tripId, int dayIndex) async {
    final rows = await (await db).query(
      'itinerary_items',
      where: 'trip_id = ? AND day_index = ?',
      whereArgs: [tripId, dayIndex],
      orderBy: 'sort_order ASC',
    );
    return rows.map(ItineraryItem.fromMap).toList();
  }

  Future<void> updateItemsOrder(List<ItineraryItem> list) async {
    final d = await db;
    final batch = d.batch();
    for (var i = 0; i < list.length; i++) {
      batch.update('itinerary_items', {'sort_order': i},
          where: 'id = ?', whereArgs: [list[i].id]);
    }
    await batch.commit(noResult: true);
  }

  Future<int> insertItemAndGetId(ItineraryItem i) async => insertItem(i);
  Future<int> updateItem(ItineraryItem i) async => (await db)
      .update('itinerary_items', i.toMap(), where: 'id = ?', whereArgs: [i.id]);
  Future<int> deleteItem(int id) async =>
      (await db).delete('itinerary_items', where: 'id = ?', whereArgs: [id]);

  // ---------------- Ticket ----------------
  Future<int> insertTicket(Ticket t) async =>
      (await db).insert('tickets', t.toMap());
  Future<List<Ticket>> tickets(int tripId) async {
    final rows = await (await db).query(
      'tickets',
      where: 'trip_id = ?',
      whereArgs: [tripId],
      orderBy: 'use_time ASC',
    );
    return rows.map(Ticket.fromMap).toList();
  }

  Future<int> updateTicket(Ticket t) async => (await db)
      .update('tickets', t.toMap(), where: 'id = ?', whereArgs: [t.id]);
  Future<int> deleteTicket(int id) async =>
      (await db).delete('tickets', where: 'id = ?', whereArgs: [id]);

  // ---------------- Expense ----------------
  /// 插入账目；trade_no 已存在则忽略（账单导入去重）
  Future<int> insertExpense(Expense e) async {
    final d = await db;
    if (e.tradeNo != null) {
      final exist = await d.query('expenses',
          where: 'trade_no = ?', whereArgs: [e.tradeNo], limit: 1);
      if (exist.isNotEmpty) return -1;
    }
    return d.insert('expenses', e.toMap());
  }

  Future<List<Expense>> expenses(int tripId, {String? city}) async {
    final d = await db;
    final rows = city == null || city == '全部'
        ? await d.query('expenses',
            where: 'trip_id = ?', whereArgs: [tripId], orderBy: 'spent_at DESC')
        : await d.query('expenses',
            where: 'trip_id = ? AND city = ?',
            whereArgs: [tripId, city],
            orderBy: 'spent_at DESC');
    return rows.map(Expense.fromMap).toList();
  }

  Future<List<String>> expenseCities(int tripId) async {
    final rows = await (await db).query('expenses',
        columns: ['city'],
        distinct: true,
        where: 'trip_id = ?',
        whereArgs: [tripId]);
    return rows.map((r) => r['city'] as String).toList();
  }

  Future<int> updateExpense(Expense e) async => (await db)
      .update('expenses', e.toMap(), where: 'id = ?', whereArgs: [e.id]);
  Future<int> deleteExpense(int id) async =>
      (await db).delete('expenses', where: 'id = ?', whereArgs: [id]);

  // ---------------- Reminder ----------------
  Future<int> insertReminder(Reminder r) async =>
      (await db).insert('reminders', r.toMap());
  Future<List<Reminder>> reminders(int tripId) async {
    final rows = await (await db)
        .query('reminders', where: 'trip_id = ?', whereArgs: [tripId]);
    return rows.map(Reminder.fromMap).toList();
  }

  Future<int> updateReminder(Reminder r) async => (await db)
      .update('reminders', r.toMap(), where: 'id = ?', whereArgs: [r.id]);
  Future<int> deleteReminder(int id) async =>
      (await db).delete('reminders', where: 'id = ?', whereArgs: [id]);

  // ---------------- Note ----------------
  Future<int> insertNote(TravelNote n) async =>
      (await db).insert('notes', n.toMap());
  Future<List<TravelNote>> notes(int tripId) async {
    final rows = await (await db).query('notes',
        where: 'trip_id = ?', whereArgs: [tripId], orderBy: 'created_at DESC');
    return rows.map(TravelNote.fromMap).toList();
  }

  Future<int> updateNote(TravelNote n) async =>
      (await db).update('notes', n.toMap(), where: 'id = ?', whereArgs: [n.id]);
  Future<int> deleteNote(int id) async =>
      (await db).delete('notes', where: 'id = ?', whereArgs: [id]);

  // ---------------- Coupon ----------------
  Future<int> insertCoupon(Coupon c) async =>
      (await db).insert('coupons', c.toMap());
  Future<List<Coupon>> coupons(int tripId) async {
    final rows = await (await db)
        .query('coupons', where: 'trip_id = ?', whereArgs: [tripId]);
    return rows.map(Coupon.fromMap).toList();
  }

  Future<int> updateCoupon(Coupon c) async => (await db)
      .update('coupons', c.toMap(), where: 'id = ?', whereArgs: [c.id]);
  Future<int> deleteCoupon(int id) async =>
      (await db).delete('coupons', where: 'id = ?', whereArgs: [id]);
}
