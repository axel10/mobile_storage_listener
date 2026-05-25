# mobile_storage_listener

A Flutter plugin to monitor external and removable storage devices (USB drives, SD cards, external volumes) being mounted, unmounted, or removed across Android, iOS, macOS, Windows, and Linux.

## Features

- **Multi-Platform Support**: Works on Android, iOS (17.0+), macOS, Windows, and Linux.
- **Real-Time Stream**: Subscribe to storage events to react instantly when media is plugged in or removed.
- **Detailed Event Metadata**: Receive both the event type (`mounted`, `unmounted`, `removed`, `eject`, `bad_removal`) and the path (or unique identifier) of the storage media.
- **Automated Lifecycle**: Automatically manages native listeners when the Dart stream subscription is active or cancelled.

---

## Platform Support

| Platform | Support | Notes |
|---|---|---|
| **Android** | Yes | Monitors standard media broadcast intents. |
| **iOS** | Yes (17.0+) | Uses `AVExternalStorageDeviceDiscoverySession`. Returns UUID as path. |
| **macOS** | Yes | Monitors `NSWorkspace` mount/unmount notifications. |
| **Windows** | Yes | Monitors `WM_DEVICECHANGE` messages for removable volumes. |
| **Linux** | Yes | Uses `GVolumeMonitor` for GLib-based desktop mount monitoring. |

---

## Getting Started

### 1. Add dependency

Add `mobile_storage_listener` to your `pubspec.yaml`:

```yaml
dependencies:
  mobile_storage_listener: ^1.0.0
```

### 2. Import the package

```dart
import 'package:mobile_storage_listener/mobile_storage_listener.dart';
import 'package:mobile_storage_listener/mobile_storage_event.dart';
```

---

## Usage

### Listen to Storage Events

Subscribe to the `storageEvents` stream to receive real-time notifications about storage media state changes:

```dart
final _storageListener = MobileStorageListener();
StreamSubscription<MobileStorageEvent>? _subscription;

@override
void initState() {
  super.initState();
  
  _subscription = _storageListener.storageEvents.listen((event) {
    print('Storage Event Type: ${event.typeName}'); // e.g., 'mounted', 'unmounted'
    print('Storage Path / ID: ${event.path}');       // File path or device identifier
  });
}

@override
void dispose() {
  _subscription?.cancel(); // Always cancel subscriptions to free resources
  super.dispose();
}
```

### Get Platform Version

You can also retrieve the current platform's version string:

```dart
final _storageListener = MobileStorageListener();
final platformVersion = await _storageListener.getPlatformVersion();
print('Running on: $platformVersion');
```

---

## API Reference

### `MobileStorageListener`

The main entry point class to interact with the plugin.

- `Stream<MobileStorageEvent> get storageEvents`: A broadcast stream of storage activity events.
- `Future<String?> getPlatformVersion()`: Returns the OS platform version name.

### `MobileStorageEvent`

Represents an event triggered by a storage device change.

- `MobileStorageEventType type`: The enum representing the event type.
- `String? path`: The file path or platform-specific identifier of the storage volume.
- `String get typeName`: Helper getter returning the event type as a string (e.g. `'mounted'`).

### `MobileStorageEventType`

An enum representing the specific storage transition:

- `mounted`: Media was successfully mounted and is ready for use.
- `unmounted`: Media was safely unmounted.
- `removed`: Media was removed from the device.
- `eject`: Media eject request triggered.
- `badRemoval`: Media was removed unsafely (Android-specific).
- `unknown`: Fallback value for unrecognized events.

---

## Platform-Specific Implementation Details

### iOS
- Only supported on **iOS 17.0 and newer** due to dependencies on Apple's `AVExternalStorageDeviceDiscoverySession` API.
- iOS does not expose direct file paths for external volumes. Therefore, the `path` property in `MobileStorageEvent` will contain the unique `UUID` of the connected external device instead of a file system path.

### Android
- The plugin dynamically registers a system `BroadcastReceiver` internally when you subscribe to the stream. You do not need to add any special declarations to your `AndroidManifest.xml`.

### macOS
- Uses `NSWorkspace.shared.notificationCenter` to listen for global mount and unmount events.

### Windows
- Monitors top-level window messages (`WM_DEVICECHANGE`) using Flutter's window procedure delegation. Filters specifically for `DBT_DEVTYP_VOLUME` representing external or removable drives.

### Linux
- Employs the GIO library's `GVolumeMonitor` to detect system-wide mounts and unmounts, filtering for removable media.

---

## License

This project is licensed under the Apache License, Version 2.0 - see the [LICENSE](LICENSE) file for details.
