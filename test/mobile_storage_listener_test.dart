import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_storage_listener/mobile_storage_event.dart';
import 'package:mobile_storage_listener/mobile_storage_listener.dart';
import 'package:mobile_storage_listener/mobile_storage_listener_platform_interface.dart';
import 'package:mobile_storage_listener/mobile_storage_listener_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockMobileStorageListenerPlatform
    with MockPlatformInterfaceMixin
    implements MobileStorageListenerPlatform {
  @override
  Future<String?> getPlatformVersion() => Future.value('42');

  @override
  Stream<MobileStorageEvent> storageEvents() => Stream.value(
    const MobileStorageEvent(
      type: MobileStorageEventType.mounted,
      path: '/storage/1234-5678',
    ),
  );
}

void main() {
  final MobileStorageListenerPlatform initialPlatform =
      MobileStorageListenerPlatform.instance;

  test('$MethodChannelMobileStorageListener is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelMobileStorageListener>());
  });

  test('getPlatformVersion', () async {
    MobileStorageListener mobileStorageListenerPlugin = MobileStorageListener();
    MockMobileStorageListenerPlatform fakePlatform =
        MockMobileStorageListenerPlatform();
    MobileStorageListenerPlatform.instance = fakePlatform;

    expect(await mobileStorageListenerPlugin.getPlatformVersion(), '42');
  });

  test('storageEvents', () async {
    final mobileStorageListenerPlugin = MobileStorageListener();
    final fakePlatform = MockMobileStorageListenerPlatform();
    MobileStorageListenerPlatform.instance = fakePlatform;

    expect(
      await mobileStorageListenerPlugin.storageEvents.first,
      isA<MobileStorageEvent>()
          .having((event) => event.type, 'type', MobileStorageEventType.mounted)
          .having((event) => event.path, 'path', '/storage/1234-5678'),
    );
  });
}
