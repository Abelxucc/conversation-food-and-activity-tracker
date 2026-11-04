import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tracktalk/auth/LoginPage.dart';
import 'package:tracktalk/app_shell.dart';
import 'package:tracktalk/shared/food_chrome.dart';
import 'package:tracktalk/food/food_editor.dart';
import 'package:tracktalk/history/food_history_page.dart';
import 'package:tracktalk/food/food_page.dart';
import 'package:tracktalk/food/food_service.dart';

Future<void> tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> openMe(WidgetTester tester) =>
    tap(tester, find.byKey(const Key('nav-me')));

void phone(WidgetTester tester, {Size size = const Size(390, 844)}) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

const app = MaterialApp(home: AppShell(service: FoodService('test-token')));

void main() {
  testWidgets('Food uses meal rows and a separate weekly recommendation card', (
    tester,
  ) async {
    phone(tester);
    final client = MockClient((request) async {
      if (request.url.path == '/api/food-recommendations/') {
        expect(request.headers['authorization'], 'Token test-token');
        return http.Response(
          jsonEncode({
            'week_start': '2026-11-02',
            'week_end': '2026-11-08',
            'days_logged': 1,
            'groups': [
              {
                'label': 'Protein foods',
                'foods': ['Chicken'],
              },
            ],
            'recommendation': {
              'title': 'No pulses logged this week',
              'body': 'Try lentils in soup.',
              'source_url': 'https://www.nhs.uk/',
            },
          }),
          200,
        );
      }
      if (request.url.path == '/api/food-records/') {
        final now = DateTime.now();
        return http.Response(
          jsonEncode([
            for (final (id, type, hour, name) in [
              (1, 'breakfast', 8, 'Porridge'),
              (2, 'lunch', 12, 'Chicken sandwich'),
              (3, 'snack', 15, 'Yoghurt'),
            ])
              {
                'id': id,
                'meal_type': type,
                'eaten_at': DateTime(
                  now.year,
                  now.month,
                  now.day,
                  hour,
                ).toIso8601String(),
                'items': [
                  {'name': name, 'quantity': null, 'unit': ''},
                ],
              },
          ]),
          200,
        );
      }
      return http.Response('[]', 200);
    });
    await http.runWithClient(() async {
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();
      expect(find.text('Try lentils in soup.'), findsOneWidget);
      await tap(tester, find.byKey(const Key('nav-food')));
      expect(find.text('Your food diary'), findsOneWidget);
      expect(find.text('3 food records'), findsOneWidget);
      expect(find.text('2 meals · 1 snack'), findsOneWidget);
      expect(find.text('Meals & snacks'), findsOneWidget);
      expect(find.text('Porridge'), findsOneWidget);
      expect(find.text('Chicken sandwich'), findsOneWidget);
      expect(find.text('Yoghurt'), findsOneWidget);
      expect(find.text('Food allergies'), findsOneWidget);
      expect(find.byType(PageView), findsNothing);
      expect(find.text('Try lentils in soup.'), findsNothing);
      await tap(tester, find.text('View this week'));
      expect(find.text('Chicken'), findsOneWidget);
      expect(find.text('Pulses'), findsOneWidget);
      expect(find.text('Not logged'), findsOneWidget);
      expect(find.text('Try lentils in soup.'), findsOneWidget);
    }, () => client);
  });

  testWidgets(
    'Me has placeholder cards and selection animates across the bar',
    (tester) async {
      phone(tester);
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();
      expect(find.byType(FoodNavigation), findsOneWidget);
      final start = tester.getCenter(find.byKey(const Key('nav-selection'))).dx;
      await tester.tap(find.byKey(const Key('nav-me')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final middle = tester
          .getCenter(find.byKey(const Key('nav-selection')))
          .dx;
      final end = tester.getCenter(find.byKey(const Key('nav-me'))).dx;
      expect(middle, greaterThan(start));
      expect(middle, lessThan(end));
      await tester.pumpAndSettle();
      expect(
        tester.getCenter(find.byKey(const Key('nav-selection'))).dx,
        closeTo(end, .1),
      );
      expect(find.text('Edit my profile'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('About us'), findsOneWidget);
      expect(find.text('Coming soon'), findsNWidgets(3));
      expect(find.text('Sign out'), findsOneWidget);
      await tester.tap(find.text('Edit my profile'));
      await tester.pumpAndSettle();
      expect(find.text('Coming soon'), findsNWidgets(3));
      await tap(tester, find.byKey(const Key('nav-home')));
      expect(find.text('Today'), findsOneWidget);
      await tap(tester, find.byKey(const Key('nav-food')));
      expect(find.text('This week'), findsOneWidget);
      await tap(tester, find.byKey(const Key('nav-activity')));
      expect(find.text('Coming soon'), findsOneWidget);
      await tap(tester, find.byKey(const Key('nav-add')));
      expect(find.text('Add record'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('switching to Me preserves manual input and the review draft', (
    tester,
  ) async {
    phone(tester);
    await tester.pumpWidget(app);
    await tap(tester, find.byKey(const Key('nav-add')));
    await tap(tester, find.byKey(const Key('add-manually')));
    await tester.enterText(find.byKey(const Key('food-name-0')), 'Porridge');
    await tester.enterText(find.byKey(const Key('food-amount-0')), '1');
    await tap(tester, find.byKey(const Key('meal-type')));
    await tap(tester, find.byKey(const Key('picker-done')));
    await openMe(tester);
    expect(find.text('Sign out'), findsOneWidget);
    await tap(tester, find.byKey(const Key('nav-add')));
    expect(find.byType(FoodEditor), findsOneWidget);
    expect(find.text('Porridge'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    await tap(tester, find.byKey(const Key('review-record')));
    await openMe(tester);
    await tap(tester, find.byKey(const Key('nav-add')));
    expect(find.byKey(const Key('confirm-record')), findsOneWidget);
    expect(find.text('Porridge'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'History keeps its filters across tabs and system back returns to Add record',
    (tester) async {
      phone(tester);
      final client = MockClient((_) async => http.Response('[]', 200));
      await http.runWithClient(() async {
        await tester.pumpWidget(app);
        await tap(tester, find.byKey(const Key('nav-add')));
        await tap(tester, find.text('History'));
        await tap(tester, find.byKey(const Key('history-filter-activity')));
        await openMe(tester);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.byType(FoodHistoryPage), findsOneWidget);
        expect(find.text('No activity records yet.'), findsOneWidget);
        expect(find.byType(FoodNavigation), findsOneWidget);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.byType(FoodHistoryPage), findsNothing);
        expect(find.text('Add record'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }, () => client);
      client.close();
    },
  );

  testWidgets(
    'sign out waits once, clears every authenticated route and cannot go back',
    (tester) async {
      phone(tester);
      final response = Completer<http.Response>();
      var calls = 0;
      final client = MockClient((request) {
        calls++;
        expect(request.method, 'POST');
        expect(request.url.path, '/api/auth/logout/');
        expect(request.headers['Authorization'], 'Token test-token');
        return response.future;
      });
      await http.runWithClient(() async {
        await tester.pumpWidget(app);
        await tap(tester, find.byKey(const Key('nav-add')));
        await tap(tester, find.text('History'));
      }, () => MockClient((_) async => http.Response('[]', 200)));
      await http.runWithClient(() async {
        await openMe(tester);
        await tester.tap(find.byKey(const Key('sign-out')));
        await tester.pump(const Duration(milliseconds: 50));
        await tester.tap(find.byKey(const Key('sign-out')));
        expect(calls, 1);
        final navigation = tester.widget<FoodNavigation>(
          find.byType(FoodNavigation),
        );
        expect(navigation.onSelected, isNull);
        await tester.binding.handlePopRoute();
        await tester.pump(const Duration(milliseconds: 50));
        expect(find.text('Sign out'), findsOneWidget);
        response.complete(http.Response('', 204));
        await tester.pumpAndSettle();
        expect(find.byType(LoginPage), findsOneWidget);
        expect(find.byType(AppShell), findsNothing);
        expect(find.byType(FoodPage), findsNothing);
        expect(find.byType(FoodHistoryPage), findsNothing);
        expect(
          tester
              .widget<TextFormField>(find.byKey(const Key('login-password')))
              .controller!
              .text,
          isEmpty,
        );
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.byType(LoginPage), findsOneWidget);
        expect(find.byType(FoodNavigation), findsNothing);
        expect(tester.takeException(), isNull);
      }, () => client);
      client.close();
    },
  );

  testWidgets('failed sign out preserves the session and retry works', (
    tester,
  ) async {
    phone(tester);
    var calls = 0;
    final client = MockClient((request) async {
      if (request.method == 'GET') return http.Response('', 503);
      return http.Response('', ++calls == 1 ? 503 : 204);
    });
    await http.runWithClient(() async {
      await tester.pumpWidget(app);
      await openMe(tester);
      await tap(tester, find.byKey(const Key('sign-out')));
      expect(find.byKey(const Key('sign-out-error')), findsOneWidget);
      expect(find.byType(AppShell), findsOneWidget);
      await tap(tester, find.byKey(const Key('nav-add')));
      expect(find.text('Add record'), findsOneWidget);
      await openMe(tester);
      await tap(tester, find.byKey(const Key('sign-out')));
      expect(calls, 2);
      expect(find.byType(LoginPage), findsOneWidget);
      expect(tester.takeException(), isNull);
    }, () => client);
    client.close();
  });

  testWidgets('an already expired token can still sign out', (tester) async {
    phone(tester);
    final client = MockClient((_) async => http.Response('', 401));
    await http.runWithClient(() async {
      await tester.pumpWidget(app);
      await openMe(tester);
      await tap(tester, find.byKey(const Key('sign-out')));
      expect(find.byType(LoginPage), findsOneWidget);
      expect(tester.takeException(), isNull);
    }, () => client);
    client.close();
  });

  testWidgets(
    'pending food saves prevent tab switching until the write finishes',
    (tester) async {
      phone(tester);
      final response = Completer<http.Response>();
      Map<String, dynamic>? draft;
      final client = MockClient((request) async {
        if (request.method == 'GET') return http.Response('', 503);
        draft = jsonDecode(request.body) as Map<String, dynamic>;
        return response.future;
      });
      await http.runWithClient(() async {
        await tester.pumpWidget(app);
        await tap(tester, find.byKey(const Key('nav-add')));
        await tap(tester, find.byKey(const Key('add-manually')));
        await tester.enterText(
          find.byKey(const Key('food-name-0')),
          'Porridge',
        );
        await tap(tester, find.byKey(const Key('meal-type')));
        await tap(tester, find.byKey(const Key('picker-done')));
        await tap(tester, find.byKey(const Key('review-record')));
        await tester.tap(find.byKey(const Key('confirm-record')));
        await tester.pump(const Duration(milliseconds: 50));
        expect(
          tester.widget<FoodNavigation>(find.byType(FoodNavigation)).onSelected,
          isNull,
        );
        await tester.tap(find.byKey(const Key('nav-me')));
        await tester.pump(const Duration(milliseconds: 50));
        expect(find.text('Sign out'), findsNothing);
        response.complete(http.Response(jsonEncode({...draft!, 'id': 7}), 201));
        await tester.pumpAndSettle();
        await openMe(tester);
        expect(find.text('Sign out'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }, () => client);
      client.close();
    },
  );

  testWidgets(
    'Me fits a small screen and reduced motion skips the selection animation',
    (tester) async {
      phone(tester, size: const Size(320, 568));
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: const AppShell(service: FoodService('test-token')),
        ),
      );
      await tester.tap(find.byKey(const Key('nav-me')));
      await tester.pump();
      expect(
        tester.getCenter(find.byKey(const Key('nav-selection'))).dx,
        closeTo(tester.getCenter(find.byKey(const Key('nav-me'))).dx, .1),
      );
      await tester.ensureVisible(find.byKey(const Key('sign-out')));
      expect(find.text('Sign out'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
