#include "include/mobile_storage_listener/mobile_storage_listener_plugin.h"

#include <flutter_linux/flutter_linux.h>
#include <gio/gio.h>
#include <gtk/gtk.h>
#include <sys/utsname.h>

#include <cstring>
#include <vector>
#include <string>
#include <algorithm>

#include "mobile_storage_listener_plugin_private.h"

#define MOBILE_STORAGE_LISTENER_PLUGIN(obj) \
  (G_TYPE_CHECK_INSTANCE_CAST((obj), mobile_storage_listener_plugin_get_type(), \
                              MobileStorageListenerPlugin))

struct _MobileStorageListenerPlugin {
  GObject parent_instance;
};

typedef struct {
  FlEventChannel *event_channel;
  GVolumeMonitor *volume_monitor;
  gulong mount_added_handler;
  gulong mount_removed_handler;
  gboolean listening;
  std::vector<std::string> known_mounts;
  gboolean detect_internal_volumes;
} StorageMonitorState;

G_DEFINE_TYPE(MobileStorageListenerPlugin, mobile_storage_listener_plugin, g_object_get_type())

namespace {

gboolean is_removable_mount(GMount *mount, gboolean detect_internal_volumes) {
  if (mount == nullptr) {
    return FALSE;
  }

  GVolume *volume = g_mount_get_volume(mount);
  gboolean removable = FALSE;
  gboolean has_volume_or_drive = FALSE;

  if (volume != nullptr) {
    has_volume_or_drive = TRUE;
    GDrive *drive = g_volume_get_drive(volume);
    if (drive != nullptr) {
      removable = g_drive_is_removable(drive) || g_drive_is_media_removable(drive);
      g_object_unref(drive);
    }
    g_object_unref(volume);
  } else {
    GDrive *drive = g_mount_get_drive(mount);
    if (drive != nullptr) {
      has_volume_or_drive = TRUE;
      removable = g_drive_is_removable(drive) || g_drive_is_media_removable(drive);
      g_object_unref(drive);
    }
  }

  if (detect_internal_volumes) {
    return has_volume_or_drive;
  }

  return removable;
}

gchar *get_mount_path(GMount *mount) {
  if (mount == nullptr) {
    return nullptr;
  }

  GFile *root = g_mount_get_root(mount);
  if (root == nullptr) {
    return nullptr;
  }

  gchar *path = g_file_get_path(root);
  g_object_unref(root);
  return path;
}

void mount_added_cb(GVolumeMonitor *monitor, GMount *mount, gpointer user_data) {
  (void)monitor;
  auto *state = static_cast<StorageMonitorState *>(user_data);
  if (!state->listening) {
    return;
  }

  if (is_removable_mount(mount, state->detect_internal_volumes)) {
    gchar *path = get_mount_path(mount);
    if (path != nullptr) {
      std::string path_str(path);
      auto it = std::find(state->known_mounts.begin(), state->known_mounts.end(), path_str);
      if (it == state->known_mounts.end()) {
        state->known_mounts.push_back(path_str);

        g_autoptr(FlValue) event = create_storage_event("mounted", path);
        g_autoptr(GError) error = nullptr;
        if (!fl_event_channel_send(state->event_channel, event, nullptr, &error)) {
          g_warning("Failed to send storage event: %s", error->message);
        }
      }
      g_free(path);
    }
  }
}

void mount_removed_cb(GVolumeMonitor *monitor, GMount *mount, gpointer user_data) {
  (void)monitor;
  auto *state = static_cast<StorageMonitorState *>(user_data);
  if (!state->listening) {
    return;
  }

  gchar *path = get_mount_path(mount);
  if (path != nullptr) {
    std::string path_str(path);
    auto it = std::find(state->known_mounts.begin(), state->known_mounts.end(), path_str);
    if (it != state->known_mounts.end()) {
      state->known_mounts.erase(it);

      g_autoptr(FlValue) event = create_storage_event("unmounted", path);
      g_autoptr(GError) error = nullptr;
      if (!fl_event_channel_send(state->event_channel, event, nullptr, &error)) {
        g_warning("Failed to send storage event: %s", error->message);
      }
    }
    g_free(path);
  }
}

FlMethodErrorResponse *listen_cb(FlEventChannel *channel, FlValue *args, gpointer user_data) {
  (void)channel;
  auto *state = static_cast<StorageMonitorState *>(user_data);
  state->listening = TRUE;

  gboolean detect_internal_volumes = TRUE;
  if (args != nullptr && fl_value_get_type(args) == FL_VALUE_TYPE_MAP) {
    FlValue *val = fl_value_lookup_string(args, "detectInternalVolumes");
    if (val != nullptr && fl_value_get_type(val) == FL_VALUE_TYPE_BOOL) {
      detect_internal_volumes = fl_value_get_bool(val);
    }
  }
  state->detect_internal_volumes = detect_internal_volumes;

  if (state->volume_monitor == nullptr) {
    state->volume_monitor = g_volume_monitor_get();

    // Populate already mounted removable volumes
    GList *mounts = g_volume_monitor_get_mounts(state->volume_monitor);
    for (GList *l = mounts; l != nullptr; l = l->next) {
      auto *mount = static_cast<GMount *>(l->data);
      if (is_removable_mount(mount, state->detect_internal_volumes)) {
        gchar *path = get_mount_path(mount);
        if (path != nullptr) {
          state->known_mounts.push_back(path);
          g_free(path);
        }
      }
    }
    g_list_free_full(mounts, g_object_unref);

    state->mount_added_handler = g_signal_connect(
        state->volume_monitor, "mount-added", G_CALLBACK(mount_added_cb), state);
    state->mount_removed_handler = g_signal_connect(
        state->volume_monitor, "mount-removed", G_CALLBACK(mount_removed_cb), state);
  }

  return nullptr;
}

FlMethodErrorResponse *cancel_cb(FlEventChannel *channel, FlValue *args, gpointer user_data) {
  (void)channel;
  (void)args;
  auto *state = static_cast<StorageMonitorState *>(user_data);
  state->listening = FALSE;

  if (state->volume_monitor != nullptr) {
    if (state->mount_added_handler != 0) {
      g_signal_handler_disconnect(state->volume_monitor, state->mount_added_handler);
      state->mount_added_handler = 0;
    }
    if (state->mount_removed_handler != 0) {
      g_signal_handler_disconnect(state->volume_monitor, state->mount_removed_handler);
      state->mount_removed_handler = 0;
    }
    g_clear_object(&state->volume_monitor);
  }
  state->known_mounts.clear();

  return nullptr;
}

void storage_monitor_state_free(gpointer data) {
  auto *state = static_cast<StorageMonitorState *>(data);
  if (state == nullptr) {
    return;
  }

  state->listening = FALSE;
  g_clear_object(&state->event_channel);
  if (state->volume_monitor != nullptr) {
    if (state->mount_added_handler != 0) {
      g_signal_handler_disconnect(state->volume_monitor, state->mount_added_handler);
      state->mount_added_handler = 0;
    }
    if (state->mount_removed_handler != 0) {
      g_signal_handler_disconnect(state->volume_monitor, state->mount_removed_handler);
      state->mount_removed_handler = 0;
    }
    g_clear_object(&state->volume_monitor);
  }
  state->known_mounts.clear();

  delete state;
}

}  // namespace

