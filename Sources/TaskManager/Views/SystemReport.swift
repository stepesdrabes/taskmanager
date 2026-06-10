import AppKit
import Darwin
import Foundation
import IOKit
import Metal
import SystemConfiguration

/// A flat, searchable set of static system facts. Built on the main actor
/// because some sources (NSScreen, Metal) are main-actor only; this is a
/// one-shot read, not part of the 1 Hz sampler.
struct SystemReport {
    struct Row: Identifiable {
        let label: String
        let value: String
        var id: String { label }
    }

    struct Section: Identifiable {
        let title: String
        let rows: [Row]
        var id: String { title }
    }

    let sections: [Section]

    /// Keeps rows whose label or value contains `query`; drops empty sections.
    func filtered(by query: String) -> [Section] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return sections }
        return sections.compactMap { section in
            let rows = section.rows.filter {
                $0.label.localizedCaseInsensitiveContains(trimmed)
                    || $0.value.localizedCaseInsensitiveContains(trimmed)
            }
            return rows.isEmpty ? nil : Section(title: section.title, rows: rows)
        }
    }

    static func gather(system: SystemInfo) -> SystemReport {
        var sections: [Section] = []
        func section(_ title: String, _ rows: [Row?]) {
            let filled = rows.compactMap { $0 }
            if !filled.isEmpty { sections.append(Section(title: title, rows: filled)) }
        }

        section("Overview", [
            row("Model", marketingName()),
            row("Model Identifier", Sysctl.string("hw.model")),
            row("Model Number", modelNumber()),
            row("Chip", system.chipName),
            row("Memory", Format.bytes(system.memoryTotal)),
            row("Serial Number", ioPlatformString("IOPlatformSerialNumber")),
            row("Hardware UUID", ioPlatformString("IOPlatformUUID")),
        ])

        section("Processor", [
            row("Chip", system.chipName),
            row("Total Cores", "\(system.pCoreCount + system.eCoreCount)"),
            row("\(system.pCoreName) Cores", system.pCoreCount > 0 ? "\(system.pCoreCount)" : nil),
            row("\(system.eCoreName) Cores", system.eCoreCount > 0 ? "\(system.eCoreCount)" : nil),
            row("L1 Cache (\(system.pCoreName))", "\(Format.bytes(system.pCoreL1i)) + \(Format.bytes(system.pCoreL1d))"),
            row("L2 Cache (\(system.pCoreName))", Format.bytes(system.pCoreL2)),
            row("L1 Cache (\(system.eCoreName))", "\(Format.bytes(system.eCoreL1i)) + \(Format.bytes(system.eCoreL1d))"),
            row("L2 Cache (\(system.eCoreName))", Format.bytes(system.eCoreL2)),
            row("Cache Line", Sysctl.int("hw.cachelinesize").map { "\($0) bytes" }),
            row("Byte Order", Sysctl.int("hw.byteorder").map { $0 == 1234 ? "Little Endian" : "Big Endian" }),
            row("Page Size", "\(system.pageSize / 1024) KB"),
            row("64-bit", (Sysctl.int("hw.cpu64bit_capable") ?? 0) == 1 ? "Yes" : "No"),
        ])

        section("Graphics", graphicsRows(system: system))

        for (index, screen) in NSScreen.screens.enumerated() {
            section(displayTitle(screen, index: index), displayRows(screen))
        }

        section("Memory", [
            row("Total", Format.bytes(system.memoryTotal)),
            row("Type", deviceTreeString("IODeviceTree:/chosen", "dram-type")),
            row("Manufacturer", deviceTreeString("IODeviceTree:/chosen", "dram-vendor")),
            row("Page Size", "\(system.pageSize / 1024) KB"),
        ])

        section("Storage", storageRows())

        section("Operating System", [
            row("macOS", osVersion()),
            row("Build", Sysctl.string("kern.osversion")),
            row("Kernel", kernelVersion()),
            row("Uptime", Format.uptime(since: system.bootTime)),
            row("Architecture", architecture()),
        ])

        section("Network", networkRows())

        section("Battery", batteryRows())

        section("Environment", [
            row("User", "\(NSFullUserName()) (\(NSUserName()))"),
            row("Shell", ProcessInfo.processInfo.environment["SHELL"]),
            row("Locale", Locale.current.identifier),
            row("Time Zone", TimeZone.current.identifier),
            row("Thermal State", thermalState()),
            row("Low Power Mode", ProcessInfo.processInfo.isLowPowerModeEnabled ? "On" : "Off"),
        ])

        return SystemReport(sections: sections)
    }
}

private func row(_ label: String, _ value: String?) -> SystemReport.Row? {
    value.map { SystemReport.Row(label: label, value: $0) }
}

// MARK: - Graphics

