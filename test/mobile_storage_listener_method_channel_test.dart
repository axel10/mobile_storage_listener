import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test/src/mock_event_channel.dart';
import 'package:mobile_storage_listener/mobile_storage_event.dart';
import 'package:mobile_storage_listener/mobile_storage_listener_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  MethodChannelMobileStorageListener platform =
      MethodChannelMobileStorageListener();
  const MethodChannel channel = MethodChannel('mobile_storage_listener');
  const EventChannel eventChannel = EventChannel(
    'mobile_storage_listener/events',
  );

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
          return '42';
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockStreamHandler(eventChannel, null);
  });

  test('getPlatformVersion', () async {
    expect(await platform.getPlatformVersion(), '42');
  });

  test('storageEvents', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockStreamHandler(
          eventChannel,
          MockStreamHandler.inline(
            onListen: (_, eventSink) {
              eventSink.success({
                'type': 'mounted',
                'path': '/storage/1234-5678',
              });
            },
          ),
        );

    final event = await platform.storageEvents().first;

    expect(event.type, MobileStorageEventType.mounted);
    expect(event.path, '/storage/1234-5678');
  });
}
