import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tracktalk/main.dart';
import 'package:tracktalk/ReSetPage.dart';

void main() {
  testWidgets('forgot password opens reset with email and can return', (
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
    final field = tester.widget<TextFormField>(
      find.byKey(const Key('reset-email')),
    );
    expect(field.controller!.text, 'person@example.com');
    await tester.ensureVisible(find.text('Back to log in'));
    await tester.tap(find.text('Back to log in'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome back'), findsOneWidget);
  });

  testWidgets(
    'invalid email sends no request and duplicate submits are blocked',
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
        await tester.pumpWidget(MaterialApp(home: const ResetPage()));
        await tester.ensureVisible(find.text('Request reset link'));
        await tester.tap(find.text('Request reset link'));
        await tester.pump();
        expect(find.text('Enter your email address.'), findsOneWidget);
        expect(calls, 0);
        await tester.enterText(
          find.byKey(const Key('reset-email')),
          'person@example.com',
        );
        await tester.ensureVisible(find.text('Request reset link'));
        await tester.tap(find.text('Request reset link'));
        await tester.pump();
        expect(calls, 1);
        final button = tester.widget<FilledButton>(find.byType(FilledButton));
        expect(button.onPressed, isNull);
        pending.complete(http.Response('{"detail":"accepted"}', 200));
        await tester.pumpAndSettle();
        expect(find.text('Reset link requested'), findsOneWidget);
        expect(find.byType(TextFormField), findsNothing);
      }, () => client);
      client.close();
    },
  );

  testWidgets('password confirmation and invalid link allow retry', (
    tester,
  ) async {
    final client = MockClient((request) async {
      expect(request.url.path, '/api/auth/password-reset/confirm/');
      final data = jsonDecode(request.body) as Map<String, dynamic>;
      expect(data['uid'], 'MQ');
      expect(data['token'], 'example-token');
      return http.Response(
        '{"detail":"This reset link is invalid or has expired. Request a new link."}',
        400,
      );
    });
    await http.runWithClient(() async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ResetPage(uid: 'MQ', token: 'example-token'),
        ),
      );
      await tester.enterText(
        find.byKey(const Key('reset-password')),
        'A-new-password-71!',
      );
      await tester.enterText(
        find.byKey(const Key('reset-confirmation')),
        'different',
      );
      await tester.ensureVisible(find.text('Reset password'));
      await tester.tap(find.text('Reset password'));
      await tester.pumpAndSettle();
      expect(find.text('The passwords do not match.'), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('reset-confirmation')),
        'A-new-password-71!',
      );
      await tester.ensureVisible(find.text('Reset password'));
      await tester.tap(find.text('Reset password'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'This reset link is invalid or has expired. Request a new link.',
        ),
        findsOneWidget,
      );
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull,
      );
      expect(find.text('Password reset'), findsNothing);
    }, () => client);
    client.close();
  });

  testWidgets(
    'deep link changes password only after successful backend response',
    (tester) async {
      final client = MockClient(
        (request) async => http.Response('{"detail":"reset"}', 200),
      );
      await http.runWithClient(() async {
        await tester.pumpWidget(const TrackTalkApp());
        tester
            .state<NavigatorState>(find.byType(Navigator))
            .pushNamed('/reset-password/MQ/example-token');
        await tester.pumpAndSettle();
        expect(find.text('Set a new password'), findsOneWidget);
        await tester.enterText(
          find.byKey(const Key('reset-password')),
          'A-new-password-71!',
        );
        await tester.enterText(
          find.byKey(const Key('reset-confirmation')),
          'A-new-password-71!',
        );
        await tester.ensureVisible(find.text('Reset password'));
        await tester.tap(find.text('Reset password'));
        await tester.pumpAndSettle();
        expect(find.text('Password reset'), findsOneWidget);
        expect(find.byType(TextFormField), findsNothing);
        await tester.ensureVisible(find.text('Back to log in'));
        await tester.tap(find.text('Back to log in'));
        await tester.pumpAndSettle();
        expect(find.text('Welcome back'), findsOneWidget);
      }, () => client);
      client.close();
    },
  );

  testWidgets('reset form fits a small screen with keyboard', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 260);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpWidget(
      const MaterialApp(
        home: ResetPage(uid: 'MQ', token: 'test-token'),
      ),
    );
    await tester.ensureVisible(find.text('Reset password'));
    await tester.tap(find.text('Reset password'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a new password.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
