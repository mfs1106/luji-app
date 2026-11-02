import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:luji_app/data/app_db.dart';
import 'package:luji_app/models/expense.dart';
import 'package:luji_app/models/itinerary_item.dart';
import 'package:luji_app/models/reminder.dart';
import 'package:luji_app/models/spot.dart';
import 'package:luji_app/models/travel_note.dart';
import 'package:luji_app/models/trip.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a blank trip persists its linked features and resize/delete updates them',
      () async {
    sqfliteFfiInit();
    final directory = await Directory.systemTemp.createTemp('luji_db_test_');
    databaseFactory = databaseFactoryFfi;
    await databaseFactoryFfi.setDatabasesPath(directory.path);
    final store = AppDb.instance;

    expect(await store.trips(), isEmpty);
    final tripId = await store.insertTrip(Trip(
      title: 'Test trip',
      city: 'Xiamen',
      startDate: DateTime(2026, 10, 21),
      endDate: DateTime(2026, 10, 23),
      days: 3,
      budgetTotal: 3000,
    ));
    expect((await store.trips()).single.days, 3);
    expect((await store.items(tripId, 2)), isEmpty);

    final spotId = await store.insertSpot(Spot(
      tripId: tripId,
      name: 'First stop',
      lat: 24.4798,
      lon: 118.0894,
      city: 'Xiamen',
      category: 'spot',
      openTime: '09:00-18:00',
      stayMinutes: 90,
      dayIndex: 3,
    ));
    await store.insertItem(ItineraryItem(
      tripId: tripId,
      dayIndex: 3,
      spotId: spotId,
      name: 'First stop',
      startTime: '09:00',
      endTime: '10:30',
    ));
    await store.insertExpense(Expense(
      tripId: tripId,
      city: 'Xiamen',
      category: 'ticket',
      amount: 80,
      source: 'manual',
      spentAt: DateTime(2026, 10, 21),
      placeName: '景区售票处',
      itemName: '门票',
      paymentMethod: '微信支付',
    ));
    await store.insertNote(TravelNote(
      tripId: tripId,
      dayIndex: 3,
      content: 'A real note',
      createdAt: DateTime(2026, 10, 21),
    ));
    await store.insertReminder(const Reminder(
      tripId: 0,
      type: 'alarm',
      title: 'Independent reminder',
      subtitle: '',
    ));

    final renamed = (await store.spots(tripId)).single.copyWith(name: 'Renamed stop');
    await store.updateSpot(renamed);
    await store.syncItemsForSpot(renamed);
    expect((await store.items(tripId, 3)).single.name, 'Renamed stop');
    expect((await store.expenses(tripId)).single.amount, 80);
    expect((await store.expenses(tripId)).single.placeName, '景区售票处');
    expect((await store.expenses(tripId)).single.itemName, '门票');
    expect((await store.expenses(tripId)).single.paymentMethod, '微信支付');
    expect((await store.notes(tripId)).single.content, 'A real note');

    final trip = (await store.trips()).single;
    await store.updateTrip(trip.copyWith(
      days: 2,
      endDate: DateTime(2026, 10, 22),
    ));
    await store.reassignDaysAfterTripResize(tripId, 2);
    expect((await store.spots(tripId)).single.dayIndex, 2);
    expect((await store.items(tripId, 2)).single.name, 'Renamed stop');
    expect((await store.notes(tripId)).single.dayIndex, 2);

    await store.deleteTrip(tripId);
    expect(await store.trips(), isEmpty);
    expect(await store.spots(tripId), isEmpty);
    expect(await store.items(tripId, 2), isEmpty);
    expect(await store.expenses(tripId), isEmpty);
    expect(await store.notes(tripId), isEmpty);
    expect((await store.reminders(0)).single.title, 'Independent reminder');
    await (await store.db).close();
    await directory.delete(recursive: true);
  });
}
