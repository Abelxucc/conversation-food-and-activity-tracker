import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tracktalk/main.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tracktalk/food/food_page.dart';
import 'package:tracktalk/shared/food_chrome.dart';

MockClient _loginClient() => MockClient((request) async {
  switch (request.url.path) {
    case '/api/auth/login/':
      expect(request.method, 'POST');
      return http.Response('{"token":"test-token"}', 200);
    case '/api/food-records/':
    case '/api/activity-records/':
      return http.Response('[]', 200);
    case '/api/food-recommendations/':
      return http.Response(
        '{"week_start":"2026-11-02","week_end":"2026-11-08",'
        '"days_logged":0,"groups":[],"recommendation":null}',
        200,
      );
    default:
      fail('Unexpected request: ${request.url.path}');
  }
});

void main() {
  testWidgets('validates credentials and opens Home after sign-in', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final client = _loginClient();
    await http.runWithClient(() async {
      await tester.pumpWidget(const TrackTalkApp());
      await tester.ensureVisible(find.text('Log in'));
      await tester.tap(find.text('Log in'));
      await tester.pumpAndSettle();
      expect(find.text('Enter your email address.'), findsOneWidget);
      expect(find.text('Enter your password.'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('login-email')), 'bad-email');
      await tester.enterText(
        find.byKey(const Key('login-password')),
        'example-password',
      );
      await tester.ensureVisible(find.text('Log in'));
      await tester.tap(find.text('Log in'));
      await tester.pumpAndSettle();
      expect(find.text('Enter a valid email address.'), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('login-email')),
        'person@example.com',
      );
      await tester.ensureVisible(find.text('Log in'));
      await tester.tap(find.text('Log in'));
      await tester.pumpAndSettle();
      expect(find.text('Today'), findsOneWidget);
      expect(
        tester
            .widget<FoodNavigation>(find.byType(FoodNavigation))
            .selectedDestination,
        FoodDestination.home,
      );
      expect(find.byType(FoodPage), findsNothing);
      expect(tester.takeException(), isNull);
    }, () => client);
    client.close();
  });

  testWidgets(
    'Add record hides back and system back keeps the user signed in',
    (tester) async {
      final client = _loginClient();
      await http.runWithClient(() async {
        await tester.pumpWidget(const TrackTalkApp());
        expect(find.byKey(const Key('page-back')), findsNothing);
        await tester.enterText(
          find.byKey(const Key('login-email')),
          'person@example.com',
        );
        await tester.enterText(
          find.byKey(const Key('login-password')),
          'example-password',
        );
        await tester.ensureVisible(find.text('Log in'));
        await tester.tap(find.text('Log in'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('nav-add')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('page-back')), findsNothing);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.byType(FoodPage), findsOneWidget);
        expect(find.text('Welcome back'), findsNothing);
        expect(
          tester
              .widget<TextFormField>(
                find.byKey(const Key('login-email'), skipOffstage: false),
              )
              .controller!
              .text,
          'person@example.com',
        );
        expect(
          tester
              .widget<TextFormField>(
                find.byKey(const Key('login-password'), skipOffstage: false),
              )
              .controller!
              .text,
          isEmpty,
        );
      }, () => client);
      client.close();
    },
  );

  testWidgets('registration back returns to the same login draft', (
    tester,
  ) async {
    await tester.pumpWidget(const TrackTalkApp());
    await tester.enterText(
      find.byKey(const Key('login-email')),
      'person@example.com',
    );
    await tester.ensureVisible(find.text('Sign up here!'));
    await tester.tap(find.text('Sign up here!'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('page-back')));
    await tester.tap(find.byKey(const Key('page-back')));
    await tester.pumpAndSettle();
    expect(find.text('Welcome back'), findsOneWidget);
    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('login-email')))
          .controller!
          .text,
      'person@example.com',
    );
  });

  testWidgets('password toggle preserves the entered value', (tester) async {
    await tester.pumpWidget(const TrackTalkApp());
    final password = find.byKey(const Key('login-password'));
    await tester.ensureVisible(password);
    await tester.enterText(password, 'my-password');
    expect(
      tester
          .widget<EditableText>(
            find.descendant(of: password, matching: find.byType(EditableText)),
          )
          .obscureText,
      isTrue,
    );
    await tester.tap(find.byTooltip('Show password'));
    await tester.pump();
    final input = tester.widget<EditableText>(
      find.descendant(of: password, matching: find.byType(EditableText)),
    );
    expect(input.obscureText, isFalse);
    expect(input.controller.text, 'my-password');
  });

  testWidgets('small screens and keyboard keep the form scrollable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 260);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpWidget(const TrackTalkApp());
    await tester.ensureVisible(find.text('Sign up here!'));
    await tester.tap(find.text('Sign up here!'));
    await tester.pumpAndSettle();
    expect(find.text('Create an account'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
