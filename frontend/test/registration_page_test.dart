import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tracktalk/main.dart';
import 'package:tracktalk/RegistrationPage.dart';

Future<void> fillForm(
  WidgetTester tester, {
  String confirmation = 'person@example.com',
}) async {
  await tester.enterText(
    find.byKey(const Key('registration-email')),
    'person@example.com',
  );
  await tester.enterText(
    find.byKey(const Key('registration-confirm-email')),
    confirmation,
  );
  await tester.enterText(
    find.byKey(const Key('registration-password')),
    'River-walk-739!',
  );
  await tester.enterText(
    find.byKey(const Key('registration-phone')),
    '+44 7700 900123',
  );
  await tester.ensureVisible(find.text('Create account'));
}

void main() {
  testWidgets(
    'sign up opens the single registration page with email prefilled',
    (tester) async {
      await tester.pumpWidget(const TrackTalkApp());
      await tester.enterText(
        find.byKey(const Key('login-email')),
        'person@example.com',
      );
      await tester.ensureVisible(find.text('Sign up here!'));
      await tester.tap(find.text('Sign up here!'));
      await tester.pumpAndSettle();
      expect(find.byType(RegistrationPage), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('registration-email')))
            .controller!
            .text,
        'person@example.com',
      );
      expect(find.byType(TextFormField), findsNWidgets(4));
      await tester.ensureVisible(find.text('Already have an account? Log in'));
      await tester.tap(find.text('Already have an account? Log in'));
      await tester.pumpAndSettle();
      expect(find.text('Welcome back'), findsOneWidget);
    },
  );

  testWidgets('mismatched emails prevent registration requests', (
    tester,
  ) async {
    var calls = 0;
    final client = MockClient((_) async {
      calls++;
      return http.Response('{}', 201);
    });
    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(home: RegistrationPage()));
      await fillForm(tester, confirmation: 'someone-else@example.com');
      await tester.tap(find.text('Create account'));
      await tester.pumpAndSettle();
      expect(find.text('The email addresses do not match.'), findsOneWidget);
      expect(calls, 0);
    }, () => client);
    client.close();
  });

  testWidgets('requires every account field on a small screen with keyboard', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 260);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpWidget(const MaterialApp(home: RegistrationPage()));
    await tester.ensureVisible(find.text('Create account'));
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();
    expect(find.text('Enter your email address.'), findsOneWidget);
    expect(find.text('Confirm your email address.'), findsOneWidget);
    expect(find.text('Enter a password.'), findsOneWidget);
    expect(find.text('Enter your phone number.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'creates account only after backend confirmation and blocks duplicate submits',
    (tester) async {
      final pending = Completer<http.Response>();
      var calls = 0;
      final client = MockClient((request) {
        calls++;
        expect(request.url.path, '/api/auth/register/');
        expect(jsonDecode(request.body), {
          'email': 'person@example.com',
          'confirm_email': 'person@example.com',
          'password': 'River-walk-739!',
          'phone_number': '+44 7700 900123',
        });
        return pending.future;
      });
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(home: RegistrationPage()));
        await fillForm(tester);
        await tester.tap(find.text('Create account'));
        await tester.pump();
        expect(calls, 1);
        expect(
          tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
          isNull,
        );
        expect(find.text('Account created'), findsNothing);
        pending.complete(http.Response('{"email":"person@example.com"}', 201));
        await tester.pumpAndSettle();
        expect(find.text('Account created'), findsOneWidget);
        expect(find.byType(TextFormField), findsNothing);
      }, () => client);
      client.close();
    },
  );

  testWidgets('duplicate email error keeps details and permits retry', (
    tester,
  ) async {
    final client = MockClient(
      (_) async => http.Response(
        '{"email":["An account with this email address already exists."]}',
        400,
      ),
    );
    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(home: RegistrationPage()));
      await fillForm(tester);
      await tester.tap(find.text('Create account'));
      await tester.pumpAndSettle();
      expect(
        find.text('An account with this email address already exists.'),
        findsOneWidget,
      );
      expect(find.text('Account created'), findsNothing);
      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('registration-email')))
            .controller!
            .text,
        'person@example.com',
      );
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull,
      );
    }, () => client);
    client.close();
  });

  testWidgets('network failure does not show account created', (tester) async {
    final client = MockClient(
      (_) async => throw http.ClientException('offline'),
    );
    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(home: RegistrationPage()));
      await fillForm(tester);
      await tester.tap(find.text('Create account'));
      await tester.pumpAndSettle();
      expect(find.text('Could not connect. Please try again.'), findsOneWidget);
      expect(find.text('Account created'), findsNothing);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull,
      );
    }, () => client);
    client.close();
  });
}
