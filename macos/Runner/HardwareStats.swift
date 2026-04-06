//
//  HardwareStats.swift
//  Runner
//
//  Created by Danis Preldzic on 6. 4. 2026..
//

import Foundation
import IOKit
import IOKit.hid
import IOKit.hidsystem
import IOKit.ps
import IOKit.pwr_mgt

private typealias IOHIDEventRef = CFTypeRef

@_silgen_name("IOHIDEventSystemClientCreate")
private func IOHIDEventSystemClientCreateShim(
    _ allocator: CFAllocator?
) -> IOHIDEventSystemClient

@_silgen_name("IOHIDEventSystemClientSetMatching")
private func IOHIDEventSystemClientSetMatchingShim(
    _ client: IOHIDEventSystemClient,
    _ matching: CFDictionary
)

@_silgen_name("IOHIDServiceClientCopyEvent")
private func IOHIDServiceClientCopyEventShim(
    _ service: IOHIDServiceClient,
    _ type: Int64,
    _ options: Int32,
    _ timestamp: UInt64
) -> Unmanaged<IOHIDEventRef>?

@_silgen_name("IOHIDEventGetFloatValue")
private func IOHIDEventGetFloatValueShim(
    _ event: IOHIDEventRef,
    _ field: Int32
) -> Double

struct HardwareStats {

    // MARK: - CPU Usage

    static func getCPUUsage() -> Double {
        var cpuInfo: processor_info_array_t?
        var numCpuInfo: mach_msg_type_number_t = 0
        var numCPUs: natural_t = 0

        let err = host_processor_info(
            mach_host_self(),
            PROCESSOR_CPU_LOAD_INFO,
            &numCPUs,
            &cpuInfo,
            &numCpuInfo
        )

        guard err == KERN_SUCCESS, let cpuInfo = cpuInfo else {
            return 0.0
        }

        var totalUsage: Double = 0.0

        for i in 0..<Int(numCPUs) {
            let base   = Int32(CPU_STATE_MAX) * Int32(i)
            let user   = Double(cpuInfo[Int(base + Int32(CPU_STATE_USER))])
            let system = Double(cpuInfo[Int(base + Int32(CPU_STATE_SYSTEM))])
            let nice   = Double(cpuInfo[Int(base + Int32(CPU_STATE_NICE))])
            let idle   = Double(cpuInfo[Int(base + Int32(CPU_STATE_IDLE))])
            let total  = user + system + nice + idle
            totalUsage += (total > 0) ? ((user + system + nice) / total) * 100.0 : 0.0
        }

        vm_deallocate(
            mach_task_self_,
            vm_address_t(bitPattern: cpuInfo),
            vm_size_t(numCpuInfo) * vm_size_t(MemoryLayout<integer_t>.stride)
        )

        return totalUsage / Double(numCPUs)
    }

    // MARK: - Battery Level

    static func getBatteryLevel() -> Int {
        let snapshot = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let sources  = IOPSCopyPowerSourcesList(snapshot).takeRetainedValue() as Array

        for source in sources {
            if let info = IOPSGetPowerSourceDescription(snapshot, source)
                .takeUnretainedValue() as? [String: Any],
               let capacity = info[kIOPSCurrentCapacityKey] as? Int {
                return capacity
            }
        }

        // Desktop Mac / no battery
        return -1
    }

    // MARK: - Memory Usage (used RAM in MB)

    static func getMemoryUsage() -> Int {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size
        )

        let result: kern_return_t = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }

        guard result == KERN_SUCCESS else { return 0 }

        let pageSize   = UInt64(vm_kernel_page_size)
        let active     = UInt64(stats.active_count)          * pageSize
        let wired      = UInt64(stats.wire_count)            * pageSize
        let compressed = UInt64(stats.compressor_page_count) * pageSize
        let usedBytes  = active + wired + compressed

        return Int(usedBytes / 1024 / 1024) // MB
    }

    // MARK: - Fan Speed (RPM) via IOKit SMC

    static func getFanSpeed() -> Int {
        return SMCReader.shared.readFanSpeed()
    }

    // MARK: - CPU Temperature (°C) via IOKit SMC

    static func getCPUTemperature() -> Double {
        return SMCReader.shared.readCPUTemperature()
    }
}

