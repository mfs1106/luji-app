import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luji_app/models/trip.dart';
import 'package:luji_app/screens/trip_editor_dialog.dart';

void main() {
  for (final count in [3, 5]) {
    testWidgets('creating a $count-day trip derives its end date',
        (tester) async {
      Trip? saved;
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
        body: Builder(
            builder: (context) => FilledButton(
                  onPressed: () async {
                    saved = await showDialog<Trip>(
                        context: context,
                        builder: (_) => const TripEditorDialog());
                  },
                  child: const Text('新建'),
                )),
      )));
      await tester.tap(find.text('新建'));
      await tester.pumpAndSettle();
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), '周末旅行');
      await tester.enterText(fields.at(1), '杭州');
      await tester.enterText(fields.at(2), '$count');
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      expect(saved, isNotNull);
      expect(saved!.days, count);
      expect(saved!.endDate.difference(saved!.startDate).inDays, count - 1);
    });
  }
}
