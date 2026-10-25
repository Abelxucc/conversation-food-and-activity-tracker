import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tracktalk/GenderPage.dart';
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

Future<void> fillProfile(WidgetTester tester) async {
  await tester.ensureVisible(find.byKey(const Key('gender-female')));
  await tester.tap(find.byKey(const Key('gender-female')));
  await tester.ensureVisible(find.byKey(const Key('gender-continue')));
  await tester.tap(find.byKey(const Key('gender-continue')));
  await tester.pumpAndSettle();
  expect(find.text('2 of 4'), findsOneWidget);
  await tester.enterText(find.byKey(const Key('profile-height')), '172.5');
  await tester.ensureVisible(find.byKey(const Key('profile-continue')));
  await tester.tap(find.byKey(const Key('profile-continue')));
  await tester.pumpAndSettle();
  expect(find.text('3 of 4'), findsOneWidget);
  await tester.enterText(find.byKey(const Key('profile-weight')), '68.25');
  await tester.ensureVisible(find.byKey(const Key('profile-continue')));
  await tester.tap(find.byKey(const Key('profile-continue')));
  await tester.pumpAndSettle();
  expect(find.text('4 of 4'), findsOneWidget);
  await tester.enterText(find.byKey(const Key('profile-age')), '24');
  await tester.ensureVisible(find.byKey(const Key('profile-continue')));
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
    'checks account details before profile and submits the complete registration last',
    (tester) async {
      final pending = Completer<http.Response>();
      var calls = 0;
      var checks = 0;
      final client = MockClient((request) {
        if (request.url.path == '/api/auth/register/validate/') {
          checks++;
          expect(jsonDecode(request.body), {
            'email': 'person@example.com',
            'confirm_email': 'person@example.com',
            'password': 'River-walk-739!',
            'phone_number': '+44 7700 900123',
          });
          return Future.value(http.Response('', 204));
        }
        calls++;
        expect(request.url.path, '/api/auth/register/');
        expect(jsonDecode(request.body), {
          'email': 'person@example.com',
          'confirm_email': 'person@example.com',
          'password': 'River-walk-739!',
          'phone_number': '+44 7700 900123',
          'gender': 'female',
          'height_cm': '172.5',
          'weight_kg': '68.25',
          'age': 24,
        });
        return pending.future;
      });
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(home: RegistrationPage()));
        await fillForm(tester);
        await tester.tap(find.text('Create account'));
        await tester.pumpAndSettle();
        expect(find.byType(GenderPage), findsOneWidget);
        expect(checks, 1);
        expect(calls, 0);
        await fillProfile(tester);
        await tester.tap(find.byKey(const Key('profile-continue')));
        await tester.pump();
        expect(calls, 1);
        expect(
          tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
          isNull,
        );
        expect(find.text('Account created'), findsNothing);
        await tester.binding.handlePopRoute();
        await tester.pump();
        expect(find.text('4 of 4'), findsOneWidget);
        pending.complete(http.Response('{"email":"person@example.com"}', 201));
        await tester.pumpAndSettle();
        expect(find.text('Account created'), findsOneWidget);
        expect(find.byType(TextFormField), findsNothing);
        expect(calls, 1);
      }, () => client);
      client.close();
    },
  );

  testWidgets(
    'duplicate email is reported before gender and keeps account fields',
    (tester) async {
      final client = MockClient((request) async {
        expect(request.url.path, '/api/auth/register/validate/');
        return http.Response(
          '{"email":["An account with this email address already exists."]}',
          400,
        );
      });
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
        expect(find.byType(GenderPage), findsNothing);
        expect(
          tester
              .widget<TextFormField>(
                find.byKey(const Key('registration-email')),
              )
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
    },
  );

  testWidgets(
    'network failure keeps the draft and the final Continue can retry',
    (tester) async {
      var calls = 0;
      final client = MockClient((request) async {
        if (request.url.path == '/api/auth/register/validate/') {
          return http.Response('', 204);
        }
        calls++;
        if (calls == 1) throw http.ClientException('offline');
        return http.Response('{}', 201);
      });
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(home: RegistrationPage()));
        await fillForm(tester);
        await tester.tap(find.text('Create account'));
        await tester.pumpAndSettle();
        await fillProfile(tester);
        await tester.tap(find.byKey(const Key('profile-continue')));
        await tester.pumpAndSettle();
        expect(
          find.text('Could not connect. Please try again.'),
          findsOneWidget,
        );
        expect(find.text('Account created'), findsNothing);
        expect(
          tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
          isNotNull,
        );
        await tester.ensureVisible(find.byKey(const Key('profile-continue')));
        await tester.tap(find.byKey(const Key('profile-continue')));
        await tester.pumpAndSettle();
        expect(find.text('Account created'), findsOneWidget);
        expect(calls, 2);
      }, () => client);
      client.close();
    },
  );

  testWidgets('profile steps validate and retain values when going back', (
    tester,
  ) async {
    var calls = 0;
    final client = MockClient((request) async {
      if (request.url.path == '/api/auth/register/validate/') {
        return http.Response('', 204);
      }
      calls++;
      return http.Response('{}', 201);
    });
    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(home: RegistrationPage()));
      await fillForm(tester);
      await tester.tap(find.text('Create account'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('gender-continue')));
      await tester.tap(find.byKey(const Key('gender-continue')));
      await tester.pumpAndSettle();
      expect(find.text('Choose an option to continue.'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('gender-female')));
      await tester.tap(find.byKey(const Key('gender-female')));
      await tester.ensureVisible(find.byKey(const Key('gender-continue')));
      await tester.tap(find.byKey(const Key('gender-continue')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('profile-height')), '0');
      await tester.ensureVisible(find.byKey(const Key('profile-continue')));
      await tester.tap(find.byKey(const Key('profile-continue')));
      await tester.pumpAndSettle();
      expect(find.text('Enter height between 30 and 300.'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('profile-height')), '172.5');
      await tester.ensureVisible(find.byKey(const Key('profile-continue')));
      await tester.tap(find.byKey(const Key('profile-continue')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('profile-weight')), '68.25');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('profile-height')))
            .controller!
            .text,
        '172.5',
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(GenderPage), findsOneWidget);
      expect(find.byKey(const Key('gender-selected')), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Create an account'), findsOneWidget);
      await tester.ensureVisible(find.text('Create account'));
      await tester.tap(find.text('Create account'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('gender-continue')));
      await tester.tap(find.byKey(const Key('gender-continue')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('profile-height')))
            .controller!
            .text,
        '172.5',
      );
      expect(calls, 0);
    }, () => client);
    client.close();
  });

  testWidgets(
    'waits for account validation and allows retry when backend is unavailable',
    (tester) async {
      final pending = Completer<http.Response>();
      var checks = 0;
      final client = MockClient((request) {
        expect(request.url.path, '/api/auth/register/validate/');
        checks++;
        return checks == 1
            ? pending.future
            : Future.value(http.Response('', 204));
      });
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(home: RegistrationPage()));
        await fillForm(tester);
        await tester.tap(find.text('Create account'));
        await tester.pump();
        expect(find.byType(GenderPage), findsNothing);
        expect(
          tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
          isNull,
        );
        pending.completeError(http.ClientException('offline'));
        await tester.pumpAndSettle();
        expect(
          find.text('Could not connect. Please try again.'),
          findsOneWidget,
        );
        expect(find.byType(GenderPage), findsNothing);
        await tester.ensureVisible(find.text('Create account'));
        await tester.tap(find.text('Create account'));
        await tester.pumpAndSettle();
        expect(find.byType(GenderPage), findsOneWidget);
        expect(checks, 2);
      }, () => client);
      client.close();
    },
  );
}
