import 'dart:convert';

import 'Login.dart';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

const apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://127.0.0.1:8000',
);

void main() => runApp(const TrackTalkApp());

class TrackTalkApp extends StatelessWidget {
  const TrackTalkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TrackTalk',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF287565)),
        useMaterial3: true,
      ),
      home: const LoginPage(),
    );
  }
}

class ConnectionPage extends StatefulWidget {
  const ConnectionPage({super.key});

  @override
  State<ConnectionPage> createState() => _ConnectionPageState();
}

class _ConnectionPageState extends State<ConnectionPage> {
  bool _loading = false;
  bool _connected = false;
  String _message = 'Ready to check your local Django backend.';

  Future<void> _checkConnection() async {
    setState(() {
      _loading = true;
      _connected = false;
      _message = 'Connecting…';
    });
    try {
      final response = await http
          .get(Uri.parse('$apiBaseUrl/api/health/'))
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) {
        throw Exception('Server returned HTTP ${response.statusCode}');
      }
      final data = jsonDecode(response.body);
      if (data is! Map<String, dynamic> || data['status'] != 'ok') {
        throw const FormatException('Unexpected backend response');
      }
      if (!mounted) return;
      setState(() {
        _connected = true;
        _message = 'Connected to ${data['service'] ?? 'Django'}.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _message = 'Could not connect. Start the backend, then try again.';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F8F6),
      appBar: AppBar(title: const Text('TrackTalk')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      _connected
                          ? Icons.check_circle
                          : Icons.chat_bubble_outline,
                      size: 44,
                      color: colors.primary,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Your tracker starts here.',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'A simple place to record food and activity, in your own words.',
                    ),
                    const SizedBox(height: 28),
                    const Text(
                      'LOCAL DEVELOPMENT',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Text(_message, key: const Key('connection-status')),
                    const SizedBox(height: 8),
                    const SelectableText('$apiBaseUrl/api/health/'),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: _loading ? null : _checkConnection,
                      icon: _loading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.sync),
                      label: Text(
                        _loading ? 'Connecting…' : 'Check connection',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
