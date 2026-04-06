import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {

    // Stream state
    private var streamTimer: Timer?
    private var eventSink: FlutterEventSink?

    override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }

    override func applicationDidFinishLaunching(_ notification: Notification) {
        let controller = mainFlutterWindow?.contentViewController as! FlutterViewController
        let messenger  = controller.engine.binaryMessenger

        registerHardwareChannel(messenger: messenger)
        registerHardwareStreamChannel(messenger: messenger)

        super.applicationDidFinishLaunching(notification)
    }

    // ─────────────────────────────────────────────
    // MethodChannel — individual on-demand calls
    // ─────────────────────────────────────────────
    private func registerHardwareChannel(messenger: FlutterBinaryMessenger) {
        let channel = FlutterMethodChannel(
            name: "com.bytebuddy/hardware_stats",
            binaryMessenger: messenger
        )

        channel.setMethodCallHandler { [weak self] call, result in
            guard let self else { return }
            switch call.method {
            case "getSystemStats":    result(self.getAllStats())
            case "getCpuUsage":       result(self.getCpuUsage())
            case "getBatteryLevel":   result(self.getBatteryLevel())
            case "getMemoryUsage":    result(self.getMemoryUsage())
            case "getFanSpeed":       result(self.getFanSpeed())
            case "getCpuTemp",
                 "getCpuTemperature": result(self.getCpuTemperature())
            default:                  result(FlutterMethodNotImplemented)
            }
        }
    }

    // ─────────────────────────────────────────────
    // EventChannel — live push stream
    // ─────────────────────────────────────────────
    private func registerHardwareStreamChannel(messenger: FlutterBinaryMessenger) {
        let eventChannel = FlutterEventChannel(
            name: "com.bytebuddy/hardware_stats_stream",
            binaryMessenger: messenger
        )
        eventChannel.setStreamHandler(self)
    }

    private func startStream(intervalMs: Int) {
        let interval = TimeInterval(intervalMs) / 1000.0

        streamTimer = Timer.scheduledTimer(
            withTimeInterval: interval,
            repeats: true
        ) { [weak self] _ in
            guard let self, let sink = self.eventSink else { return }
            sink(self.getAllStats())
        }

        // Fire immediately so Dart gets data right away
        eventSink?(getAllStats())
    }

    private func stopStream() {
        streamTimer?.invalidate()
        streamTimer = nil
        eventSink   = nil
    }

    // ─────────────────────────────────────────────
    // Individual stat builders
    // ─────────────────────────────────────────────
    private func buildStatsSnapshot() -> [String: Any] {
        let cpuTemperature = HardwareStats.getCPUTemperature()

        return [
            "cpuUsage": HardwareStats.getCPUUsage(),
            "batteryLevel": HardwareStats.getBatteryLevel(),
            "memoryUsage": HardwareStats.getMemoryUsage(),
            "fanSpeed": HardwareStats.getFanSpeed(),
            // Keep both keys while Dart migrates to the more explicit name.
            "cpuTemp": cpuTemperature,
            "cpuTemperature": cpuTemperature
        ]
    }

    private func getAllStats()      -> [String: Any] { buildStatsSnapshot() }
    private func getCpuUsage()      -> [String: Any] { ["cpuUsage": HardwareStats.getCPUUsage()] }
    private func getBatteryLevel()  -> [String: Any] { ["batteryLevel": HardwareStats.getBatteryLevel()] }
    private func getMemoryUsage()   -> [String: Any] { ["memoryUsage": HardwareStats.getMemoryUsage()] }
    private func getFanSpeed()      -> [String: Any] { ["fanSpeed": HardwareStats.getFanSpeed()] }
    private func getCpuTemperature() -> [String: Any] {
        let snapshot = buildStatsSnapshot()
        return [
            "cpuTemp": snapshot["cpuTemp"] as Any,
            "cpuTemperature": snapshot["cpuTemperature"] as Any
        ]
    }
}

// ─────────────────────────────────────────────
// FlutterStreamHandler — EventChannel delegate
// ─────────────────────────────────────────────
extension AppDelegate: FlutterStreamHandler {

    /// Called when Dart calls listen() on the stream
    func onListen(
        withArguments arguments: Any?,
        eventSink events: @escaping FlutterEventSink
    ) -> FlutterError? {
        self.eventSink = events

        // Dart can pass an interval in ms as an argument; default 2000
        let intervalMs = (arguments as? Int) ?? 2000
        startStream(intervalMs: intervalMs)
        return nil
    }

    /// Called when Dart cancels the stream subscription
    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        stopStream()
        return nil
    }
}
