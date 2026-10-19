import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tracktalk/main.dart';

void main() {
  testWidgets('shows successful backend connection', (tester) async {
    final client = MockClient((request) async {
      expect(request.url.path, '/api/health/');
      return http.Response('{"status":"ok","service":"TrackTalk API"}', 200);
    });
    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(home: ConnectionPage()));
      await tester.tap(find.text('Check connection'));
      await tester.pumpAndSettle();
      expect(find.text('Connected to TrackTalk API.'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    }, () => client);
    client.close();
  });

  testWidgets('allows retry after a failed request', (tester) async {
    final client = MockClient((_) async => http.Response('Unavailable', 503));
    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(home: ConnectionPage()));
      await tester.tap(find.text('Check connection'));
      await tester.pumpAndSettle();
      expect(
        find.text('Could not connect. Start the backend, then try again.'),
        findsOneWidget,
      );
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull,
      );
    }, () => client);
    client.close();
  });
}
