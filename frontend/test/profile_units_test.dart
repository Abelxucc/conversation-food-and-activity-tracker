import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tracktalk/profile_details.dart';
import 'package:tracktalk/profile_setup_page.dart';

Future<void> pressContinue(WidgetTester tester, {bool gender = false}) async {
  final button = find.byKey(
    Key(gender ? 'gender-continue' : 'profile-continue'),
  );
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pumpAndSettle();
}

String fieldText(WidgetTester tester, String name) => tester
    .widget<TextFormField>(find.byKey(Key('profile-$name')))
    .controller!
    .text;

void main() {
  testWidgets('unit switches preserve entries and submit metric measurements', (
    tester,
  ) async {
    ProfileDetails? submitted;
    final draft = ProfileSetupDraft()..gender = ProfileGender.nonBinary;
    await tester.pumpWidget(
      MaterialApp(
        home: ProfileSetupPage(
          draft: draft,
          onSubmit: (details) async {
            submitted = details;
          },
        ),
      ),
    );
    await pressContinue(tester, gender: true);
    await tester.enterText(find.byKey(const Key('profile-height')), '170');
    await tester.ensureVisible(find.byKey(const Key('unit-ft / in')));
    await tester.tap(find.byKey(const Key('unit-ft / in')));
    await tester.pumpAndSettle();
    expect(fieldText(tester, 'height-feet'), '5');
    expect(
      double.parse(fieldText(tester, 'height-inches')),
      closeTo(6.93, 0.01),
    );
    await tester.enterText(find.byKey(const Key('profile-height-inches')), '7');
    await pressContinue(tester);
    await tester.enterText(find.byKey(const Key('profile-weight')), '70');
    await tester.ensureVisible(find.byKey(const Key('unit-lb')));
    await tester.tap(find.byKey(const Key('unit-lb')));
    await tester.pumpAndSettle();
    expect(
      double.parse(fieldText(tester, 'weight-pounds')),
      closeTo(154.32, 0.01),
    );
    await tester.enterText(
      find.byKey(const Key('profile-weight-pounds')),
      '220.46',
    );
    await pressContinue(tester);
    expect(find.text('Age (years)'), findsOneWidget);
    expect(find.text('Get started!'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('profile-age')), '24');
    await pressContinue(tester);
    expect(submitted!.gender, ProfileGender.nonBinary);
    expect(double.parse(submitted!.heightCm), closeTo(170.18, 0.01));
    expect(double.parse(submitted!.weightKg), closeTo(100, 0.01));
    expect(submitted!.age, 24);
  });

  testWidgets(
    'invalid imperial input cannot advance and back retains unit choice',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ProfileSetupPage(
            draft: ProfileSetupDraft()..gender = ProfileGender.female,
            onSubmit: (_) async {},
          ),
        ),
      );
      await pressContinue(tester, gender: true);
      await tester.tap(find.byKey(const Key('unit-ft / in')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('profile-height-feet')), '5');
      await tester.enterText(
        find.byKey(const Key('profile-height-inches')),
        '12',
      );
      await pressContinue(tester);
      expect(find.text('2 of 4'), findsOneWidget);
      expect(find.text('Enter inches between 0 and 11.99.'), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('profile-height-inches')),
        '7',
      );
      await pressContinue(tester);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(fieldText(tester, 'height-feet'), '5');
      expect(fieldText(tester, 'height-inches'), '7');
      await tester.ensureVisible(find.byKey(const Key('unit-cm')));
      await tester.tap(find.byKey(const Key('unit-cm')));
      await tester.pumpAndSettle();
      expect(fieldText(tester, 'height'), '170.18');
      expect(tester.takeException(), isNull);
    },
  );
}
