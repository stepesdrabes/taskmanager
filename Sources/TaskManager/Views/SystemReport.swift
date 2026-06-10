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

    static func gather(system: SystemInfo, loc: Localizer) -> SystemReport {
        var sections: [Section] = []
        func section(_ title: String, _ rows: [Row?]) {
            let filled = rows.compactMap { $0 }
            if !filled.isEmpty { sections.append(Section(title: title, rows: filled)) }
        }
        let performance = loc("common.performance")
        let efficiency = loc("common.efficiency")

        section(loc("sysinfo.overview"), [
            row(loc("sysinfo.model"), marketingName()),
            row(loc("sysinfo.modelIdentifier"), Sysctl.string("hw.model")),
            row(loc("sysinfo.modelNumber"), modelNumber()),
            row(loc("sysinfo.chip"), system.chipName),
            row(loc("sysinfo.memory"), Format.bytes(system.memoryTotal)),
            row(loc("sysinfo.serialNumber"), ioPlatformString("IOPlatformSerialNumber")),
            row(loc("sysinfo.hardwareUUID"), ioPlatformString("IOPlatformUUID")),
        ])

        section(loc("sysinfo.processor"), [
            row(loc("sysinfo.chip"), system.chipName),
            row(loc("sysinfo.totalCores"), "\(system.pCoreCount + system.eCoreCount)"),
            row(loc("sysinfo.coresOfType", ["type": performance]), system.pCoreCount > 0 ? "\(system.pCoreCount)" : nil),
            row(loc("sysinfo.coresOfType", ["type": efficiency]), system.eCoreCount > 0 ? "\(system.eCoreCount)" : nil),
            row(loc("sysinfo.l1CacheOfType", ["type": performance]), "\(Format.bytes(system.pCoreL1i)) + \(Format.bytes(system.pCoreL1d))"),
            row(loc("sysinfo.l2CacheOfType", ["type": performance]), Format.bytes(system.pCoreL2)),
            row(loc("sysinfo.l1CacheOfType", ["type": efficiency]), "\(Format.bytes(system.eCoreL1i)) + \(Format.bytes(system.eCoreL1d))"),
            row(loc("sysinfo.l2CacheOfType", ["type": efficiency]), Format.bytes(system.eCoreL2)),
            row(loc("sysinfo.cacheLine"), Sysctl.int("hw.cachelinesize").map { loc("sysinfo.bytes", ["n": "\($0)"]) }),
            row(loc("sysinfo.byteOrder"), Sysctl.int("hw.byteorder").map { $0 == 1234 ? loc("sysinfo.littleEndian") : loc("sysinfo.bigEndian") }),
            row(loc("sysinfo.pageSize"), loc("sysinfo.kilobytes", ["n": "\(system.pageSize / 1024)"])),
            row(loc("sysinfo.bit64"), (Sysctl.int("hw.cpu64bit_capable") ?? 0) == 1 ? loc("common.yes") : loc("common.no")),
        ])

        section(loc("sysinfo.graphics"), graphicsRows(system: system, loc: loc))

        for screen in NSScreen.screens {
            section(loc("sysinfo.display", ["name": screen.localizedName]), displayRows(screen, loc: loc))
        }

        section(loc("sysinfo.memory"), [
            row(loc("sysinfo.total"), Format.bytes(system.memoryTotal)),
            row(loc("sysinfo.type"), deviceTreeString("IODeviceTree:/chosen", "dram-type")),
            row(loc("sysinfo.manufacturer"), deviceTreeString("IODeviceTree:/chosen", "dram-vendor")),
            row(loc("sysinfo.pageSize"), loc("sysinfo.kilobytes", ["n": "\(system.pageSize / 1024)"])),
        ])

        section(loc("sysinfo.storage"), storageRows(loc: loc))

        section(loc("sysinfo.operatingSystem"), [
            row(loc("sysinfo.macos"), osVersion()),
            row(loc("sysinfo.build"), Sysctl.string("kern.osversion")),
            row(loc("sysinfo.kernel"), kernelVersion()),
            row(loc("sysinfo.uptime"), Format.uptime(since: system.bootTime)),
            row(loc("sysinfo.architecture"), architecture(loc: loc)),
        ])

        section(loc("sysinfo.network"), networkRows(loc: loc))

        section(loc("sysinfo.battery"), batteryRows(loc: loc))

        section(loc("sysinfo.environment"), [
            row(loc("sysinfo.user"), loc("sysinfo.userValue", ["full": NSFullUserName(), "short": NSUserName()])),
            row(loc("sysinfo.shell"), ProcessInfo.processInfo.environment["SHELL"]),
            row(loc("sysinfo.locale"), Locale.current.identifier),
            row(loc("sysinfo.timeZone"), TimeZone.current.identifier),
            row(loc("sysinfo.thermalState"), thermalState(loc: loc)),
            row(loc("sysinfo.lowPowerMode"), ProcessInfo.processInfo.isLowPowerModeEnabled ? loc("common.on") : loc("common.off")),
        ])

        return SystemReport(sections: sections)
    }
}

private func row(_ label: String, _ value: String?) -> SystemReport.Row? {
    value.map { SystemReport.Row(label: label, value: $0) }
}

// MARK: - Graphics

