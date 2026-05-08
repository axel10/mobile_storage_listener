#include "include/mobile_storage_listener/mobile_storage_listener_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "mobile_storage_listener_plugin.h"

void MobileStorageListenerPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  mobile_storage_listener::MobileStorageListenerPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
