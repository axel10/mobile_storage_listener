import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'mobile_storage_event.dart';
import 'mobile_storage_listener_method_channel.dart';

abstract class MobileStorageListenerPlatform extends PlatformInterface {
  /// Constructs a MobileStorageListenerPlatform.
  MobileStorageListenerPlatform() : super(token: _token);

  static final Object _token = Object();

  static MobileStorageListenerPlatform _instance =
      MethodChannelMobileStorageListener();

  /// The default instance of [MobileStorageListenerPlatform] to use.
  ///
  /// Defaults to [MethodChannelMobileStorageListener].
  static MobileStorageListenerPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [MobileStorageListenerPlatform] when
  /// they register themselves.
  static set instance(MobileStorageListenerPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }

  Stream<MobileStorageEvent> storageEvents() {
    throw UnimplementedError('storageEvents() has not been implemented.');
  }
}