private func graphicsRows(system: SystemInfo, loc: Localizer) -> [SystemReport.Row?] {
    let device = MTLCreateSystemDefaultDevice()
    return [
        row(loc("sysinfo.gpu"), system.gpuName ?? device?.name),
        row(loc("sysinfo.gpuCores"), system.gpuCoreCount.map { "\($0)" }),
        row(loc("sysinfo.metalSupport"), device.map { metalFamily($0, loc: loc) }),
        row(loc("sysinfo.unifiedMemory"), device.map { $0.hasUnifiedMemory ? loc("common.yes") : loc("common.no") }),
        row(loc("sysinfo.recommendedVRAM"), device.map { Format.bytes(UInt64($0.recommendedMaxWorkingSetSize)) }),
    ]
}

private func metalFamily(_ device: MTLDevice, loc: Localizer) -> String {
    var parts: [String] = []
    if device.supportsFamily(.apple9) { parts.append("Apple 9") }
    else if device.supportsFamily(.apple8) { parts.append("Apple 8") }
    else if device.supportsFamily(.apple7) { parts.append("Apple 7") }
    if device.supportsFamily(.metal3) { parts.append("Metal 3") }
    return parts.isEmpty ? loc("sysinfo.metalSupported") : parts.joined(separator: ", ")
}

// MARK: - Displays

private func displayRows(_ screen: NSScreen, loc: Localizer) -> [SystemReport.Row?] {
    let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID ?? 0
    let pixels = screen.convertRectToBacking(screen.frame).size
    let edrHeadroom = screen.maximumPotentialExtendedDynamicRangeColorComponentValue
    let physical = CGDisplayScreenSize(displayID)
    return [
        row(loc("sysinfo.resolution"), loc("sysinfo.resolutionValue", ["w": "\(Int(screen.frame.width))", "h": "\(Int(screen.frame.height))"])),
        row(loc("sysinfo.pixels"), loc("sysinfo.pixelsValue", ["w": "\(Int(pixels.width))", "h": "\(Int(pixels.height))"])),
        row(loc("sysinfo.scale"), String(format: "%.1f×", screen.backingScaleFactor)),
        row(loc("sysinfo.refreshRate"), screen.maximumFramesPerSecond > 0 ? loc("sysinfo.refreshValue", ["n": "\(screen.maximumFramesPerSecond)"]) : nil),
        row(loc("sysinfo.colorSpace"), screen.colorSpace?.localizedName),
        row(loc("sysinfo.builtIn"), CGDisplayIsBuiltin(displayID) != 0 ? loc("common.yes") : loc("common.no")),
        row(loc("sysinfo.physicalSize"), physical.width > 0 ? loc("sysinfo.physicalValue", ["w": "\(Int(physical.width))", "h": "\(Int(physical.height))"]) : nil),
        row(loc("sysinfo.hdr"), edrHeadroom > 1 ? loc("sysinfo.hdrYes", ["headroom": String(format: "%.0f", edrHeadroom)]) : loc("common.no")),
    ]
}

// MARK: - Storage

private func storageRows(loc: Localizer) -> [SystemReport.Row?] {
    let keys: [URLResourceKey] = [
        .volumeNameKey, .volumeLocalizedFormatDescriptionKey, .volumeTotalCapacityKey,
        .volumeAvailableCapacityForImportantUsageKey, .volumeIsInternalKey,
    ]
    guard let values = try? URL(fileURLWithPath: "/").resourceValues(forKeys: Set(keys)) else { return [] }
    return [
        row(loc("sysinfo.bootVolume"), values.volumeName),
        row(loc("sysinfo.fileSystem"), values.volumeLocalizedFormatDescription),
        row(loc("sysinfo.capacity"), values.volumeTotalCapacity.map { Format.storageBytes(UInt64($0)) }),
        row(loc("sysinfo.available"), values.volumeAvailableCapacityForImportantUsage.map { Format.storageBytes(UInt64(max($0, 0))) }),
        row(loc("sysinfo.internal"), values.volumeIsInternal.map { $0 ? loc("common.yes") : loc("common.no") }),
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

private func architecture(loc: Localizer) -> String {
    Sysctl.int("sysctl.proc_translated") == 1 ? loc("sysinfo.archRosetta") : loc("sysinfo.archValue")
}

private func thermalState(loc: Localizer) -> String {
    switch ProcessInfo.processInfo.thermalState {
    case .nominal: loc("sysinfo.thermalNominal")
    case .fair: loc("sysinfo.thermalFair")
    case .serious: loc("sysinfo.thermalSerious")
    case .critical: loc("sysinfo.thermalCritical")
    @unknown default: loc("sysinfo.thermalUnknown")
    }
}

// MARK: - Network

private func networkRows(loc: Localizer) -> [SystemReport.Row?] {
    let primary = primaryInterface()
    return [
        row(loc("sysinfo.computerName"), Host.current().localizedName),
        row(loc("sysinfo.localHostname"), ProcessInfo.processInfo.hostName),
        row(loc("sysinfo.primaryInterface"), primary),
        row(loc("sysinfo.ipAddress"), primary.flatMap(ipv4Address)),
        row(loc("sysinfo.macAddress"), primary.flatMap(macAddress)),
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

private func batteryRows(loc: Localizer) -> [SystemReport.Row?] {
    guard let battery = registryProperties("AppleSmartBattery"),
          battery["BatteryInstalled"] as? Bool ?? false else { return [] }
    return [
        row(loc("sysinfo.cycleCount"), (battery["CycleCount"] as? Int).map { "\($0)" }),
        row(loc("sysinfo.designCycleLimit"), (battery["DesignCycleCount9C"] as? Int).map { "\($0)" }),
        row(loc("sysinfo.designCapacity"), (battery["DesignCapacity"] as? Int).map { loc("sysinfo.milliampHours", ["n": "\($0)"]) }),
        row(loc("sysinfo.batterySerial"), battery["Serial"] as? String),
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
