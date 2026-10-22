import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tracktalk/main.dart';
import 'package:tracktalk/ReSetPage.dart';

void main() {
  testWidgets('forgot password opens request page with email and returns', (
    tester,
  ) async {
    await tester.pumpWidget(const TrackTalkApp());
    await tester.enterText(
      find.byKey(const Key('login-email')),
      'person@example.com',
    );
    await tester.ensureVisible(find.text('Forgot password?'));
    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();
    expect(find.byType(ResetPage), findsOneWidget);
    expect(find.byType(TextFormField), findsOneWidget);
    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('reset-email')))
          .controller!
          .text,
      'person@example.com',
    );
    expect(find.text('Request password reset'), findsOneWidget);
    await tester.ensureVisible(find.text('Back to log in'));
    await tester.tap(find.text('Back to log in'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome back'), findsOneWidget);
  });

  testWidgets(
    'validates email and waits for acceptance before claiming submission',
    (tester) async {
      var calls = 0;
      final pending = Completer<http.Response>();
      final client = MockClient((request) {
        calls++;
        expect(request.url.path, '/api/auth/password-reset/');
        expect(jsonDecode(request.body), {'email': 'person@example.com'});
        return pending.future;
      });
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(home: ResetPage()));
        await tester.ensureVisible(find.text('Request password reset'));
        await tester.tap(find.text('Request password reset'));
        await tester.pump();
        expect(find.text('Enter your email address.'), findsOneWidget);
        expect(calls, 0);
        await tester.enterText(
          find.byKey(const Key('reset-email')),
          'person@example.com',
        );
        await tester.ensureVisible(find.text('Request password reset'));
        await tester.tap(find.text('Request password reset'));
        await tester.pump();
        expect(calls, 1);
        expect(
          tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
          isNull,
        );
        expect(find.text('Request submitted'), findsNothing);
        pending.complete(http.Response('{"detail":"accepted"}', 202));
        await tester.pumpAndSettle();
        expect(find.text('Request submitted'), findsOneWidget);
        expect(
          find.text(
            'Your password will be changed after your identity is verified.',
          ),
          findsOneWidget,
        );
        expect(find.byType(TextFormField), findsNothing);
        expect(find.text('Password reset'), findsNothing);
      }, () => client);
      client.close();
    },
  );

  testWidgets('network failure keeps request editable and allows retry', (
    tester,
  ) async {
    final client = MockClient(
      (_) async => throw http.ClientException('offline'),
    );
    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(home: ResetPage()));
      await tester.enterText(
        find.byKey(const Key('reset-email')),
        'person@example.com',
      );
      await tester.ensureVisible(find.text('Request password reset'));
      await tester.tap(find.text('Request password reset'));
      await tester.pumpAndSettle();
      expect(find.text('Could not connect. Please try again.'), findsOneWidget);
      expect(find.text('Request submitted'), findsNothing);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull,
      );
    }, () => client);
    client.close();
  });

  testWidgets('submission allows correcting the email afterwards', (
    tester,
  ) async {
    final client = MockClient((_) async => http.Response('{}', 202));
    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(home: ResetPage()));
      await tester.enterText(
        find.byKey(const Key('reset-email')),
        'person@example.com',
      );
      await tester.ensureVisible(find.text('Request password reset'));
      await tester.tap(find.text('Request password reset'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Use a different email'));
      await tester.tap(find.text('Use a different email'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('reset-email')), findsOneWidget);
      expect(find.text('Request password reset'), findsOneWidget);
    }, () => client);
    client.close();
  });

  testWidgets('small screen with keyboard keeps the request button reachable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 260);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpWidget(const MaterialApp(home: ResetPage()));
    await tester.ensureVisible(find.text('Request password reset'));
    await tester.tap(find.text('Request password reset'));
    await tester.pumpAndSettle();
    expect(find.text('Enter your email address.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