// MARK: - SMC Reader

/// Reads SMC keys for fan speed and CPU temperature.
/// Supports both Intel and Apple Silicon (M1/M2/M3) Macs.
/// SMC access requires no entitlements on macOS for read-only sensor data.
final class SMCReader {

    static let shared = SMCReader()

    private struct SMCKeyValue {
        let bytes: [UInt8]
        let dataType: String
    }

    private enum HIDConstants {
        static let appleVendorUsagePage: UInt32 = 0xff00
        static let appleVendorTemperatureSensor: UInt32 = 0x05
        static let temperatureEventType: Int64 = 15

        static func eventFieldBase(for type: Int32) -> Int32 {
            type << 16
        }
    }

    private var conn: io_connect_t = 0

    /// Detected architecture, cached on first use.
    private let isAppleSilicon: Bool = {
        var sysinfo = utsname()
        uname(&sysinfo)
        let machine = withUnsafeBytes(of: &sysinfo.machine) { ptr -> String in
            let bytes = ptr.bindMemory(to: CChar.self)
            return String(cString: bytes.baseAddress!)
        }
        // Apple Silicon reports "arm64"; Intel reports "x86_64"
        return machine.contains("arm64")
    }()

    private init() {
        open()
    }

    deinit {
        close()
    }

    // MARK: - Open / Close

    private func open() {
        let service = IOServiceGetMatchingService(
            kIOMasterPortDefault,
            IOServiceMatching("AppleSMC")
        )
        guard service != IO_OBJECT_NULL else {
            print("SMC: AppleSMC service not found")
            return
        }
        let ret = IOServiceOpen(service, mach_task_self_, 0, &conn)
        IOObjectRelease(service)
        if ret != KERN_SUCCESS {
            print("SMC: IOServiceOpen failed with code \(ret)")
        } else {
            print("SMC: connection opened, conn=\(conn)")
        }
    }

    private func close() {
        if conn != 0 { IOServiceClose(conn) }
    }

    // MARK: - Public Reads

    func readFanSpeed() -> Int {
        if isAppleSilicon {
            return readFanSpeedAppleSilicon()
        } else {
            return readFanSpeedIntel()
        }
    }

    func readCPUTemperature() -> Double {
        if isAppleSilicon {
            return readCPUTemperatureAppleSilicon()
        } else {
            return readCPUTemperatureIntel()
        }
    }

    // MARK: - Intel Fan Speed

    /// Intel Macs use FP2.14 encoded fan RPM under keys "F0Ac", "F1Ac", etc.
    private func readFanSpeedIntel() -> Int {
        let keys = ["F0Ac", "F1Ac"]
        for key in keys {
            if let keyValue = readKeyValue(key),
               let rpm = decodeFanRPM(keyValue) {
                if rpm > 0 { return rpm }
            }
        }
        return -1
    }

    // MARK: - Apple Silicon Fan Speed

    /// Apple Silicon Macs still use the same FP2.14 fan keys, but the
    /// physical fan count and key availability differs per model.
    /// M2 MacBook Pro (14"/16") typically has two fans: F0Ac and F1Ac.
    /// M2 MacBook Air is fanless — returns -1 intentionally.
    private func readFanSpeedAppleSilicon() -> Int {
        // Probe both actual and target fan keys since availability varies by model.
        let fanKeys = ["F0Ac", "F1Ac", "F2Ac", "F0Tg", "F1Tg", "F2Tg"]
        var maxRPM = 0

        for key in fanKeys {
            if let keyValue = readKeyValue(key),
               let rpm = decodeFanRPM(keyValue) {
                if rpm > maxRPM { maxRPM = rpm }
            }
        }

        return maxRPM > 0 ? maxRPM : -1
    }

