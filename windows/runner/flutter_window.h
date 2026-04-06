#ifndef RUNNER_FLUTTER_WINDOW_H_
#define RUNNER_FLUTTER_WINDOW_H_

#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <flutter/method_channel.h>
#include <flutter/event_channel.h>
#include <flutter/event_sink.h>
#include <flutter/event_stream_handler_functions.h>
#include <flutter/standard_method_codec.h>
#include <flutter/encodable_value.h>

#include <memory>
#include <thread>
#include <atomic>
#include <chrono>

#include "run_loop.h"
#include "win32_window.h"

class FlutterWindow : public Win32Window {
public:
    explicit FlutterWindow(const flutter::DartProject& project);
    virtual ~FlutterWindow();

protected:
    bool OnCreate() override;
    void OnDestroy() override;
    LRESULT MessageHandler(HWND window, UINT const message,
                           WPARAM const wparam,
                           LPARAM const lparam) noexcept override;

private:
    // Channel registration
    void RegisterHardwareChannel(flutter::BinaryMessenger* messenger);
    void RegisterHardwareStreamChannel(flutter::BinaryMessenger* messenger);

    // MethodChannel individual handlers
    flutter::EncodableMap GetAllStats();
    flutter::EncodableMap GetCpuUsage();
    flutter::EncodableMap GetBatteryLevel();
    flutter::EncodableMap GetMemoryUsage();
    flutter::EncodableMap GetFanSpeed();
    flutter::EncodableMap GetCpuTemp();

    // Stream thread
    void StartStreamThread(flutter::EventSink<flutter::EncodableValue>* sink,
                           int intervalMs);
    void StopStreamThread();

    flutter::DartProject project_;
    std::unique_ptr<flutter::FlutterViewController> flutter_controller_;

    // MethodChannel (individual calls)
    std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;

    // EventChannel (live stream)
    std::unique_ptr<flutter::EventChannel<flutter::EncodableValue>> event_channel_;

    // Background stream thread state
    std::thread stream_thread_;
    std::atomic<bool> streaming_{ false };

    RunLoop* run_loop_;
};

#endif  // RUNNER_FLUTTER_WINDOW_H_