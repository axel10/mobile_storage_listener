#if os(iOS)
import Flutter
import UIKit
import AVFoundation
#elseif os(macOS)
import Cocoa
import FlutterMacOS
#endif

public class MobileStorageListenerPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
  private var eventSink: FlutterEventSink?

  #if os(macOS)
  private var mountObserver: NSObjectProtocol?
  private var unmountObserver: NSObjectProtocol?
  private var knownDrives = Set<String>()
  #elseif os(iOS)
  private var discoverySessionObserver: NSKeyValueObservation?
  private var knownDevices = Set<String>()
  #endif

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
      #if os(iOS)
      result("iOS " + UIDevice.current.systemVersion)
      #elseif os(macOS)
      result("macOS " + ProcessInfo.processInfo.operatingSystemVersionString)
      #endif
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  public func onListen(
    withArguments arguments: Any?,
    eventSink events: @escaping FlutterEventSink
  ) -> FlutterError? {
    eventSink = events
    #if os(macOS)
    populateKnownDrives()
    startObserving()
    #elseif os(iOS)
    if #available(iOS 17.0, *) {
      populateKnownDevices()
      startObserving()
    }
    #endif
    return nil
  }

  public func onCancel(withArguments arguments: Any?) -> FlutterError? {
    #if os(macOS)
    stopObserving()
    knownDrives.removeAll()
    #elseif os(iOS)
    if #available(iOS 17.0, *) {
      stopObserving()
      knownDevices.removeAll()
    }
    #endif
    eventSink = nil
    return nil
  }

  #if os(macOS)
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
  #endif

  #if os(iOS)
  @available(iOS 17.0, *)
  private func populateKnownDevices() {
    knownDevices.removeAll()
    guard AVExternalStorageDeviceDiscoverySession.isSupported,
          let session = AVExternalStorageDeviceDiscoverySession.shared else {
      return
    }
    for device in session.externalStorageDevices {
      if let uuidString = device.uuid?.uuidString {
        knownDevices.insert(uuidString)
      }
    }
  }

  @available(iOS 17.0, *)
  private func startObserving() {
    guard AVExternalStorageDeviceDiscoverySession.isSupported,
          let session = AVExternalStorageDeviceDiscoverySession.shared else {
      return
    }
    
    discoverySessionObserver = session.observe(\.externalStorageDevices, options: [.new]) { [weak self] session, change in
      self?.handleDeviceChange(session.externalStorageDevices)
    }
  }

  @available(iOS 17.0, *)
  private func stopObserving() {
    discoverySessionObserver = nil
  }

  @available(iOS 17.0, *)
  private func handleDeviceChange(_ currentDevices: [AVExternalStorageDevice]) {
    guard let eventSink else {
      return
    }

    let currentUUIDs = Set(currentDevices.compactMap { $0.uuid?.uuidString })

    let mountedUUIDs = currentUUIDs.subtracting(knownDevices)
    for uuid in mountedUUIDs {
      knownDevices.insert(uuid)
      eventSink([
        "type": "mounted",
        "path": uuid,
      ])
    }

    let unmountedUUIDs = knownDevices.subtracting(currentUUIDs)
    for uuid in unmountedUUIDs {
      knownDevices.remove(uuid)
      eventSink([
        "type": "unmounted",
        "path": uuid,
      ])
    }
  }
  #endif
}
