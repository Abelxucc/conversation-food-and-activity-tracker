import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tracktalk/app_shell.dart';
import 'package:tracktalk/food/food_service.dart';
import 'package:tracktalk/food/food_page.dart';

const app = MaterialApp(home: AppShell(service: FoodService('activity-token')));

Finder byKey(String value) => find.byKey(Key(value));

Future<void> tap(WidgetTester tester, Finder finder) async {
  await tester.pumpAndSettle();
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      finder,
      180,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> startActivity(WidgetTester tester) async {
  await tap(tester, byKey('nav-add'));
  await tap(tester, byKey('record-mode-activity'));
  await tap(tester, byKey('add-activity-manually'));
}

Future<void> setPicker(
  WidgetTester tester,
  String field,
  DateTime value,
) async {
  await tap(tester, byKey('activity-$field'));
  tester
      .widget<CupertinoDatePicker>(byKey('activity-$field-picker'))
      .onDateTimeChanged(value);
  await tap(tester, byKey('picker-done'));
}

void main() {
  testWidgets('routes messages both ways and enables direct Activity input', (
    tester,
  ) async {
    const run = 'I went jogging for 30 minutes at 08:15.';
    const walk = 'I went for a walk.';
    const tea = 'I had one cup of bubble tea for afternoon tea.';
    final modes = <String>[];
    final records = <Map<String, dynamic>>[];
    final foodRecords = <Map<String, dynamic>>[];
    final client = MockClient((request) async {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      if (request.url.path == '/api/food-records/parse/') {
        modes.add(body['mode'] as String);
        if (body['text'] == tea) {
          return http.Response(
            jsonEncode({
              'meal_type': 'afternoon_tea',
              'date': body['reference_date'],
              'time': null,
              'items': [
                {'name': 'Bubble tea', 'quantity': 1, 'unit': 'cup'},
              ],
            }),
            200,
          );
        }
        final jogging = body['text'] == run;
        expect(body['text'], jogging ? run : walk);
        return http.Response(
          jsonEncode({
            'kind': 'activity',
            'activity_name': jogging ? 'Jogging' : 'Walking',
            'duration_minutes': jogging ? 30 : null,
            'date': body['reference_date'],
            'time': jogging ? '08:15' : null,
          }),
          200,
        );
      }
      expect(request.method, 'POST');
      if (request.url.path == '/api/food-records/') {
        foodRecords.add(body);
        return http.Response(jsonEncode({...body, 'id': 1}), 201);
      }
      expect(request.url.path, '/api/activity-records/');
      records.add(body);
      return http.Response(jsonEncode({...body, 'id': records.length}), 201);
    });

    await http.runWithClient(() async {
      await tester.pumpWidget(
        const MaterialApp(
          home: FoodPage(service: FoodService('activity-token')),
        ),
      );

      Future<void> send(String mode, String text) async {
        await tester.enterText(byKey('$mode-description'), text);
        await tester.pump();
        await tester.tap(byKey('parse-$mode'));
        await tester.pump();
        // The pending turn may enter the viewport during the scroll animation.
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 300));
        expect(byKey('food-typing'), findsOneWidget);
        await tester.pump(const Duration(milliseconds: 600));
        await tester.pumpAndSettle();
      }

      await send('food', run);
      expect(byKey('activity-description'), findsOneWidget);
      expect(byKey('food-description'), findsNothing);
      expect(find.text(run), findsOneWidget);
      expect(find.text('30 minutes'), findsOneWidget);
      expect(find.text('08:15'), findsOneWidget);
      expect(find.text('Try an example'), findsNothing);
      expect(records, isEmpty);
      await tap(tester, byKey('confirm-activity'));
      expect(find.text('✓ Your activity has been saved.'), findsOneWidget);
      expect(records.single['duration_minutes'], 30);
      expect(records.single['time_specified'], true);
      await tap(tester, byKey('record-mode-food'));
      expect(find.text(run), findsNothing);
      await tap(tester, byKey('record-mode-activity'));

      await send('activity', tea);
      expect(byKey('food-description'), findsOneWidget);
      expect(byKey('activity-description'), findsNothing);
      expect(find.text(tea), findsOneWidget);
      expect(find.text('Bubble tea'), findsOneWidget);
      expect(find.text('1 cup'), findsOneWidget);
      expect(foodRecords, isEmpty);
      await tap(tester, byKey('confirm-record'));
      expect(foodRecords.single['meal_type'], 'afternoon_tea');
      expect(find.text('✓ Your afternoon tea has been saved.'), findsOneWidget);

      await tap(tester, byKey('record-mode-activity'));
      expect(find.text(tea), findsNothing);
      await send('activity', walk);
      expect(find.text(walk), findsOneWidget);
      expect(find.text('Duration not specified'), findsOneWidget);
      expect(
        tester.widget<CupertinoButton>(byKey('confirm-activity')).onPressed,
        isNull,
      );
      await tap(tester, find.text('Edit'));
      expect(find.text('Edit activity'), findsOneWidget);
      expect(find.text('Walking'), findsOneWidget);
      await tester.enterText(byKey('activity-duration'), '20');
      await tap(tester, byKey('review-activity'));
      expect(find.text('20 minutes'), findsOneWidget);
      expect(records.last['duration_minutes'], 20);
      expect(records.last['time_specified'], false);
      expect(records, hasLength(2));
      expect(modes, ['food', 'activity', 'activity']);
      expect(tester.takeException(), isNull);
    }, () => client);
    client.close();
  });

  testWidgets(
    'manual activity is reviewed, saved, filtered, edited and deleted',
    (tester) async {
      tester.view.physicalSize = const Size(402, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final day = DateTime(2026, 10, 6);
      final editedTime = DateTime(2026, 10, 6, 10, 15);
      Map<String, dynamic>? saved;
      final writes = <String>[];

      Map<String, Object> meal(int id, String type, int hour, String name) => {
        'id': id,
        'meal_type': type,
        'eaten_at': DateTime(2026, 10, 6, hour).toUtc().toIso8601String(),
        'items': [
          {'name': name, 'quantity': null, 'unit': ''},
        ],
      };
      final client = MockClient((request) async {
        expect(request.headers['Authorization'], 'Token activity-token');
        if (request.url.path == '/api/food-records/') {
          expect(request.method, 'GET');
          return http.Response(
            jsonEncode([
              meal(8, 'lunch', 12, 'Sandwich'),
              meal(7, 'breakfast', 8, 'Porridge'),
            ]),
            200,
          );
        }
        if (request.url.path == '/api/food-recommendations/') {
          return http.Response('', 503);
        }
        expect(request.url.path, startsWith('/api/activity-records/'));
        if (request.method == 'GET') {
          return http.Response(jsonEncode([?saved]), 200);
        }
        writes.add(request.method);
        if (request.method == 'DELETE') {
          expect(request.url.path, '/api/activity-records/7/');
          saved = null;
          return http.Response('', 204);
        }
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        if (request.method == 'POST') {
          expect(request.url.path, '/api/activity-records/');
          expect(body, {
            'name': 'Jogging',
            'duration_minutes': 30,
            'occurred_at': day.toUtc().toIso8601String(),
            'time_specified': false,
          });
        } else {
          expect(request.method, 'PUT');
          expect(request.url.path, '/api/activity-records/7/');
          expect(body['duration_minutes'], 45);
          expect(body['occurred_at'], editedTime.toUtc().toIso8601String());
          expect(body['time_specified'], true);
        }
        saved = {...body, 'id': 7};
        return http.Response(
          jsonEncode(saved),
          request.method == 'POST' ? 201 : 200,
        );
      });

      await http.runWithClient(() async {
        await tester.pumpWidget(app);
        await startActivity(tester);
        expect(find.text('Add activity manually'), findsOneWidget);
        await tester.enterText(byKey('activity-name'), 'Jogging');
        await tester.enterText(byKey('activity-duration'), '30');
        await setPicker(tester, 'date', day);
        await tap(tester, byKey('review-activity'));
        expect(writes, isEmpty);
        expect(find.text('Review activity'), findsOneWidget);
        expect(find.text('30 minutes'), findsOneWidget);
        expect(find.text('Not specified'), findsOneWidget);

        await tap(tester, byKey('record-mode-food'));
        expect(find.byKey(const Key('add-manually')), findsOneWidget);
        await tap(tester, byKey('record-mode-activity'));
        expect(find.text('Jogging'), findsOneWidget);
        await tap(tester, byKey('confirm-activity'));
        expect(find.text('Activity saved ✓'), findsOneWidget);
        await tap(tester, find.text('View history'));
        expect(byKey('activity-history-7'), findsOneWidget);
        expect(find.text('Porridge'), findsNothing);
        expect(find.text('1 record'), findsOneWidget);

        await tap(tester, find.text('Edit'));
        expect(find.text('Edit activity'), findsOneWidget);
        expect(find.text('Jogging'), findsOneWidget);
        await tester.enterText(byKey('activity-duration'), '45');
        await setPicker(tester, 'time', editedTime);
        await tap(tester, byKey('review-activity'));
        expect(find.text('45 minutes'), findsOneWidget);
        expect(find.text('10:15'), findsOneWidget);
        await tap(tester, byKey('history-filter-all'));
        expect(find.text('3 records'), findsOneWidget);
        final activityY = tester.getTopLeft(find.text('Jogging')).dy;
        expect(
          tester.getTopLeft(find.text('Porridge')).dy,
          lessThan(activityY),
        );
        expect(
          tester.getTopLeft(find.text('Sandwich')).dy,
          greaterThan(activityY),
        );
        await tap(tester, byKey('history-filter-food'));
        expect(byKey('activity-history-7'), findsNothing);
        await tap(tester, byKey('history-filter-activity'));
        await tap(tester, find.text('Delete'));
        await tap(tester, find.text('Cancel'));
        expect(byKey('activity-history-7'), findsOneWidget);
        await tap(tester, find.text('Delete'));
        await tap(tester, find.text('Delete').last);
        expect(byKey('activity-history-7'), findsNothing);
        expect(writes, ['POST', 'PUT', 'DELETE']);
        await tap(tester, byKey('history-filter-all'));
        expect(find.text('Porridge'), findsOneWidget);
        expect(find.text('2 records'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }, () => client);
      client.close();
    },
  );

  testWidgets(
    'small screen validates duration and a failed save preserves the draft',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var calls = 0;
      final client = MockClient((request) async {
        if (request.method == 'GET') return http.Response('', 503);
        expect(request.method, 'POST');
        calls++;
        if (calls == 1) return http.Response('unavailable', 503);
        return http.Response(
          jsonEncode({
            ...jsonDecode(request.body) as Map<String, dynamic>,
            'id': 1,
          }),
          201,
        );
      });
      await http.runWithClient(() async {
        await tester.pumpWidget(app);
        await startActivity(tester);
        await tap(tester, byKey('review-activity'));
        expect(find.text('Enter an activity name.'), findsOneWidget);
        expect(
          find.text('Enter a valid whole number of minutes.'),
          findsOneWidget,
        );
        await tester.enterText(byKey('activity-name'), 'Walking');
        await tester.enterText(byKey('activity-duration'), '0');
        await tap(tester, byKey('review-activity'));
        expect(
          find.text('Enter a valid whole number of minutes.'),
          findsOneWidget,
        );
        await tester.enterText(byKey('activity-duration'), '20');
        await setPicker(tester, 'time', DateTime(2026, 10, 6, 8));
        await tap(tester, byKey('activity-clear-time'));
        await tap(tester, byKey('review-activity'));
        expect(calls, 0);
        await tap(tester, byKey('confirm-activity'));
        expect(
          find.text('Could not save or load your record. Please try again.'),
          findsOneWidget,
        );
        expect(find.text('Walking'), findsOneWidget);
        expect(find.text('20 minutes'), findsOneWidget);
        expect(find.text('Not specified'), findsOneWidget);
        await tap(tester, byKey('confirm-activity'));
        expect(find.text('Activity saved ✓'), findsOneWidget);
        expect(calls, 2);
        expect(tester.takeException(), isNull);
      }, () => client);
      client.close();
    },
  );
}
