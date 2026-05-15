#ifndef FLUTTER_PLUGIN_MOBILE_STORAGE_LISTENER_PLUGIN_H_
#define FLUTTER_PLUGIN_MOBILE_STORAGE_LISTENER_PLUGIN_H_

#include <flutter/encodable_value.h>
#include <flutter/event_channel.h>
#include <flutter/event_sink.h>
#include <flutter/event_stream_handler_functions.h>
#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>

#include <memory>
#include <optional>
#include <string>
#include <vector>

#include <windows.h>

namespace mobile_storage_listener {

class MobileStorageListenerPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows* registrar);

  MobileStorageListenerPlugin();
  ~MobileStorageListenerPlugin() override;

  MobileStorageListenerPlugin(const MobileStorageListenerPlugin&) = delete;
  MobileStorageListenerPlugin& operator=(const MobileStorageListenerPlugin&) = delete;

  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

 private:
  void StartMonitoring();
  void StopMonitoring();
  std::optional<LRESULT> HandleWindowProc(HWND hwnd,
                                          UINT message,
                                          WPARAM wparam,
                                          LPARAM lparam);
  void EmitEvent(const std::string& type, const std::string& path);
  std::vector<std::wstring> GetRemovableDrives() const;
  std::vector<std::wstring> GetDriveLettersFromMask(DWORD unit_mask) const;
  bool IsKnownDrive(const std::wstring& drive) const;
  void AddKnownDrive(const std::wstring& drive);
  void RemoveKnownDrive(const std::wstring& drive);

  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> method_channel_;
  std::unique_ptr<flutter::EventChannel<flutter::EncodableValue>> event_channel_;
  std::unique_ptr<flutter::StreamHandlerFunctions<flutter::EncodableValue>> stream_handler_;
  std::unique_ptr<flutter::EventSink<flutter::EncodableValue>> event_sink_;
  flutter::PluginRegistrarWindows* registrar_ = nullptr;
  int window_proc_delegate_id_ = 0;
  bool monitoring_ = false;
  std::vector<std::wstring> known_drives_;
};

}  // namespace mobile_storage_listener

#endif  // FLUTTER_PLUGIN_MOBILE_STORAGE_LISTENER_PLUGIN_H_
