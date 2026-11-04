import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:tracktalk/food/food_editor.dart';
import 'package:tracktalk/food/food_amount.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tracktalk/food/food_page.dart';
import 'package:tracktalk/history/food_history_page.dart';
import 'package:tracktalk/food/food_service.dart';

// Food-flow tests keep their existing food responses when History also loads activities.
MockClient foodClient(Future<http.Response> Function(http.Request) handler) =>
    MockClient((request) async {
      if (request.method == 'GET' &&
          request.url.path == '/api/activity-records/') {
        return http.Response('[]', 200);
      }
      return handler(request);
    });

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

Future<void> chooseMeal(WidgetTester tester) async {
  await tapVisible(tester, find.byKey(const Key('meal-type')));
  await tapVisible(tester, find.byKey(const Key('picker-done')));
}

Future<void> chooseUnit(WidgetTester tester, int index, int unitIndex) async {
  await tapVisible(tester, find.byKey(Key('choose-amount-$index')));
  tester
      .widget<CupertinoPicker>(find.byKey(const Key('amount-unit-picker')))
      .scrollController!
      .jumpToItem(unitIndex);
  await tester.pumpAndSettle();
  await tapVisible(tester, find.byKey(const Key('amount-done')));
}

Future<void> enterDraft(WidgetTester tester) async {
  await tapVisible(tester, find.byKey(const Key('add-manually')));
  await tester.enterText(find.byKey(const Key('food-name-0')), 'Porridge');
  await chooseMeal(tester);
  await tester.enterText(find.byKey(const Key('food-amount-0')), '100');
  await chooseUnit(tester, 0, 5);
  await tapVisible(tester, find.byKey(const Key('add-food-item')));
  await tester.enterText(find.byKey(const Key('food-name-1')), 'Milk');
  await tapVisible(tester, find.byKey(const Key('review-record')));
}

