import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'mobile_storage_event.dart';
import 'mobile_storage_listener_platform_interface.dart';

/// An implementation of [MobileStorageListenerPlatform] that uses method channels.
class MethodChannelMobileStorageListener extends MobileStorageListenerPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('mobile_storage_listener');

  @visibleForTesting
  final eventChannel = const EventChannel('mobile_storage_listener/events');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>(
      'getPlatformVersion',
    );
    return version;
  }

  @override
  Stream<MobileStorageEvent> storageEvents() {
    return eventChannel.receiveBroadcastStream().map((event) {
      if (event is Map<Object?, Object?>) {
        return MobileStorageEvent.fromMap(event);
      }

      return const MobileStorageEvent(
        type: MobileStorageEventType.unknown,
        path: null,
      );
    });
  }
}