private func graphicsRows(system: SystemInfo) -> [SystemReport.Row?] {
    let device = MTLCreateSystemDefaultDevice()
    return [
        row("GPU", system.gpuName ?? device?.name),
        row("GPU Cores", system.gpuCoreCount.map { "\($0)" }),
        row("Metal Support", device.map(metalFamily)),
        row("Unified Memory", device.map { $0.hasUnifiedMemory ? "Yes" : "No" }),
        row("Recommended VRAM", device.map { Format.bytes(UInt64($0.recommendedMaxWorkingSetSize)) }),
    ]
}

private func metalFamily(_ device: MTLDevice) -> String {
    var parts: [String] = []
    if device.supportsFamily(.apple9) { parts.append("Apple 9") }
    else if device.supportsFamily(.apple8) { parts.append("Apple 8") }
    else if device.supportsFamily(.apple7) { parts.append("Apple 7") }
    if device.supportsFamily(.metal3) { parts.append("Metal 3") }
    return parts.isEmpty ? "Supported" : parts.joined(separator: ", ")
}

// MARK: - Displays

private func displayTitle(_ screen: NSScreen, index: Int) -> String {
    "Display — \(screen.localizedName)"
}

private func displayRows(_ screen: NSScreen) -> [SystemReport.Row?] {
    let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID ?? 0
    let pixels = screen.convertRectToBacking(screen.frame).size
    let edrHeadroom = screen.maximumPotentialExtendedDynamicRangeColorComponentValue
    let physical = CGDisplayScreenSize(displayID)
    return [
        row("Resolution", "\(Int(screen.frame.width)) × \(Int(screen.frame.height)) points"),
        row("Pixels", "\(Int(pixels.width)) × \(Int(pixels.height))"),
        row("Scale", String(format: "%.1f×", screen.backingScaleFactor)),
        row("Refresh Rate", screen.maximumFramesPerSecond > 0 ? "\(screen.maximumFramesPerSecond) Hz" : nil),
        row("Color Space", screen.colorSpace?.localizedName),
        row("Built-in", CGDisplayIsBuiltin(displayID) != 0 ? "Yes" : "No"),
        row("Physical Size", physical.width > 0 ? "\(Int(physical.width)) × \(Int(physical.height)) mm" : nil),
        row("HDR", edrHeadroom > 1 ? "Yes (×\(String(format: "%.0f", edrHeadroom)) headroom)" : "No"),
    ]
}

// MARK: - Storage

private func storageRows() -> [SystemReport.Row?] {
    let keys: [URLResourceKey] = [
        .volumeNameKey, .volumeLocalizedFormatDescriptionKey, .volumeTotalCapacityKey,
        .volumeAvailableCapacityForImportantUsageKey, .volumeIsInternalKey,
    ]
    guard let values = try? URL(fileURLWithPath: "/").resourceValues(forKeys: Set(keys)) else { return [] }
    return [
        row("Boot Volume", values.volumeName),
        row("File System", values.volumeLocalizedFormatDescription),
        row("Capacity", values.volumeTotalCapacity.map { Format.storageBytes(UInt64($0)) }),
        row("Available", values.volumeAvailableCapacityForImportantUsage.map { Format.storageBytes(UInt64(max($0, 0))) }),
        row("Internal", values.volumeIsInternal.map { $0 ? "Yes" : "No" }),
    ]
}

// MARK: - Operating system

private func osVersion() -> String {
    let version = Sysctl.string("kern.osproductversion") ?? "\(ProcessInfo.processInfo.operatingSystemVersion.majorVersion)"
    let major = ProcessInfo.processInfo.operatingSystemVersion.majorVersion
    let name = macOSName(major)
    return name.isEmpty ? version : "\(name) \(version)"
}

private func macOSName(_ major: Int) -> String {
    switch major {
    case 26: "Tahoe"
    case 15: "Sequoia"
    case 14: "Sonoma"
    case 13: "Ventura"
    case 12: "Monterey"
    case 11: "Big Sur"
    default: ""
    }
}

private func kernelVersion() -> String? {
    guard let type = Sysctl.string("kern.ostype"), let release = Sysctl.string("kern.osrelease") else { return nil }
    return "\(type) \(release)"
}

private func architecture() -> String {
    let translated = Sysctl.int("sysctl.proc_translated")
    return translated == 1 ? "Apple Silicon (running under Rosetta)" : "Apple Silicon (arm64)"
}

private func thermalState() -> String {
    switch ProcessInfo.processInfo.thermalState {
    case .nominal: "Nominal"
    case .fair: "Fair"
    case .serious: "Serious"
    case .critical: "Critical"
    @unknown default: "Unknown"
    }
}

// MARK: - Network