void main() {
  testWidgets('text entry reviews the AI draft before posting a record', (
    tester,
  ) async {
    final paths = <String>[];
    final client = foodClient((request) async {
      paths.add(request.url.path);
      if (request.url.path == '/api/food-records/parse/') {
        expect(jsonDecode(request.body)['text'], 'Porridge for breakfast');
        return http.Response(
          jsonEncode({
            'meal_type': 'breakfast',
            'date': '2026-11-04',
            'time': null,
            'items': [
              {'name': 'Porridge', 'quantity': null, 'unit': ''},
            ],
          }),
          200,
        );
      }
      expect(request.url.path, '/api/food-records/');
      expect(jsonDecode(request.body)['time_specified'], isFalse);
      return http.Response(
        jsonEncode({...stored, 'time_specified': false}),
        201,
      );
    });
    await http.runWithClient(() async {
      await tester.pumpWidget(
        const MaterialApp(home: FoodPage(service: FoodService('test-token'))),
      );
      await tester.enterText(
        find.byKey(const Key('food-description')),
        'Porridge for breakfast',
      );
      await tapVisible(tester, find.byKey(const Key('parse-food')));
      expect(find.byKey(const Key('confirm-record')), findsOneWidget);
      expect(find.textContaining('Time not specified'), findsOneWidget);
      expect(paths, ['/api/food-records/parse/']);
      await tapVisible(tester, find.byKey(const Key('page-back')));
      await tapVisible(tester, find.text('Keep draft'));
      expect(find.text('Porridge'), findsOneWidget);
      await tapVisible(tester, find.byKey(const Key('confirm-record')));
      expect(paths, ['/api/food-records/parse/', '/api/food-records/']);
    }, () => client);
  });

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

  test('amounts accept item counts and preserve explicit units', () {
    for (final input in ['1 bowl', '100g', '0.5 banana', '1.25 slices']) {
      expect(FoodAmount.tryParse(input), isNotNull);
    }
    expect(FoodAmount.tryParse('100g')!.quantity, '100');
    expect(FoodAmount.tryParse('100g')!.unit, 'g');
    for (final input in ['1', '2', '0.5', '100', '999999.99']) {
      expect(FoodAmount.tryParse(input)!.quantity, input);
      expect(FoodAmount.tryParse(input)!.unit, 'item');
    }
    for (final input in [
      '-1 bowl',
      '0 g',
      '0',
      '-1',
      '1.234',
      '1000000',
      '1.234 g',
      '1/2 bowl',
      '1000000 g',
    ]) {
      expect(FoodAmount.tryParse(input), isNull, reason: input);
    }
    expect(FoodAmount.isUnspecified(''), isTrue);
    expect(FoodAmount.isUnspecified('Not specified'), isTrue);
  });

  testWidgets(
    'bare count saves with filled foods and ignores empty extra rows',
    (tester) async {
      final requests = <http.Request>[];
      final client = foodClient((request) async {
        requests.add(request);
        final data = jsonDecode(request.body) as Map<String, dynamic>;
        expect(data['items'], [
          {'name': 'Banana', 'quantity': '1', 'unit': 'item'},
          {'name': 'Milk', 'quantity': null, 'unit': ''},
        ]);
        return http.Response(jsonEncode({...data, 'id': 7}), 201);
      });
      await http.runWithClient(() async {
        await tester.pumpWidget(
          const MaterialApp(home: FoodPage(service: FoodService('token'))),
        );
        await tapVisible(tester, find.byKey(const Key('add-manually')));
        await chooseMeal(tester);
        // Leave the first row blank, and an accidental blank row at the end.
        await tapVisible(tester, find.byKey(const Key('add-food-item')));
        await tester.enterText(find.byKey(const Key('food-name-1')), 'Banana');
        await tester.enterText(find.byKey(const Key('food-amount-1')), '1');
        await tapVisible(tester, find.byKey(const Key('add-food-item')));
        await tester.enterText(find.byKey(const Key('food-name-2')), 'Milk');
        await tapVisible(tester, find.byKey(const Key('add-food-item')));
        await tester.enterText(find.byKey(const Key('food-name-3')), '   ');
        await tapVisible(tester, find.byKey(const Key('review-record')));
        expect(find.byType(FoodEditor), findsNothing);
        expect(find.text('Banana'), findsOneWidget);
        expect(find.text('1 item'), findsOneWidget);
        expect(requests, isEmpty);
        await tapVisible(tester, find.byKey(const Key('confirm-record')));
        expect(requests, hasLength(1));
        expect(find.text('✓ Your food record has been saved.'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }, () => client);
      client.close();
    },
  );

  testWidgets(
    'amount without a name requires correction and keeps other rows',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: FoodPage(service: FoodService('token'))),
      );
      await tapVisible(tester, find.byKey(const Key('add-manually')));
      await chooseMeal(tester);
      await tester.enterText(find.byKey(const Key('food-name-0')), 'Banana');
      await tester.enterText(find.byKey(const Key('food-amount-0')), '1');
      await tapVisible(tester, find.byKey(const Key('add-food-item')));
      await tester.enterText(find.byKey(const Key('food-amount-1')), '2');
      await tapVisible(tester, find.byKey(const Key('review-record')));
      expect(find.text('Enter a food name.'), findsOneWidget);
      expect(find.text('Banana'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('food-amount-1')), '');
      await tapVisible(tester, find.byKey(const Key('review-record')));
      expect(find.byType(FoodEditor), findsNothing);
      expect(find.text('1 item'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'typed quantity and unit wheel support cancel and unspecified on small screen',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        const MaterialApp(home: FoodPage(service: FoodService('token'))),
      );
      await tapVisible(tester, find.byKey(const Key('add-manually')));
      await chooseMeal(tester);
      await tester.enterText(find.byKey(const Key('food-name-0')), 'Porridge');
      await tester.enterText(find.byKey(const Key('food-amount-0')), '2');
      await tapVisible(tester, find.byKey(const Key('choose-amount-0')));
      expect(find.byKey(const Key('amount-quantity-picker')), findsNothing);
      tester
          .widget<CupertinoPicker>(find.byKey(const Key('amount-unit-picker')))
          .scrollController!
          .jumpToItem(1);
      await tester.pumpAndSettle();
      await tapVisible(tester, find.byKey(const Key('amount-done')));
      expect(find.text('2'), findsOneWidget);
      expect(find.text('Bowl'), findsOneWidget);
      await tapVisible(tester, find.byKey(const Key('choose-amount-0')));
      tester
          .widget<CupertinoPicker>(find.byKey(const Key('amount-unit-picker')))
          .scrollController!
          .jumpToItem(5);
      await tester.pumpAndSettle();
      await tapVisible(tester, find.byKey(const Key('amount-cancel')));
      expect(find.text('2'), findsOneWidget);
      expect(find.text('Bowl'), findsOneWidget);
      await tapVisible(tester, find.byKey(const Key('choose-amount-0')));
      await tapVisible(tester, find.byKey(const Key('amount-unspecified')));
      expect(find.text('2'), findsNothing);
      await tapVisible(tester, find.byKey(const Key('review-record')));
      expect(find.text('Amount not provided'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'unit picker preserves precise quantities and existing custom units',
    (tester) async {
      for (final item in [
        const FoodItem(name: 'Banana', quantity: '0.1', unit: 'banana'),
        const FoodItem(name: 'Banana', quantity: '1.25', unit: 'banana'),
        const FoodItem(name: 'Rice', quantity: '1500', unit: 'g'),
      ]) {
        FoodDraft? saved;
        await tester.pumpWidget(
          MaterialApp(
            key: UniqueKey(),
            home: FoodEditor(
              initialDraft: FoodDraft(
                mealType: 'breakfast',
                eatenAt: DateTime(2026, 10, 31),
                items: [item],
              ),
              onSave: (draft) async => saved = draft,
            ),
          ),
        );
        await tapVisible(tester, find.byKey(const Key('choose-amount-0')));
        expect(find.byKey(const Key('amount-quantity-picker')), findsNothing);
        await tapVisible(tester, find.byKey(const Key('amount-done')));
        expect(find.text(item.quantity!), findsOneWidget);
        await tapVisible(tester, find.byKey(const Key('review-record')));
        expect(saved!.items.single.quantity, item.quantity);
        expect(saved!.items.single.unit, item.unit);
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets(
    'review back asks before discarding and returns to food input after confirmation',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: FoodPage(service: FoodService('token'))),
      );
      await tapVisible(tester, find.byKey(const Key('add-manually')));
      await tester.enterText(
        find.byKey(const Key('food-name-0')),
        'Unused draft',
      );
      await tapVisible(tester, find.byKey(const Key('page-back')));
      expect(find.byType(FoodEditor), findsNothing);
      await enterDraft(tester);
      await tapVisible(tester, find.byKey(const Key('page-back')));
      expect(find.text('Discard this draft?'), findsOneWidget);
      expect(find.byType(FoodEditor), findsNothing);
      await tapVisible(tester, find.text('Keep draft'));
      expect(find.byKey(const Key('confirm-record')), findsOneWidget);
      expect(find.text('Porridge'), findsOneWidget);
      await tapVisible(tester, find.byKey(const Key('page-back')));
      await tapVisible(tester, find.text('Discard'));
      expect(find.byKey(const Key('food-description')), findsOneWidget);
      expect(find.byKey(const Key('confirm-record')), findsNothing);
      expect(find.byType(FoodEditor), findsNothing);
    },
  );

  testWidgets('edit rows remove the selected food and keep the other amount', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: FoodPage(service: FoodService('token'))),
    );
    await enterDraft(tester);
    await tapVisible(tester, find.text('Edit'));
    await tapVisible(tester, find.byKey(const Key('remove-food-1')));
    expect(find.text('Milk'), findsNothing);
    expect(find.text('100'), findsOneWidget);
    await tapVisible(tester, find.byKey(const Key('review-record')));
    expect(find.text('Milk'), findsNothing);
    expect(find.text('100 g'), findsOneWidget);
  });

  testWidgets(
    'review does not write; confirm stores all items and reloads history',
    (tester) async {
      final requests = <http.Request>[];
      Map<String, dynamic>? savedRecord;
      final client = foodClient((request) async {
        requests.add(request);
        expect(request.headers['Authorization'], 'Token example-token');
        if (request.method == 'POST') {
          final data = jsonDecode(request.body) as Map<String, dynamic>;
          expect(data['items'], [
            {'name': 'Porridge', 'quantity': '100', 'unit': 'g'},
            {'name': 'Milk', 'quantity': null, 'unit': ''},
          ]);
          savedRecord = {...data, 'id': 7};
          return http.Response(jsonEncode(savedRecord), 201);
        }
        return http.Response(jsonEncode([savedRecord!]), 200);
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
        expect(find.text('1 record'), findsOneWidget);
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
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const MaterialApp(home: FoodEditor()));
      await tester.enterText(find.byKey(const Key('food-name-0')), 'Rice');
      await tapVisible(tester, find.byKey(const Key('meal-type')));
      final wheel = tester.widget<CupertinoPicker>(
        find.byKey(const Key('meal-picker')),
      );
      wheel.scrollController!.jumpToItem(1);
      await tester.pumpAndSettle();
      await tapVisible(tester, find.byKey(const Key('picker-cancel')));
      expect(find.text('Choose a meal'), findsOneWidget);
      expect(find.text('Rice'), findsOneWidget);
      await tapVisible(tester, find.byKey(const Key('meal-type')));
      tester
          .widget<CupertinoPicker>(find.byKey(const Key('meal-picker')))
          .scrollController!
          .jumpToItem(2);
      await tester.pumpAndSettle();
      await tapVisible(tester, find.byKey(const Key('picker-done')));
      expect(find.text('Morning snack (Elevenses)'), findsOneWidget);
      expect(find.text('Rice'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('iOS date wheel cancels and commits while preserving the time', (
    tester,
  ) async {
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
    expect(find.text('10 October'), findsOneWidget);
    await tapVisible(tester, find.byKey(const Key('food-date')));
    tester
        .widget<CupertinoDatePicker>(find.byKey(const Key('date-picker')))
        .onDateTimeChanged(DateTime(2026, 10, 11));
    await tapVisible(tester, find.byKey(const Key('picker-done')));
    expect(find.text('11 October'), findsOneWidget);
    expect(find.byKey(const Key('food-time')), findsOneWidget);
    expect(find.text('09:30'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'selected time survives cancellation, date changes, creation and editing',
    (tester) async {
      final methods = <String>[];
      Map<String, dynamic>? record;
      var expectedTime = DateTime(2026, 10, 31, 12, 45);
      final client = foodClient((request) async {
        methods.add(request.method);
        if (request.method == 'POST' || request.method == 'PUT') {
          final data = jsonDecode(request.body) as Map<String, dynamic>;
          expect(data['eaten_at'], expectedTime.toUtc().toIso8601String());
          expect(data['time_specified'], true);
          expect(data['items'], [
            {'name': 'Rice', 'quantity': null, 'unit': ''},
          ]);
          record = {...data, 'id': 7};
          return http.Response(
            jsonEncode(record),
            request.method == 'POST' ? 201 : 200,
          );
        }
        return http.Response(jsonEncode([record!]), 200);
      });
      await http.runWithClient(() async {
        await tester.pumpWidget(
          const MaterialApp(home: FoodPage(service: FoodService('token'))),
        );
        await tapVisible(tester, find.byKey(const Key('add-manually')));
        await chooseMeal(tester);
        await tester.enterText(find.byKey(const Key('food-name-0')), 'Rice');
        await tapVisible(tester, find.byKey(const Key('food-date')));
        tester
            .widget<CupertinoDatePicker>(find.byKey(const Key('date-picker')))
            .onDateTimeChanged(DateTime(2026, 10, 30));
        await tapVisible(tester, find.byKey(const Key('picker-done')));

        await tapVisible(tester, find.byKey(const Key('food-time')));
        var picker = tester.widget<CupertinoDatePicker>(
          find.byKey(const Key('time-picker')),
        );
        final originalTime = picker.initialDateTime;
        expect(picker.mode, CupertinoDatePickerMode.time);
        expect(picker.use24hFormat, isTrue);
        picker.onDateTimeChanged(expectedTime);
        await tapVisible(tester, find.byKey(const Key('picker-cancel')));
        await tapVisible(tester, find.byKey(const Key('food-time')));
        picker = tester.widget<CupertinoDatePicker>(
          find.byKey(const Key('time-picker')),
        );
        expect(picker.initialDateTime, originalTime);
        picker.onDateTimeChanged(expectedTime);
        await tapVisible(tester, find.byKey(const Key('picker-done')));
        expect(find.text('30 October'), findsOneWidget);
        expect(find.text('12:45'), findsOneWidget);

        await tapVisible(tester, find.byKey(const Key('food-date')));
        tester
            .widget<CupertinoDatePicker>(find.byKey(const Key('date-picker')))
            .onDateTimeChanged(expectedTime);
        await tapVisible(tester, find.byKey(const Key('picker-done')));
        expect(find.text('12:45'), findsOneWidget);
        await tapVisible(tester, find.byKey(const Key('review-record')));
        expect(find.text('31 Oct 2026 · 12:45'), findsOneWidget);
        expect(methods, isEmpty);
        await tapVisible(tester, find.byKey(const Key('confirm-record')));
        await tapVisible(tester, find.text('View history'));
        expect(find.text('31 October · 12:45'), findsOneWidget);
        expect(find.textContaining('Time not specified'), findsNothing);

        await tapVisible(tester, find.text('Edit'));
        expect(find.text('12:45'), findsOneWidget);
        await tapVisible(tester, find.byKey(const Key('food-time')));
        picker = tester.widget<CupertinoDatePicker>(
          find.byKey(const Key('time-picker')),
        );
        expect(picker.initialDateTime, expectedTime);
        expectedTime = DateTime(2026, 10, 31, 13, 15);
        picker.onDateTimeChanged(expectedTime);
        await tapVisible(tester, find.byKey(const Key('picker-done')));
        await tapVisible(tester, find.byKey(const Key('review-record')));
        expect(find.text('31 October · 13:15'), findsOneWidget);
        expect(methods, ['POST', 'GET', 'PUT', 'GET']);
        expect(tester.takeException(), isNull);
      }, () => client);
      client.close();
    },
  );

  testWidgets('optional time can be cancelled, chosen, cleared and saved', (
    tester,
  ) async {
    Map<String, dynamic>? saved;
    final client = foodClient((request) async {
      if (request.method == 'POST') {
        saved = {...jsonDecode(request.body) as Map<String, dynamic>, 'id': 7};
        expect(saved!['time_specified'], false);
        expect(DateTime.parse(saved!['eaten_at'] as String).toLocal().hour, 0);
        return http.Response(jsonEncode(saved), 201);
      }
      return http.Response(jsonEncode([saved!]), 200);
    });
    await http.runWithClient(() async {
      await tester.pumpWidget(
        const MaterialApp(home: FoodPage(service: FoodService('token'))),
      );
      await tapVisible(tester, find.byKey(const Key('add-manually')));
      await chooseMeal(tester);
      await tester.enterText(find.byKey(const Key('food-name-0')), 'Banana');
      expect(find.text('Time not specified'), findsOneWidget);
      await tapVisible(tester, find.byKey(const Key('food-time')));
      tester
          .widget<CupertinoDatePicker>(find.byKey(const Key('time-picker')))
          .onDateTimeChanged(DateTime(2026, 10, 31, 10));
      await tapVisible(tester, find.byKey(const Key('picker-cancel')));
      expect(find.text('Time not specified'), findsOneWidget);
      await tapVisible(tester, find.byKey(const Key('food-time')));
      tester
          .widget<CupertinoDatePicker>(find.byKey(const Key('time-picker')))
          .onDateTimeChanged(DateTime(2026, 10, 31, 10));
      await tapVisible(tester, find.byKey(const Key('picker-done')));
      expect(find.text('10:00'), findsOneWidget);
      await tapVisible(tester, find.byKey(const Key('clear-food-time')));
      expect(find.text('Time not specified'), findsOneWidget);
      await tapVisible(tester, find.byKey(const Key('review-record')));
      expect(find.textContaining('Time not specified'), findsOneWidget);
      await tapVisible(tester, find.text('Edit'));
      expect(find.text('Time not specified'), findsOneWidget);
      await tapVisible(tester, find.byKey(const Key('review-record')));
      await tapVisible(tester, find.byKey(const Key('confirm-record')));
      await tapVisible(tester, find.text('View history'));
      expect(find.textContaining('Time not specified'), findsOneWidget);
      await tapVisible(tester, find.text('Edit'));
      expect(find.text('Time not specified'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }, () => client);
    client.close();
  });

  testWidgets('history inserts timed snacks and reorders them after editing', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(402, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    Map<String, dynamic> meal(
      int id,
      String type,
      int hour,
      String name, [
      bool time = true,
    ]) => {
      'id': id,
      'meal_type': type,
      'eaten_at': DateTime(2026, 10, 31, hour).toUtc().toIso8601String(),
      'time_specified': time,
      'items': [
        {'name': name, 'quantity': null, 'unit': ''},
      ],
    };
    final records = [
      meal(1, 'dinner', 19, 'Evening meal'),
      meal(2, 'snack', 0, 'Untimed snack', false),
      meal(3, 'lunch', 12, 'Midday meal'),
      meal(4, 'snack', 10, 'Timed snack'),
      meal(5, 'breakfast', 8, 'Morning meal'),
    ];
    final client = foodClient((request) async {
      if (request.method == 'PUT') {
        records[3] = {
          ...jsonDecode(request.body) as Map<String, dynamic>,
          'id': 4,
        };
        return http.Response(jsonEncode(records[3]), 200);
      }
      return http.Response(jsonEncode(records), 200);
    });
    void expectOrder(List<String> names) {
      final positions = names
          .map((name) => tester.getTopLeft(find.text(name)).dy)
          .toList();
      for (var i = 1; i < positions.length; i++) {
        expect(positions[i], greaterThan(positions[i - 1]));
      }
    }

    await http.runWithClient(() async {
      await tester.pumpWidget(
        MaterialApp(
          home: FoodHistoryPage(
            service: const FoodService('token'),
            initialDate: DateTime(2026, 10, 31),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expectOrder([
        'Morning meal',
        'Timed snack',
        'Midday meal',
        'Evening meal',
        'Untimed snack',
      ]);
      await tapVisible(tester, find.text('Edit').at(1));
      expect(find.text('10:00'), findsOneWidget);
      await tapVisible(tester, find.byKey(const Key('food-time')));
      tester
          .widget<CupertinoDatePicker>(find.byKey(const Key('time-picker')))
          .onDateTimeChanged(DateTime(2026, 10, 31, 15));
      await tapVisible(tester, find.byKey(const Key('picker-done')));
      await tapVisible(tester, find.byKey(const Key('review-record')));
      expectOrder([
        'Morning meal',
        'Midday meal',
        'Timed snack',
        'Evening meal',
        'Untimed snack',
      ]);
      expect(tester.takeException(), isNull);
    }, () => client);
    client.close();
  });

  testWidgets(
    'history keeps each food beside its own amount on a small screen',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const longName = 'Blueberries with banana and unsweetened yoghurt';
      final client = foodClient(
        (_) async => http.Response(
          jsonEncode([
            {
              ...stored,
              'items': [
                {'name': 'Blueberry', 'quantity': '1.00', 'unit': 'bowl'},
                {'name': 'Banana', 'quantity': '2.00', 'unit': 'item'},
                {'name': longName, 'quantity': null, 'unit': ''},
              ],
            },
          ]),
          200,
        ),
      );
      await http.runWithClient(() async {
        await tester.pumpWidget(
          MaterialApp(
            home: FoodHistoryPage(
              service: const FoodService('token'),
              initialDate: DateTime(2026, 10, 31),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final blueberry = tester.getTopLeft(find.text('Blueberry'));
        final bowl = tester.getTopRight(find.text('1 bowl'));
        final banana = tester.getTopLeft(find.text('Banana'));
        final count = tester.getTopRight(find.text('2 item'));
        expect(blueberry.dy, bowl.dy);
        expect(banana.dy, count.dy);
        expect(banana.dy, greaterThan(blueberry.dy));
        expect(bowl.dx, count.dx);
        expect(
          tester.getTopLeft(find.text('1 bowl')).dx,
          greaterThan(blueberry.dx),
        );
        expect(find.text(longName), findsOneWidget);
        expect(find.text('Amount not provided'), findsOneWidget);
        expect(find.text('Blueberry · Banana'), findsNothing);
        expect(find.text('31 October · 09:30'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }, () => client);
      client.close();
    },
  );

  testWidgets('failed save preserves draft and supports retry', (tester) async {
    var calls = 0;
    final client = foodClient((request) async {
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
    'manual form validates the meal, food and combined amount on a small screen',
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
      expect(find.text('Choose a meal.'), findsOneWidget);
      await chooseMeal(tester);
      await tester.enterText(find.byKey(const Key('food-name-0')), 'Rice');
      await tester.enterText(find.byKey(const Key('food-amount-0')), '-1');
      await tapVisible(tester, find.byKey(const Key('review-record')));
      expect(
        find.text('Enter a positive number, e.g. 1 or 0.5.'),
        findsOneWidget,
      );
      await tester.enterText(find.byKey(const Key('food-amount-0')), '');
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
    await chooseMeal(tester);
    await tester.enterText(find.byKey(const Key('food-name-0')), 'Rice');
    tester.view.viewInsets = const FakeViewPadding(bottom: 240);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('food-amount-0')), '100');
    await chooseUnit(tester, 0, 5);
    await tapVisible(tester, find.text('Done'));
    tester.view.resetViewInsets();
    await tester.pumpAndSettle();
    await tapVisible(tester, find.byKey(const Key('review-record')));
    expect(find.text('100 g'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('history edit updates original record and refreshes', (
    tester,
  ) async {
    final methods = <String>[];
    Map<String, dynamic> record = Map.of(stored);
    final client = foodClient((request) async {
      methods.add(request.method);
      if (request.method == 'PUT') {
        expect(request.url.path, '/api/food-records/7/');
        record = {...jsonDecode(request.body) as Map<String, dynamic>, 'id': 7};
        expect(record['meal_type'], 'afternoon_tea');
        return http.Response(jsonEncode(record), 200);
      }
      return http.Response(jsonEncode([record]), 200);
    });
    await http.runWithClient(() async {
      await tester.pumpWidget(
        MaterialApp(
          home: FoodHistoryPage(
            service: const FoodService('token'),
            initialDate: DateTime(2026, 10, 31),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('Edit'));
      await tester.enterText(find.byKey(const Key('food-name-0')), 'Oats');
      await tapVisible(tester, find.byKey(const Key('meal-type')));
      tester
          .widget<CupertinoPicker>(find.byKey(const Key('meal-picker')))
          .scrollController!
          .jumpToItem(4);
      await tapVisible(tester, find.byKey(const Key('picker-done')));
      await tapVisible(tester, find.byKey(const Key('review-record')));
      expect(find.text('Oats'), findsOneWidget);
      expect(find.text('Afternoon tea'), findsOneWidget);
      expect(methods, ['GET', 'PUT', 'GET']);
      expect(tester.takeException(), isNull);
    }, () => client);
    client.close();
  });

  testWidgets(
    'edit save waits for the API and keeps every amount after failure',
    (tester) async {
      final pending = Completer<http.Response>();
      var saves = 0;
      Map<String, dynamic> record = Map.of(stored);
      final client = foodClient((request) async {
        if (request.method == 'PUT') {
          saves++;
          final data = jsonDecode(request.body) as Map<String, dynamic>;
          expect(data['items'], [
            {'name': 'Oats', 'quantity': '100', 'unit': 'g'},
            {'name': 'Milk', 'quantity': null, 'unit': ''},
          ]);
          if (saves == 1) return pending.future;
          record = {...data, 'id': 7};
          return http.Response(jsonEncode(record), 200);
        }
        return http.Response(jsonEncode([record]), 200);
      });
      await http.runWithClient(() async {
        await tester.pumpWidget(
          MaterialApp(
            home: FoodHistoryPage(
              service: const FoodService('token'),
              initialDate: DateTime(2026, 10, 31),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tapVisible(tester, find.text('Edit'));
        await tester.enterText(find.byKey(const Key('food-name-0')), 'Oats');
        await tester.ensureVisible(find.byKey(const Key('review-record')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('review-record')));
        await tester.pump(const Duration(milliseconds: 100));
        expect(saves, 1);
        expect(
          tester
              .widget<CupertinoButton>(find.byKey(const Key('review-record')))
              .onPressed,
          isNull,
        );
        expect(
          tester
              .widget<CupertinoButton>(find.byKey(const Key('page-back')))
              .onPressed,
          isNull,
        );
        pending.complete(http.Response('unavailable', 503));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('edit-save-error')), findsOneWidget);
        expect(find.text('100'), findsOneWidget);
        expect(find.text('Oats'), findsOneWidget);
        await tapVisible(tester, find.byKey(const Key('review-record')));
        expect(find.byType(FoodEditor), findsNothing);
        expect(find.text('Oats'), findsOneWidget);
        expect(saves, 2);
      }, () => client);
      client.close();
    },
  );

  testWidgets('delete requires confirmation and waits for API success', (
    tester,
  ) async {
    var deletes = 0;
    final client = foodClient((request) async {
      if (request.method == 'DELETE') {
        deletes++;
        return http.Response('', 204);
      }
      return http.Response(jsonEncode([stored]), 200);
    });
    await http.runWithClient(() async {
      await tester.pumpWidget(
        MaterialApp(
          home: FoodHistoryPage(
            service: const FoodService('token'),
            initialDate: DateTime(2026, 10, 31),
          ),
        ),
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
      expect(find.text('No records for this day.'), findsOneWidget);
    }, () => client);
    client.close();
  });

  testWidgets(
    'history filters dates and types and opens Add record on a small screen',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final client = foodClient(
        (_) async => http.Response(
          jsonEncode([
            stored,
            {
              ...stored,
              'id': 8,
              'eaten_at': '2026-10-30T09:30:00Z',
              'items': [
                {'name': 'Toast', 'quantity': '2', 'unit': 'slice'},
              ],
            },
          ]),
          200,
        ),
      );
      await http.runWithClient(() async {
        await tester.pumpWidget(
          MaterialApp(
            home: FoodHistoryPage(
              service: const FoodService('token'),
              initialDate: DateTime(2026, 10, 31),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('History'), findsOneWidget);
        expect(find.text('1 record'), findsOneWidget);
        expect(find.text('Porridge'), findsOneWidget);
        expect(find.text('Toast'), findsNothing);
        await tapVisible(
          tester,
          find.byKey(const Key('history-filter-activity')),
        );
        expect(find.text('0 records'), findsOneWidget);
        expect(find.text('No activity records yet.'), findsOneWidget);
        await tapVisible(tester, find.byKey(const Key('history-filter-food')));
        await tapVisible(tester, find.byKey(const Key('history-previous-day')));
        expect(find.text('Toast'), findsOneWidget);
        expect(find.text('Porridge'), findsNothing);
        await tapVisible(tester, find.byKey(const Key('history-next-day')));
        expect(find.text('Porridge'), findsOneWidget);
        await tapVisible(tester, find.byKey(const Key('history-next-day')));
        expect(find.text('0 records'), findsOneWidget);
        expect(find.text('No food records for this day.'), findsOneWidget);
        await tapVisible(tester, find.byKey(const Key('history-add-record')));
        expect(find.byType(FoodPage), findsOneWidget);
        expect(find.text('Add record'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }, () => client);
      client.close();
    },
  );

  testWidgets('history back returns to Add record and preserves its draft', (
    tester,
  ) async {
    final methods = <String>[];
    final client = foodClient((request) async {
      methods.add(request.method);
      return http.Response(jsonEncode([stored]), 200);
    });
    await http.runWithClient(() async {
      await tester.pumpWidget(
        const MaterialApp(home: FoodPage(service: FoodService('token'))),
      );
      await enterDraft(tester);
      for (var visit = 0; visit < 2; visit++) {
        await tapVisible(tester, find.text('History'));
        expect(find.byType(FoodHistoryPage), findsOneWidget);
        await tapVisible(tester, find.byKey(const Key('page-back')));
        expect(find.byType(FoodHistoryPage), findsNothing);
        expect(find.byType(FoodPage), findsOneWidget);
        expect(find.text('Add record'), findsOneWidget);
        expect(find.text('Porridge'), findsOneWidget);
        expect(find.text('100 g'), findsOneWidget);
      }
      expect(methods, ['GET', 'GET']);
      expect(tester.takeException(), isNull);
    }, () => client);
    client.close();
  });

  testWidgets(
    'manual form has no History shortcut and back returns to Add record',
    (tester) async {
      final client = foodClient((_) async => http.Response('[]', 200));
      await http.runWithClient(() async {
        await tester.pumpWidget(
          const MaterialApp(home: FoodPage(service: FoodService('token'))),
        );
        await tapVisible(tester, find.byKey(const Key('add-manually')));
        expect(find.text('History'), findsNothing);
        expect(find.byType(FoodHistoryPage), findsNothing);
        await tapVisible(tester, find.byKey(const Key('page-back')));
        expect(find.byType(FoodHistoryPage), findsNothing);
        expect(find.byType(FoodEditor), findsNothing);
        expect(find.byType(FoodPage), findsOneWidget);
        expect(find.text('Add record'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }, () => client);
      client.close();
    },
  );

  testWidgets('standalone history back opens Add record', (tester) async {
    final client = foodClient((_) async => http.Response('[]', 200));
    await http.runWithClient(() async {
      await tester.pumpWidget(
        const MaterialApp(home: FoodHistoryPage(service: FoodService('token'))),
      );
      await tester.pumpAndSettle();
      await tapVisible(tester, find.byKey(const Key('page-back')));
      expect(find.byType(FoodHistoryPage), findsNothing);
      expect(find.byType(FoodPage), findsOneWidget);
      expect(find.text('Add record'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }, () => client);
    client.close();
  });

  testWidgets('history failure offers retry without claiming diary is empty', (
    tester,
  ) async {
    final client = foodClient((_) async => http.Response('offline', 503));
    await http.runWithClient(() async {
      await tester.pumpWidget(
        MaterialApp(
          home: FoodHistoryPage(
            service: const FoodService('token'),
            initialDate: DateTime(2026, 10, 31),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('history-error')), findsOneWidget);
      expect(find.text('No food records for this day.'), findsNothing);
      expect(find.text('Try again'), findsOneWidget);
    }, () => client);
    client.close();
  });
}
