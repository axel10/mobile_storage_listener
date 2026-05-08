import 'mobile_storage_event.dart';
import 'mobile_storage_listener_platform_interface.dart';

class MobileStorageListener {
  Future<String?> getPlatformVersion() {
    return MobileStorageListenerPlatform.instance.getPlatformVersion();
  }

  Stream<MobileStorageEvent> get storageEvents {
    return MobileStorageListenerPlatform.instance.storageEvents();
  }
}