void mobile_storage_listener_plugin_handle_method_call(
    MobileStorageListenerPlugin* self,
    FlMethodCall* method_call) {
  (void)self;
  g_autoptr(FlMethodResponse) response = nullptr;

  const gchar* method = fl_method_call_get_name(method_call);

  if (strcmp(method, "getPlatformVersion") == 0) {
    response = get_platform_version();
  } else {
    response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  }

  fl_method_call_respond(method_call, response, nullptr);
}

FlMethodResponse* get_platform_version() {
  struct utsname uname_data = {};
  uname(&uname_data);
  g_autofree gchar *version = g_strdup_printf("Linux %s", uname_data.version);
  g_autoptr(FlValue) result = fl_value_new_string(version);
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

FlValue *create_storage_event(const gchar *type, const gchar *path) {
  g_autoptr(FlValue) event = fl_value_new_map();
  fl_value_set_string_take(event, "type", fl_value_new_string(type));
  fl_value_set_string_take(event, "path", path != nullptr ? fl_value_new_string(path)
                                                           : fl_value_new_null());
  return g_steal_pointer(&event);
}

static void mobile_storage_listener_plugin_dispose(GObject* object) {
  G_OBJECT_CLASS(mobile_storage_listener_plugin_parent_class)->dispose(object);
}

static void mobile_storage_listener_plugin_class_init(MobileStorageListenerPluginClass* klass) {
  G_OBJECT_CLASS(klass)->dispose = mobile_storage_listener_plugin_dispose;
}

static void mobile_storage_listener_plugin_init(MobileStorageListenerPlugin* self) {}

static void method_call_cb(FlMethodChannel* channel, FlMethodCall* method_call,
                           gpointer user_data) {
  (void)channel;
  MobileStorageListenerPlugin* plugin = MOBILE_STORAGE_LISTENER_PLUGIN(user_data);
  mobile_storage_listener_plugin_handle_method_call(plugin, method_call);
}

void mobile_storage_listener_plugin_register_with_registrar(FlPluginRegistrar* registrar) {
  MobileStorageListenerPlugin* plugin = MOBILE_STORAGE_LISTENER_PLUGIN(
      g_object_new(mobile_storage_listener_plugin_get_type(), nullptr));

  g_autoptr(FlStandardMethodCodec) method_codec = fl_standard_method_codec_new();
  g_autoptr(FlMethodChannel) method_channel =
      fl_method_channel_new(fl_plugin_registrar_get_messenger(registrar),
                            "mobile_storage_listener",
                            FL_METHOD_CODEC(method_codec));
  fl_method_channel_set_method_call_handler(method_channel, method_call_cb,
                                            g_object_ref(plugin),
                                            g_object_unref);

  g_autoptr(FlStandardMethodCodec) event_codec = fl_standard_method_codec_new();
  g_autoptr(FlEventChannel) event_channel =
      fl_event_channel_new(fl_plugin_registrar_get_messenger(registrar),
                           "mobile_storage_listener/events",
                           FL_METHOD_CODEC(event_codec));

  auto *state = new StorageMonitorState{};
  state->event_channel = FL_EVENT_CHANNEL(g_object_ref(event_channel));
  fl_event_channel_set_stream_handlers(event_channel, listen_cb, cancel_cb, state,
                                       storage_monitor_state_free);

  g_object_unref(plugin);
}