    // MARK: - Intel CPU Temperature

    /// Intel die / proximity sensor keys.
    private func readCPUTemperatureIntel() -> Double {
        let keys = ["TC0D", "TC0P", "TC0E", "TC0F"]
        for key in keys {
            if let keyValue = readKeyValue(key),
               let temp = decodeTemperatureCelsius(keyValue) {
                if temp > 0 && temp < 150 { return temp }
            }
        }
        return -1.0
    }

    // MARK: - Apple Silicon CPU Temperature

    /// Apple Silicon thermal keys vary by chip generation and model.
    /// Keys are tried in priority order; the first sane reading wins.
    ///
    /// Key reference:
    ///   Tp01 – efficiency-core cluster (E-cluster) temp
    ///   Tp05 – performance-core cluster (P-cluster) temp
    ///   Tp0D – CPU die temp (M1 Pro/Max/M2 Pro/Max)
    ///   Tp0b – CPU temp variant (some M2 models)
    ///   Tp09 – CPU temp (M1/M2 base)
    ///   TpAV – CPU average temp (reported on some M2 MacBook Pros)
    ///   TC0p – compatibility alias present on some Apple Silicon SKUs
    private func readCPUTemperatureAppleSilicon() -> Double {
        if let hidTemperature = readAppleSiliconHIDTemperature() {
            return hidTemperature
        }

        let keys = ["Tp05", "Tp0D", "Tp01", "Tp0b", "Tp09", "TpAV", "TC0p", "TCP0"]
        for key in keys {
            if let keyValue = readKeyValue(key),
               let temp = decodeTemperatureCelsius(keyValue) {
                if temp > 0 && temp < 150 { return temp }
            }
        }
        return -1.0
    }

    /// Apple Silicon exposes many thermal sensors via the HID event system.
    /// Prefer the CPU-cluster sensors when available; otherwise fall back to
    /// the warmest generic PMU temperature sensor so the UI still gets a value.
    private func readAppleSiliconHIDTemperature() -> Double? {
        let client = IOHIDEventSystemClientCreateShim(kCFAllocatorDefault)
        let matching: [String: Any] = [
            kIOHIDPrimaryUsagePageKey: HIDConstants.appleVendorUsagePage,
            kIOHIDPrimaryUsageKey: HIDConstants.appleVendorTemperatureSensor
        ]
        IOHIDEventSystemClientSetMatchingShim(client, matching as CFDictionary)

        guard let services = IOHIDEventSystemClientCopyServices(client) else {
            return nil
        }

        let serviceArray = services as NSArray
        var preferredTemps: [Double] = []
        var fallbackTemps: [Double] = []

        for index in 0..<serviceArray.count {
            let service = serviceArray[index] as! IOHIDServiceClient

            guard IOHIDServiceClientConformsTo(
                service,
                HIDConstants.appleVendorUsagePage,
                HIDConstants.appleVendorTemperatureSensor
            ) != 0 else {
                continue
            }

            guard let product = IOHIDServiceClientCopyProperty(
                service,
                kIOHIDProductKey as CFString
            ) as? String else {
                continue
            }

            guard let event = IOHIDServiceClientCopyEventShim(
                service,
                HIDConstants.temperatureEventType,
                0,
                0
            )?.takeRetainedValue() else {
                continue
            }

            let temp = IOHIDEventGetFloatValueShim(
                event,
                HIDConstants.eventFieldBase(
                    for: Int32(HIDConstants.temperatureEventType)
                )
            )

            guard temp > 0, temp < 150 else {
                continue
            }

            if product.hasPrefix("pACC MTR Temp Sensor")
                || product.hasPrefix("eACC MTR Temp Sensor")
                || product.hasPrefix("PMU tcal") {
                preferredTemps.append(temp)
            } else if product.hasPrefix("PMU t") {
                fallbackTemps.append(temp)
            }
        }

        if !preferredTemps.isEmpty {
            return preferredTemps.reduce(0, +) / Double(preferredTemps.count)
        }

        if !fallbackTemps.isEmpty {
            return fallbackTemps.max()
        }

        return nil
    }

