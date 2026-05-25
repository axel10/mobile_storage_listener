import Cocoa
import FlutterMacOS

public class MobileStorageListenerPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
  private var eventSink: FlutterEventSink?
  private var mountObserver: NSObjectProtocol?
  private var unmountObserver: NSObjectProtocol?
  private var knownDrives = Set<String>()

  public static func register(with registrar: FlutterPluginRegistrar) {
    let methodChannel = FlutterMethodChannel(
      name: "mobile_storage_listener",
      binaryMessenger: registrar.messenger
    )
    let eventChannel = FlutterEventChannel(
      name: "mobile_storage_listener/events",
      binaryMessenger: registrar.messenger
    )
    let instance = MobileStorageListenerPlugin()
    registrar.addMethodCallDelegate(instance, channel: methodChannel)
    eventChannel.setStreamHandler(instance)
  }

  public func handle(
    _ call: FlutterMethodCall,
    result: @escaping FlutterResult
  ) {
    switch call.method {
    case "getPlatformVersion":
      result("macOS " + ProcessInfo.processInfo.operatingSystemVersionString)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  public func onListen(
    withArguments arguments: Any?,
    eventSink events: @escaping FlutterEventSink
  ) -> FlutterError? {
    eventSink = events
    populateKnownDrives()
    startObserving()
    return nil
  }

  public func onCancel(withArguments arguments: Any?) -> FlutterError? {
    stopObserving()
    knownDrives.removeAll()
    eventSink = nil
    return nil
  }

  private func populateKnownDrives() {
    knownDrives.removeAll()
    let keys: [URLResourceKey] = [.volumeIsRemovableKey, .volumeIsInternalKey, .volumeIsLocalKey]
    let paths = FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: keys, options: [.skipHiddenVolumes]) ?? []
    for url in paths {
      if isExternalVolume(url) {
        knownDrives.insert(url.path)
      }
    }
  }

  private func isExternalVolume(_ url: URL) -> Bool {
    let keys: Set<URLResourceKey> = [.volumeIsRemovableKey, .volumeIsInternalKey, .volumeIsLocalKey]
    guard let values = try? url.resourceValues(forKeys: keys) else {
      return false
    }
    let isRemovable = values.volumeIsRemovable ?? false
    let isInternal = values.volumeIsInternal ?? true
    let isLocal = values.volumeIsLocal ?? false
    return isRemovable || (!isInternal && isLocal)
  }

  private func startObserving() {
    guard mountObserver == nil else {
      return
    }

    let center = NSWorkspace.shared.notificationCenter

    mountObserver = center.addObserver(
      forName: NSWorkspace.didMountNotification,
      object: nil,
      queue: .main
    ) { [weak self] notification in
      self?.emit(notification: notification, type: "mounted")
    }

    unmountObserver = center.addObserver(
      forName: NSWorkspace.didUnmountNotification,
      object: nil,
      queue: .main
    ) { [weak self] notification in
      self?.emit(notification: notification, type: "unmounted")
    }
  }

  private func stopObserving() {
    let center = NSWorkspace.shared.notificationCenter

    if let observer = mountObserver {
      center.removeObserver(observer)
      mountObserver = nil
    }

    if let observer = unmountObserver {
      center.removeObserver(observer)
      unmountObserver = nil
    }
  }

  private func emit(notification: Notification, type: String) {
    guard let eventSink else {
      return
    }

    guard let volumeURL = notification.userInfo?[NSWorkspace.volumeURLUserInfoKey] as? URL else {
      return
    }

    let path = volumeURL.path

    if type == "mounted" {
      if isExternalVolume(volumeURL) {
        knownDrives.insert(path)
        eventSink([
          "type": type,
          "path": path,
        ])
      }
    } else if type == "unmounted" {
      if knownDrives.contains(path) {
        knownDrives.remove(path)
        eventSink([
          "type": type,
          "path": path,
        ])
      }
    }
  }
}
