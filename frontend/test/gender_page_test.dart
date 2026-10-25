import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tracktalk/GenderPage.dart';
import 'package:tracktalk/RegistrationPage.dart';
import 'package:tracktalk/main.dart';

void main() {
  testWidgets('gender choices are exclusive and Continue stays on this page', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: GenderPage()));
    expect(find.byKey(const Key('gender-selected')), findsNothing);
    await tester.tap(find.byKey(const Key('gender-male')));
    await tester.pump();
    expect(find.byKey(const Key('gender-selected')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('gender-preferNotToSay')));
    await tester.tap(find.byKey(const Key('gender-preferNotToSay')));
    await tester.pump();
    expect(find.byKey(const Key('gender-selected')), findsOneWidget);
    expect(
      tester
          .widget<Semantics>(find.byKey(const Key('gender-preferNotToSay')))
          .properties
          .checked,
      isTrue,
    );
    expect(
      tester
          .widget<Semantics>(find.byKey(const Key('gender-male')))
          .properties
          .checked,
      isFalse,
    );
    await tester.ensureVisible(find.byKey(const Key('gender-continue')));
    await tester.tap(find.byKey(const Key('gender-continue')));
    await tester.pumpAndSettle();
    expect(find.byType(GenderPage), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a profile link without an account draft starts registration', (
    tester,
  ) async {
    await tester.pumpWidget(const TrackTalkApp());
    tester
        .state<NavigatorState>(find.byType(Navigator))
        .pushNamed('/profile/gender');
    await tester.pumpAndSettle();
    expect(find.byType(RegistrationPage), findsOneWidget);
    await tester.ensureVisible(find.text('Already have an account? Log in'));
    await tester.tap(find.text('Already have an account? Log in'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome back'), findsOneWidget);
  });

  testWidgets('small screens and larger text keep every option reachable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(1.6)),
          child: child!,
        ),
        home: const GenderPage(),
      ),
    );
    await tester.ensureVisible(find.byKey(const Key('gender-nonBinary')));
    await tester.tap(find.byKey(const Key('gender-nonBinary')));
    await tester.ensureVisible(find.byKey(const Key('gender-continue')));
    await tester.tap(find.byKey(const Key('gender-continue')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('gender-selected')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
