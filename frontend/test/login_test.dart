import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tracktalk/main.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tracktalk/food_page.dart';

void main() {
  testWidgets('validates credentials and signs in', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final client = MockClient((request) async {
      expect(request.url.path, '/api/auth/login/');
      return http.Response('{"token":"test-token"}', 200);
    });
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
      expect(find.byType(FoodPage), findsOneWidget);
      expect(tester.takeException(), isNull);
    }, () => client);
    client.close();
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
