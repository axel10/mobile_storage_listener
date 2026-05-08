#include <flutter_linux/flutter_linux.h>

#include "include/mobile_storage_listener/mobile_storage_listener_plugin.h"

// This file exposes some plugin internals for unit testing. See
// https://github.com/flutter/flutter/issues/88724 for current limitations
// in the unit-testable API.

// Handles the getPlatformVersion method call.
FlMethodResponse *get_platform_version();

// Builds a platform event payload for storage changes.
FlValue *create_storage_event(const gchar *type, const gchar *path);
