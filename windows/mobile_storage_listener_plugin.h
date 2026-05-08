#ifndef FLUTTER_PLUGIN_MOBILE_STORAGE_LISTENER_PLUGIN_H_
#define FLUTTER_PLUGIN_MOBILE_STORAGE_LISTENER_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>

#include <memory>

namespace mobile_storage_listener {

class MobileStorageListenerPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

  MobileStorageListenerPlugin();

  virtual ~MobileStorageListenerPlugin();

  // Disallow copy and assign.
  MobileStorageListenerPlugin(const MobileStorageListenerPlugin&) = delete;
  MobileStorageListenerPlugin& operator=(const MobileStorageListenerPlugin&) = delete;

  // Called when a method is called on this plugin's channel from Dart.
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue> &method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
};

}  // namespace mobile_storage_listener

#endif  // FLUTTER_PLUGIN_MOBILE_STORAGE_LISTENER_PLUGIN_H_
