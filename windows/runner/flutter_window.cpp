#include "flutter_window.h"
#include "HardwareStats.h"

#include <optional>
#include "flutter/generated_plugin_registrant.h"

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
        : project_(project) {}

FlutterWindow::~FlutterWindow() {
    StopStreamThread();
}

bool FlutterWindow::OnCreate() {
    if (!Win32Window::OnCreate()) return false;

    RECT frame = GetClientArea();
    flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
            frame.right - frame.left, frame.bottom - frame.top, project_);

    if (!flutter_controller_->engine() || !flutter_controller_->view()) return false;

    RegisterPlugins(flutter_controller_->engine());

    auto messenger = flutter_controller_->engine()->messenger();
    RegisterHardwareChannel(messenger);
    RegisterHardwareStreamChannel(messenger);

    run_loop_->RegisterFlutterInstance(flutter_controller_->engine());
    return true;
}

// ─────────────────────────────────────────────
// MethodChannel — individual on-demand calls
// ─────────────────────────────────────────────
void FlutterWindow::RegisterHardwareChannel(flutter::BinaryMessenger* messenger) {
    channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
            messenger,
                    "com.bytebuddy/hardware_stats",
                    &flutter::StandardMethodCodec::GetInstance());

    channel_->SetMethodCallHandler(
            [this](const flutter::MethodCall<flutter::EncodableValue>& call,
                   std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {

                const std::string& method = call.method_name();

                if      (method == "getSystemStats")   result->Success(flutter::EncodableValue(GetAllStats()));
                else if (method == "getCpuUsage")      result->Success(flutter::EncodableValue(GetCpuUsage()));
                else if (method == "getBatteryLevel")  result->Success(flutter::EncodableValue(GetBatteryLevel()));
                else if (method == "getMemoryUsage")   result->Success(flutter::EncodableValue(GetMemoryUsage()));
                else if (method == "getFanSpeed")      result->Success(flutter::EncodableValue(GetFanSpeed()));
                else if (method == "getCpuTemp")       result->Success(flutter::EncodableValue(GetCpuTemp()));
                else                                   result->NotImplemented();
            });
}

// ─────────────────────────────────────────────
// EventChannel — live push stream
// ─────────────────────────────────────────────
void FlutterWindow::RegisterHardwareStreamChannel(flutter::BinaryMessenger* messenger) {
    event_channel_ = std::make_unique<flutter::EventChannel<flutter::EncodableValue>>(
            messenger,
                    "com.bytebuddy/hardware_stats_stream",
                    &flutter::StandardMethodCodec::GetInstance());

    auto handler = std::make_unique<flutter::StreamHandlerFunctions<flutter::EncodableValue>>(
            // onListen — Dart subscribed, start pushing
            [this](const flutter::EncodableValue* arguments,
                   std::unique_ptr<flutter::EventSink<flutter::EncodableValue>>&& sink)
                    -> std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>>
            {
                // Default interval: 2000ms. Dart can pass an int arg to override.
                int intervalMs = 2000;
                if (arguments && std::holds_alternative<int>(*arguments)) {
                    intervalMs = std::get<int>(*arguments);
                }
                StartStreamThread(sink.release(), intervalMs);
                return nullptr;
            },
                    // onCancel — Dart unsubscribed, stop thread
                    [this](const flutter::EncodableValue* arguments)
                            -> std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>>
                    {
                        StopStreamThread();
                        return nullptr;
                    }
    );

    event_channel_->SetStreamHandler(std::move(handler));
}

void FlutterWindow::StartStreamThread(
        flutter::EventSink<flutter::EncodableValue>* sink,
        int intervalMs) {
    StopStreamThread(); // cancel any previous thread

    streaming_ = true;
    stream_thread_ = std::thread([this, sink, intervalMs]() {
        while (streaming_) {
            flutter::EncodableMap map;
            map[flutter::EncodableValue("cpuUsage")]     = flutter::EncodableValue(HardwareStats::GetCpuUsage());
            map[flutter::EncodableValue("batteryLevel")] = flutter::EncodableValue(HardwareStats::GetBatteryLevel());
            map[flutter::EncodableValue("memoryUsage")]  = flutter::EncodableValue(HardwareStats::GetMemoryUsageMB());
            map[flutter::EncodableValue("fanSpeed")]     = flutter::EncodableValue(HardwareStats::GetFanSpeed());
            map[flutter::EncodableValue("cpuTemp")]      = flutter::EncodableValue(HardwareStats::GetCpuTemperature());

            if (streaming_) {
                sink->Success(flutter::EncodableValue(map));
            }

            std::this_thread::sleep_for(std::chrono::milliseconds(intervalMs));
        }
        delete sink;
    });
}

void FlutterWindow::StopStreamThread() {
    streaming_ = false;
    if (stream_thread_.joinable()) {
        stream_thread_.join();
    }
}

// ─────────────────────────────────────────────
// Individual MethodChannel stat builders
// ─────────────────────────────────────────────
flutter::EncodableMap FlutterWindow::GetAllStats() {
    flutter::EncodableMap map;
    map[flutter::EncodableValue("cpuUsage")]     = flutter::EncodableValue(HardwareStats::GetCpuUsage());
    map[flutter::EncodableValue("batteryLevel")] = flutter::EncodableValue(HardwareStats::GetBatteryLevel());
    map[flutter::EncodableValue("memoryUsage")]  = flutter::EncodableValue(HardwareStats::GetMemoryUsageMB());
    map[flutter::EncodableValue("fanSpeed")]     = flutter::EncodableValue(HardwareStats::GetFanSpeed());
    map[flutter::EncodableValue("cpuTemp")]      = flutter::EncodableValue(HardwareStats::GetCpuTemperature());
    return map;
}

flutter::EncodableMap FlutterWindow::GetCpuUsage() {
    flutter::EncodableMap map;
    map[flutter::EncodableValue("cpuUsage")] = flutter::EncodableValue(HardwareStats::GetCpuUsage());
    return map;
}

flutter::EncodableMap FlutterWindow::GetBatteryLevel() {
    flutter::EncodableMap map;
    map[flutter::EncodableValue("batteryLevel")] = flutter::EncodableValue(HardwareStats::GetBatteryLevel());
    return map;
}

flutter::EncodableMap FlutterWindow::GetMemoryUsage() {
    flutter::EncodableMap map;
    map[flutter::EncodableValue("memoryUsage")] = flutter::EncodableValue(HardwareStats::GetMemoryUsageMB());
    return map;
}

flutter::EncodableMap FlutterWindow::GetFanSpeed() {
    flutter::EncodableMap map;
    map[flutter::EncodableValue("fanSpeed")] = flutter::EncodableValue(HardwareStats::GetFanSpeed());
    return map;
}

flutter::EncodableMap FlutterWindow::GetCpuTemp() {
    flutter::EncodableMap map;
    map[flutter::EncodableValue("cpuTemp")] = flutter::EncodableValue(HardwareStats::GetCpuTemperature());
    return map;
}

// ─────────────────────────────────────────────
// Window Lifecycle
// ─────────────────────────────────────────────
void FlutterWindow::OnDestroy() {
    StopStreamThread();
    if (flutter_controller_) flutter_controller_ = nullptr;
    Win32Window::OnDestroy();
}

LRESULT FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                                      WPARAM const wparam,
                                      LPARAM const lparam) noexcept {
if (flutter_controller_) {
std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam, lparam);
if (result) return *result;
}

switch (message) {
case WM_FONTCHANGE:
flutter_controller_->engine()->ReloadSystemFonts();
break;
}

return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}