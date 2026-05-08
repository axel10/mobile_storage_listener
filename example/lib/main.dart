import 'package:flutter/material.dart';
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:mobile_storage_listener/mobile_storage_listener.dart';
import 'package:mobile_storage_listener/mobile_storage_event.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String _platformVersion = 'Unknown';
  final _mobileStorageListenerPlugin = MobileStorageListener();
  StreamSubscription<MobileStorageEvent>? _subscription;
  final List<String> _events = <String>[];

  @override
  void initState() {
    super.initState();
    initPlatformState();
    _subscription = _mobileStorageListenerPlugin.storageEvents.listen((event) {
      if (!mounted) return;

      setState(() {
        final path = event.path ?? 'unknown path';
        _events.insert(0, '${event.typeName}: $path');
      });
    });
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initPlatformState() async {
    String platformVersion;
    // Platform messages may fail, so we use a try/catch PlatformException.
    // We also handle the message potentially returning null.
    try {
      platformVersion =
          await _mobileStorageListenerPlugin.getPlatformVersion() ??
          'Unknown platform version';
    } on PlatformException {
      platformVersion = 'Failed to get platform version.';
    }

    // If the widget was removed from the tree while the asynchronous platform
    // message was in flight, we want to discard the reply rather than calling
    // setState to update our non-existent appearance.
    if (!mounted) return;

    setState(() {
      _platformVersion = platformVersion;
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Mobile storage listener')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Running on: $_platformVersion'),
            const SizedBox(height: 16),
            const Text('Latest storage events:'),
            const SizedBox(height: 8),
            if (_events.isEmpty)
              const Text('No storage events yet.')
            else
              ..._events.map(
                (event) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(event),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
