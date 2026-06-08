import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
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

  test('storageEvents passes detectInternalVolumes argument', () async {
    dynamic receivedArgs;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockStreamHandler(
          eventChannel,
          MockStreamHandler.inline(
            onListen: (arguments, eventSink) {
              receivedArgs = arguments;
              eventSink.success({
                'type': 'mounted',
                'path': '/storage/1234-5678',
              });
            },
          ),
        );

    await platform.storageEvents(detectInternalVolumes: false).first;
    expect(receivedArgs, {
      'detectInternalVolumes': false,
    });

    await platform.storageEvents(detectInternalVolumes: true).first;
    expect(receivedArgs, {
      'detectInternalVolumes': true,
    });
  });
}
