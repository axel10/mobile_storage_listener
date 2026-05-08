//
//  Generated file. Do not edit.
//

// clang-format off

#include "generated_plugin_registrant.h"

#include <mobile_storage_listener/mobile_storage_listener_plugin.h>

void fl_register_plugins(FlPluginRegistry* registry) {
  g_autoptr(FlPluginRegistrar) mobile_storage_listener_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "MobileStorageListenerPlugin");
  mobile_storage_listener_plugin_register_with_registrar(mobile_storage_listener_registrar);
}
