#include "mobile_storage_listener_plugin.h"

#include <VersionHelpers.h>

#include <flutter/standard_method_codec.h>

#include <algorithm>
#include <dbt.h>
#include <sstream>

namespace mobile_storage_listener {
namespace {

std::string WideToUtf8(const std::wstring& value) {
  if (value.empty()) {
    return "";
  }

  const int size_needed = WideCharToMultiByte(
      CP_UTF8, 0, value.c_str(), static_cast<int>(value.size()), nullptr, 0, nullptr, nullptr);
  std::string result(size_needed, '\0');
  WideCharToMultiByte(CP_UTF8, 0, value.c_str(), static_cast<int>(value.size()),
                      result.data(), size_needed, nullptr, nullptr);
  return result;
}

}  // namespace

void MobileStorageListenerPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows* registrar) {
  auto plugin = std::make_unique<MobileStorageListenerPlugin>();
  auto plugin_pointer = plugin.get();
  plugin->registrar_ = registrar;

  plugin->method_channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      registrar->messenger(), "mobile_storage_listener",
      &flutter::StandardMethodCodec::GetInstance());
  plugin->method_channel_->SetMethodCallHandler(
      [plugin_pointer](const auto& call, auto result) {
        plugin_pointer->HandleMethodCall(call, std::move(result));
      });

  plugin->event_channel_ = std::make_unique<flutter::EventChannel<flutter::EncodableValue>>(
      registrar->messenger(), "mobile_storage_listener/events",
      &flutter::StandardMethodCodec::GetInstance());
  plugin->stream_handler_ =
      std::make_unique<flutter::StreamHandlerFunctions<flutter::EncodableValue>>(
          [plugin_pointer](const flutter::EncodableValue* arguments,
                           std::unique_ptr<flutter::EventSink<flutter::EncodableValue>>&& events) {
            plugin_pointer->event_sink_ = std::move(events);
            plugin_pointer->StartMonitoring();
            return std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>>(nullptr);
          },
          [plugin_pointer](const flutter::EncodableValue* arguments) {
            plugin_pointer->StopMonitoring();
            plugin_pointer->event_sink_.reset();
            return std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>>(nullptr);
          });
  plugin->event_channel_->SetStreamHandler(std::move(plugin->stream_handler_));

  registrar->AddPlugin(std::move(plugin));
}

MobileStorageListenerPlugin::MobileStorageListenerPlugin() = default;

MobileStorageListenerPlugin::~MobileStorageListenerPlugin() {
  StopMonitoring();
}

void MobileStorageListenerPlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue>& method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (method_call.method_name().compare("getPlatformVersion") == 0) {
    std::ostringstream version_stream;
    version_stream << "Windows ";
    if (IsWindows10OrGreater()) {
      version_stream << "10+";
    } else if (IsWindows8OrGreater()) {
      version_stream << "8";
    } else if (IsWindows7OrGreater()) {
      version_stream << "7";
    }
    result->Success(flutter::EncodableValue(version_stream.str()));
    return;
  }

  result->NotImplemented();
}

void MobileStorageListenerPlugin::StartMonitoring() {
  if (monitoring_) {
    return;
  }

  known_drives_ = GetRemovableDrives();
  monitoring_ = true;

  if (registrar_ && window_proc_delegate_id_ == 0) {
    window_proc_delegate_id_ =
        registrar_->RegisterTopLevelWindowProcDelegate(
            [this](HWND hwnd, UINT message, WPARAM wparam, LPARAM lparam)
                -> std::optional<LRESULT> {
              return HandleWindowProc(hwnd, message, wparam, lparam);
            });
  }
}

void MobileStorageListenerPlugin::StopMonitoring() {
  monitoring_ = false;
  known_drives_.clear();

  if (registrar_ && window_proc_delegate_id_ != 0) {
    registrar_->UnregisterTopLevelWindowProcDelegate(window_proc_delegate_id_);
    window_proc_delegate_id_ = 0;
  }
}

std::optional<LRESULT> MobileStorageListenerPlugin::HandleWindowProc(
    HWND hwnd,
    UINT message,
    WPARAM wparam,
    LPARAM lparam) {
  if (!monitoring_ || message != WM_DEVICECHANGE) {
    return std::nullopt;
  }

  if (wparam == DBT_DEVICEARRIVAL || wparam == DBT_DEVICEREMOVECOMPLETE) {
    const auto* header = reinterpret_cast<const DEV_BROADCAST_HDR*>(lparam);
    if (!header || header->dbch_devicetype != DBT_DEVTYP_VOLUME) {
      return std::nullopt;
    }

    const auto* volume = reinterpret_cast<const DEV_BROADCAST_VOLUME*>(header);
    const DWORD unit_mask = volume->dbcv_unitmask;
    if (unit_mask == 0) {
      return std::nullopt;
    }

    const auto drives = GetDriveLettersFromMask(unit_mask);
    for (const auto& drive : drives) {
      const bool is_known_drive = IsKnownDrive(drive);
      if (wparam == DBT_DEVICEARRIVAL) {
        if (GetDriveTypeW(drive.c_str()) != DRIVE_REMOVABLE) {
          continue;
        }

        AddKnownDrive(drive);
        EmitEvent("mounted", WideToUtf8(drive));
        continue;
      }

      if (!is_known_drive) {
        continue;
      }

      EmitEvent("removed", WideToUtf8(drive));
      RemoveKnownDrive(drive);
    }

    return LRESULT{0};
  }

  return std::nullopt;
}

void MobileStorageListenerPlugin::EmitEvent(const std::string& type,
                                            const std::string& path) {
  if (!event_sink_) {
    return;
  }

  flutter::EncodableMap event;
  event[flutter::EncodableValue("type")] = flutter::EncodableValue(type);
  event[flutter::EncodableValue("path")] = flutter::EncodableValue(path);
  event_sink_->Success(flutter::EncodableValue(event));
}

std::vector<std::wstring> MobileStorageListenerPlugin::GetRemovableDrives() const {
  std::vector<std::wstring> drives;
  DWORD mask = GetLogicalDrives();
  const auto drive_letters = GetDriveLettersFromMask(mask);

  for (const auto& drive : drive_letters) {
    if (GetDriveTypeW(drive.c_str()) == DRIVE_REMOVABLE) {
      drives.push_back(drive);
    }
  }

  return drives;
}

std::vector<std::wstring> MobileStorageListenerPlugin::GetDriveLettersFromMask(
    DWORD unit_mask) const {
  std::vector<std::wstring> drives;

  for (int i = 0; i < 26; ++i) {
    if (!(unit_mask & (1 << i))) {
      continue;
    }

    wchar_t root_path[] = {static_cast<wchar_t>(L'A' + i), L':', L'\\', L'\0'};
    drives.emplace_back(root_path);
  }

  return drives;
}

bool MobileStorageListenerPlugin::IsKnownDrive(const std::wstring& drive) const {
  return std::find(known_drives_.begin(), known_drives_.end(), drive) != known_drives_.end();
}

void MobileStorageListenerPlugin::AddKnownDrive(const std::wstring& drive) {
  if (!IsKnownDrive(drive)) {
    known_drives_.push_back(drive);
  }
}

void MobileStorageListenerPlugin::RemoveKnownDrive(const std::wstring& drive) {
  known_drives_.erase(
      std::remove(known_drives_.begin(), known_drives_.end(), drive), known_drives_.end());
}

}  // namespace mobile_storage_listener
