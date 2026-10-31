import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:tracktalk/food_editor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tracktalk/food_page.dart';
import 'package:tracktalk/food_history_page.dart';
import 'package:tracktalk/food_service.dart';

const stored = {
  'id': 7,
  'meal_type': 'breakfast',
  'eaten_at': '2026-10-31T09:30:00Z',
  'items': [
    {'name': 'Porridge', 'quantity': '100.00', 'unit': 'g'},
    {'name': 'Milk', 'quantity': null, 'unit': ''},
  ],
};

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
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

Future<void> enterDraft(WidgetTester tester) async {
  await tapVisible(tester, find.byKey(const Key('add-manually')));
  await tester.enterText(find.byKey(const Key('food-name-0')), 'Porridge');
  await tester.enterText(find.byKey(const Key('food-quantity-0')), '100');
  await tester.enterText(find.byKey(const Key('food-unit-0')), 'g');
  await tapVisible(tester, find.byKey(const Key('add-food-item')));
  await tester.enterText(find.byKey(const Key('food-name-1')), 'Milk');
  await tapVisible(tester, find.byKey(const Key('review-record')));
}

void main() {
  test('amount formatting preserves integer zeroes and missing quantities', () {
    expect(
      const FoodItem(name: 'Rice', quantity: '100', unit: 'g').amount,
      '100 g',
    );
    expect(FoodRecord.fromJson(stored).items.first.amount, '100 g');
    expect(
      FoodRecord.fromJson(stored).items.last.amount,
      'Amount not provided',
    );
  });

  testWidgets(
    'review does not write; confirm stores all items and reloads history',
    (tester) async {
      final requests = <http.Request>[];
      final client = MockClient((request) async {
        requests.add(request);
        expect(request.headers['Authorization'], 'Token example-token');
        if (request.method == 'POST') {
          final data = jsonDecode(request.body) as Map<String, dynamic>;
          expect(data['items'], [
            {'name': 'Porridge', 'quantity': '100', 'unit': 'g'},
            {'name': 'Milk', 'quantity': null, 'unit': ''},
          ]);
          return http.Response(jsonEncode({...data, 'id': 7}), 201);
        }
        return http.Response(jsonEncode([stored]), 200);
      });
      await http.runWithClient(() async {
        await tester.pumpWidget(
          const MaterialApp(
            home: FoodPage(service: FoodService('example-token')),
          ),
        );
        await enterDraft(tester);
        expect(requests, isEmpty);
        expect(find.text('Amount not provided'), findsOneWidget);
        await tapVisible(tester, find.byKey(const Key('confirm-record')));
        expect(find.text('✓ Your food record has been saved.'), findsOneWidget);
        await tapVisible(tester, find.text('View history'));
        expect(find.text('Porridge'), findsOneWidget);
        expect(find.text('100 g'), findsOneWidget);
        expect(requests.map((r) => r.method), ['POST', 'GET']);
        expect(tester.takeException(), isNull);
      }, () => client);
      client.close();
    },
  );

  testWidgets(
    'design navigation is present and future destinations do not navigate',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: FoodPage(service: FoodService('token'))),
      );
      for (final name in ['home', 'food', 'add', 'activity', 'me']) {
        final destination = find.byKey(Key('nav-$name'));
        expect(destination, findsOneWidget);
        await tester.tap(destination, warnIfMissed: false);
        await tester.pumpAndSettle();
        expect(find.text('Add record'), findsOneWidget);
      }
      expect(find.text('Food diary'), findsNothing);
      expect(find.text('Sign out'), findsNothing);
      expect(find.text('Type what you ate...'), findsOneWidget);
      expect(find.text('Try an example'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'iOS meal picker commits with Done and keeps draft when cancelled',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: FoodEditor()));
      await tester.enterText(find.byKey(const Key('food-name-0')), 'Rice');
      await tapVisible(tester, find.byKey(const Key('meal-type')));
      final wheel = tester.widget<CupertinoPicker>(
        find.byKey(const Key('meal-picker')),
      );
      wheel.scrollController!.jumpToItem(1);
      await tester.pumpAndSettle();
      await tapVisible(tester, find.byKey(const Key('picker-cancel')));
      await tester.scrollUntilVisible(
        find.text('Edit your breakfast record'),
        -120,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('Edit your breakfast record'), findsOneWidget);
      expect(find.text('Rice'), findsOneWidget);
      await tapVisible(tester, find.byKey(const Key('meal-type')));
      tester
          .widget<CupertinoPicker>(find.byKey(const Key('meal-picker')))
          .scrollController!
          .jumpToItem(2);
      await tester.pumpAndSettle();
      await tapVisible(tester, find.byKey(const Key('picker-done')));
      await tester.scrollUntilVisible(
        find.text('Edit your dinner record'),
        -120,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('Edit your dinner record'), findsOneWidget);
      expect(find.text('Rice'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'iOS date and time wheels keep cancelled values and commit selected values',
    (tester) async {
      final date = DateTime(2026, 10, 10, 9, 30);
      await tester.pumpWidget(
        MaterialApp(
          home: FoodEditor(
            initialDraft: FoodDraft(
              mealType: 'breakfast',
              eatenAt: date,
              items: const [FoodItem(name: 'Rice')],
            ),
          ),
        ),
      );
      await tapVisible(tester, find.byKey(const Key('food-date')));
      final datePicker = tester.widget<CupertinoDatePicker>(
        find.byKey(const Key('date-picker')),
      );
      expect(datePicker.mode, CupertinoDatePickerMode.date);
      datePicker.onDateTimeChanged(DateTime(2026, 10, 11));
      await tapVisible(tester, find.byKey(const Key('picker-cancel')));
      expect(find.text('10 Oct 2026'), findsWidgets);
      await tapVisible(tester, find.byKey(const Key('food-time')));
      final timePicker = tester.widget<CupertinoDatePicker>(
        find.byKey(const Key('time-picker')),
      );
      expect(timePicker.mode, CupertinoDatePickerMode.time);
      timePicker.onDateTimeChanged(DateTime(2026, 10, 10, 12, 45));
      await tapVisible(tester, find.byKey(const Key('picker-done')));
      expect(find.text('12:45'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('failed save preserves draft and supports retry', (tester) async {
    var calls = 0;
    final client = MockClient((request) async {
      calls++;
      return calls == 1
          ? http.Response('unavailable', 503)
          : http.Response(
              jsonEncode({
                ...jsonDecode(request.body) as Map<String, dynamic>,
                'id': 7,
              }),
              201,
            );
    });
    await http.runWithClient(() async {
      await tester.pumpWidget(
        const MaterialApp(home: FoodPage(service: FoodService('token'))),
      );
      await enterDraft(tester);
      await tapVisible(tester, find.byKey(const Key('confirm-record')));
      expect(find.byKey(const Key('save-error')), findsOneWidget);
      expect(find.text('Porridge'), findsOneWidget);
      expect(find.text('✓ Your food record has been saved.'), findsNothing);
      await tapVisible(tester, find.byKey(const Key('confirm-record')));
      expect(find.text('✓ Your food record has been saved.'), findsOneWidget);
      expect(calls, 2);
    }, () => client);
    client.close();
  });

  testWidgets(
    'manual form validates names and paired amounts on a small screen',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        const MaterialApp(home: FoodPage(service: FoodService('token'))),
      );
      await tapVisible(tester, find.byKey(const Key('add-manually')));
      await tapVisible(tester, find.byKey(const Key('review-record')));
      expect(find.text('Enter a food name.'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('food-name-0')), 'Rice');
      await tester.enterText(find.byKey(const Key('food-quantity-0')), '-1');
      await tapVisible(tester, find.byKey(const Key('review-record')));
      expect(
        find.text('Use a positive number\n(up to 2 decimals).'),
        findsOneWidget,
      );
      expect(find.text('Enter a unit.'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('food-quantity-0')), '');
      await tapVisible(tester, find.byKey(const Key('review-record')));
      expect(find.text('Amount not provided'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('manual editor stays usable above an iOS keyboard', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpWidget(
      const MaterialApp(home: FoodPage(service: FoodService('token'))),
    );
    await tapVisible(tester, find.byKey(const Key('add-manually')));
    await tester.enterText(find.byKey(const Key('food-name-0')), 'Rice');
    tester.view.viewInsets = const FakeViewPadding(bottom: 240);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('food-quantity-0')), '100');
    await tapVisible(tester, find.text('Done'));
    tester.view.resetViewInsets();
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('food-unit-0')), 'g');
    await tapVisible(tester, find.byKey(const Key('review-record')));
    expect(find.text('100 g'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('history edit updates original record and refreshes', (
    tester,
  ) async {
    final methods = <String>[];
    Map<String, dynamic> record = Map.of(stored);
    final client = MockClient((request) async {
      methods.add(request.method);
      if (request.method == 'PUT') {
        expect(request.url.path, '/api/food-records/7/');
        record = {...jsonDecode(request.body) as Map<String, dynamic>, 'id': 7};
        return http.Response(jsonEncode(record), 200);
      }
      return http.Response(jsonEncode([record]), 200);
    });
    await http.runWithClient(() async {
      await tester.pumpWidget(
        const MaterialApp(home: FoodHistoryPage(service: FoodService('token'))),
      );
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('Edit'));
      await tapVisible(tester, find.text('Edit'));
      await tester.enterText(find.byKey(const Key('food-name-0')), 'Oats');
      await tapVisible(tester, find.byKey(const Key('review-record')));
      await tapVisible(tester, find.byKey(const Key('confirm-record')));
      await tapVisible(tester, find.text('View history'));
      expect(find.text('Oats'), findsOneWidget);
      expect(methods, ['GET', 'PUT', 'GET']);
      expect(tester.takeException(), isNull);
    }, () => client);
    client.close();
  });

  testWidgets('delete requires confirmation and waits for API success', (
    tester,
  ) async {
    var deletes = 0;
    final client = MockClient((request) async {
      if (request.method == 'DELETE') {
        deletes++;
        return http.Response('', 204);
      }
      return http.Response(jsonEncode([stored]), 200);
    });
    await http.runWithClient(() async {
      await tester.pumpWidget(
        const MaterialApp(home: FoodHistoryPage(service: FoodService('token'))),
      );
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('Delete'));
      await tapVisible(tester, find.text('Cancel'));
      expect(deletes, 0);
      await tapVisible(tester, find.text('Delete'));
      await tapVisible(
        tester,
        find.widgetWithText(CupertinoDialogAction, 'Delete'),
      );
      expect(deletes, 1);
      expect(find.text('No food records yet.'), findsOneWidget);
    }, () => client);
    client.close();
  });

  testWidgets('history failure offers retry without claiming diary is empty', (
    tester,
  ) async {
    final client = MockClient((_) async => http.Response('offline', 503));
    await http.runWithClient(() async {
      await tester.pumpWidget(
        const MaterialApp(home: FoodHistoryPage(service: FoodService('token'))),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('history-error')), findsOneWidget);
      expect(find.text('No food records yet.'), findsNothing);
      expect(find.text('Try again'), findsOneWidget);
    }, () => client);
    client.close();
  });
}