private func networkRows() -> [SystemReport.Row?] {
    let primary = primaryInterface()
    return [
        row("Computer Name", Host.current().localizedName),
        row("Local Hostname", ProcessInfo.processInfo.hostName),
        row("Primary Interface", primary),
        row("IP Address", primary.flatMap(ipv4Address)),
        row("MAC Address", primary.flatMap(macAddress)),
    ]
}

private func primaryInterface() -> String? {
    (SCDynamicStoreCopyValue(nil, "State:/Network/Global/IPv4" as CFString) as? [String: Any])?["PrimaryInterface"] as? String
}

private func ipv4Address(of interface: String) -> String? {
    var list: UnsafeMutablePointer<ifaddrs>?
    guard getifaddrs(&list) == 0 else { return nil }
    defer { freeifaddrs(list) }
    var pointer = list
    while let current = pointer {
        defer { pointer = current.pointee.ifa_next }
        guard String(cString: current.pointee.ifa_name) == interface,
              let addr = current.pointee.ifa_addr,
              addr.pointee.sa_family == sa_family_t(AF_INET) else { continue }
        var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
        if getnameinfo(addr, socklen_t(addr.pointee.sa_len), &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST) == 0 {
            return String(cString: &host)
        }
    }
    return nil
}

private func macAddress(of interface: String) -> String? {
    var list: UnsafeMutablePointer<ifaddrs>?
    guard getifaddrs(&list) == 0 else { return nil }
    defer { freeifaddrs(list) }
    var pointer = list
    while let current = pointer {
        defer { pointer = current.pointee.ifa_next }
        guard String(cString: current.pointee.ifa_name) == interface,
              let addr = current.pointee.ifa_addr,
              addr.pointee.sa_family == sa_family_t(AF_LINK) else { continue }
        let bytes = addr.withMemoryRebound(to: sockaddr_dl.self, capacity: 1) { dl -> [UInt8] in
            let nameLen = Int(dl.pointee.sdl_nlen)
            let addrLen = Int(dl.pointee.sdl_alen)
            guard addrLen == 6 else { return [] }
            return withUnsafeBytes(of: dl.pointee.sdl_data) { raw in
                (0..<addrLen).map { raw.load(fromByteOffset: nameLen + $0, as: UInt8.self) }
            }
        }
        guard bytes.count == 6 else { return nil }
        return bytes.map { String(format: "%02x", $0) }.joined(separator: ":")
    }
    return nil
}

// MARK: - Battery (static identity only — live state lives in the Energy tab)

private func batteryRows() -> [SystemReport.Row?] {
    guard let battery = registryProperties("AppleSmartBattery"),
          battery["BatteryInstalled"] as? Bool ?? false else { return [] }
    return [
        row("Cycle Count", (battery["CycleCount"] as? Int).map { "\($0)" }),
        row("Design Cycle Limit", (battery["DesignCycleCount9C"] as? Int).map { "\($0)" }),
        row("Design Capacity", (battery["DesignCapacity"] as? Int).map { "\($0) mAh" }),
        row("Battery Serial", battery["Serial"] as? String),
    ]
}

// MARK: - IORegistry helpers

private func modelNumber() -> String? {
    guard let number = ioPlatformString("model-number") else { return nil }
    if let region = ioPlatformString("region-info") { return number + region }
    return number
}

private func ioPlatformString(_ key: String) -> String? {
    let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPlatformExpertDevice"))
    guard service != 0 else { return nil }
    defer { IOObjectRelease(service) }
    return cfString(IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue())
}

private func marketingName() -> String? {
    let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPlatformExpertDevice"))
    guard service != 0 else { return nil }
    defer { IOObjectRelease(service) }
    let value = IORegistryEntrySearchCFProperty(
        service, kIOServicePlane, "product-name" as CFString, kCFAllocatorDefault,
        IOOptionBits(kIORegistryIterateRecursively)
    )
    return cfString(value)
}

private func deviceTreeString(_ path: String, _ key: String) -> String? {
    let entry = IORegistryEntryFromPath(kIOMainPortDefault, path)
    guard entry != 0 else { return nil }
    defer { IOObjectRelease(entry) }
    return cfString(IORegistryEntryCreateCFProperty(entry, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue())
}

private func registryProperties(_ className: String) -> [String: Any]? {
    let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching(className))
    guard service != 0 else { return nil }
    defer { IOObjectRelease(service) }
    var props: Unmanaged<CFMutableDictionary>?
    guard IORegistryEntryCreateCFProperties(service, &props, kCFAllocatorDefault, 0) == KERN_SUCCESS else { return nil }
    return props?.takeRetainedValue() as? [String: Any]
}

/// Registry text comes back as either a CFString or NUL-padded Data.
private func cfString(_ value: Any?) -> String? {
    if let string = value as? String { return string }
    if let data = value as? Data {
        let text = String(decoding: data.prefix { $0 != 0 }, as: UTF8.self)
        return text.isEmpty ? nil : text
    }
    return nil
}