    // MARK: - Debug Helper

    /// Prints all probed SMC keys and their decoded values to the console.
    /// Call this once during development to identify which keys are active
    /// on the current machine.
    func debugAvailableKeys() {
        let allKeys = [
            // Fan
            "F0Ac", "F1Ac", "F2Ac", "FS! ", "FNum", "F0Tg", "F1Tg",
            // Intel thermal
            "TC0D", "TC0P", "TC0E", "TC0F",
            // Apple Silicon thermal
            "Tp01", "Tp05", "Tp09", "Tp0D", "Tp0b", "TpAV",
            "TC0p", "TCP0", "TaLP", "TaRF", "PMuj", "PMVR"
        ]

        print("=== SMC Debug [\(isAppleSilicon ? "Apple Silicon" : "Intel")] ===")
        for key in allKeys {
            if let keyValue = readKeyValue(key) {
                print(String(
                    format: "  %-6@ type=%-4@ raw=%-30@ temp=%.2f  fan=%.2f",
                    key as NSString,
                    keyValue.dataType as NSString,
                    keyValue.bytes.map { String(format: "%02X", $0) }.joined(separator: " ") as NSString,
                    decodeTemperatureCelsius(keyValue) ?? -1,
                    decodeFanRPMValue(keyValue) ?? -1
                ))
            }
        }
        print("==========================================")
    }

    // MARK: - SMC Key Read Infrastructure

    private struct SMCKeyData {
        var key: UInt32 = 0
        var vers         = SMCVers()
        var pLimitData   = SMCPLimitData()
        var keyInfo      = SMCKeyInfoData()
        var result:  UInt8  = 0
        var status:  UInt8  = 0
        var data8:   UInt8  = 0
        var data32:  UInt32 = 0
        var bytes: (UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,
                    UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,
                    UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,
                    UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8) =
            (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)
    }

    private struct SMCVers        { var major: UInt8 = 0; var minor: UInt8 = 0; var build: UInt8 = 0; var reserved: UInt8 = 0; var release: UInt16 = 0 }
    private struct SMCPLimitData  { var version: UInt16 = 0; var length: UInt16 = 0; var cpuPLimit: UInt32 = 0; var gpuPLimit: UInt32 = 0; var memPLimit: UInt32 = 0 }
    private struct SMCKeyInfoData { var dataSize: UInt32 = 0; var dataType: UInt32 = 0; var dataAttributes: UInt8 = 0 }

    private func fourCC(_ s: String) -> UInt32 {
        var result: UInt32 = 0
        for char in s.utf8 { result = result << 8 | UInt32(char) }
        return result
    }

