import Cocoa
import FlutterMacOS

public class MobileStorageListenerPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
  private var eventSink: FlutterEventSink?
  private var mountObserver: NSObjectProtocol?
  private var unmountObserver: NSObjectProtocol?

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
    startObserving()
    return nil
  }

  public func onCancel(withArguments arguments: Any?) -> FlutterError? {
    stopObserving()
    eventSink = nil
    return nil
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

    let path = volumePath(from: notification)
    eventSink([
      "type": type,
      "path": path,
    ])
  }

  private func volumePath(from notification: Notification) -> String? {
    if let volume = notification.userInfo?[NSWorkspace.volumeURLUserInfoKey] as? URL {
      return volume.path
    }

    if let volume = notification.userInfo?[NSWorkspace.volumeURLKey] as? URL {
      return volume.path
    }

    return nil
  }
}