    private func readKeyValue(_ key: String) -> SMCKeyValue? {
        guard conn != 0 else { return nil }

        var inputStruct  = SMCKeyData()
        var outputStruct = SMCKeyData()

        // Step 1: get key info
        inputStruct.key   = fourCC(key)
        inputStruct.data8 = 9 // kSMCGetKeyInfo

        let inputSize  = MemoryLayout<SMCKeyData>.size
        var outputSize = MemoryLayout<SMCKeyData>.size

        let r1 = withUnsafeMutablePointer(to: &inputStruct) { inp in
            withUnsafeMutablePointer(to: &outputStruct) { out in
                IOConnectCallStructMethod(conn, 2, inp, inputSize, out, &outputSize)
            }
        }
        guard r1 == KERN_SUCCESS else { return nil }

        let dataSize = outputStruct.keyInfo.dataSize
        let dataType = fourCCString(outputStruct.keyInfo.dataType)

        // Step 2: read key value
        inputStruct  = SMCKeyData()
        outputStruct = SMCKeyData()
        inputStruct.key              = fourCC(key)
        inputStruct.keyInfo.dataSize = dataSize
        inputStruct.data8            = 5 // kSMCReadKey

        let r2 = withUnsafeMutablePointer(to: &inputStruct) { inp in
            withUnsafeMutablePointer(to: &outputStruct) { out in
                IOConnectCallStructMethod(conn, 2, inp, inputSize, out, &outputSize)
            }
        }
        guard r2 == KERN_SUCCESS else { return nil }

        let bytes = Mirror(reflecting: outputStruct.bytes)
            .children
            .prefix(Int(dataSize))
            .compactMap { $0.value as? UInt8 }

        return SMCKeyValue(bytes: bytes, dataType: dataType)
    }

    // MARK: - Type Conversions

    private func fourCCString(_ value: UInt32) -> String {
        let bytes: [UInt8] = [
            UInt8((value >> 24) & 0xFF),
            UInt8((value >> 16) & 0xFF),
            UInt8((value >> 8) & 0xFF),
            UInt8(value & 0xFF)
        ]
        return String(bytes: bytes, encoding: .ascii) ?? ""
    }

    private func decodeFanRPM(_ keyValue: SMCKeyValue) -> Int? {
        guard let rpm = decodeFanRPMValue(keyValue) else {
            return nil
        }
        let rounded = Int(rpm.rounded())
        return rounded > 0 ? rounded : nil
    }

    private func decodeFanRPMValue(_ keyValue: SMCKeyValue) -> Double? {
        switch keyValue.dataType {
        case "fpe2":
            return Double(fpe2ToFloat(keyValue.bytes))
        case "ui16":
            return Double(readUInt16(keyValue.bytes))
        default:
            if keyValue.bytes.count >= 2 {
                return Double(fpe2ToFloat(keyValue.bytes))
            }
            return nil
        }
    }

    private func decodeTemperatureCelsius(_ keyValue: SMCKeyValue) -> Double? {
        switch keyValue.dataType {
        case "sp78":
            return Double(sp78ToFloat(keyValue.bytes))
        case "flt ":
            return Double(float32ToFloat(keyValue.bytes))
        default:
            if keyValue.bytes.count == 2 {
                return Double(sp78ToFloat(keyValue.bytes))
            }
            if keyValue.bytes.count == 4 {
                return Double(float32ToFloat(keyValue.bytes))
            }
            return nil
        }
    }

    /// Fixed-point 14.2 → Float  (used for fan RPM SMC keys such as F0Ac/F1Ac)
    private func fpe2ToFloat(_ bytes: [UInt8]) -> Float {
        guard bytes.count >= 2 else { return 0 }
        let raw = UInt16(bytes[0]) << 8 | UInt16(bytes[1])
        return Float(raw) / 4.0
    }

    /// SP78 (signed fixed-point 7.8) → Float  (used for temperatures on both architectures)
    private func sp78ToFloat(_ bytes: [UInt8]) -> Float {
        guard bytes.count >= 2 else { return 0 }
        let raw = Int16(bitPattern: UInt16(bytes[0]) << 8 | UInt16(bytes[1]))
        return Float(raw) / 256.0
    }

    private func float32ToFloat(_ bytes: [UInt8]) -> Float {
        guard bytes.count >= 4 else { return 0 }
        let bits = bytes.prefix(4).reduce(UInt32(0)) { partial, byte in
            (partial << 8) | UInt32(byte)
        }
        return Float(bitPattern: bits)
    }

    private func readUInt16(_ bytes: [UInt8]) -> UInt16 {
        guard bytes.count >= 2 else { return 0 }
        return UInt16(bytes[0]) << 8 | UInt16(bytes[1])
    }
}
