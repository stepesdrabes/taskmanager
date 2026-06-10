import Darwin
import Foundation

nonisolated enum Sysctl {
    static func string(_ name: String) -> String? {
        var size = 0
        guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 0 else { return nil }
        var buffer = [CChar](repeating: 0, count: size)
        guard sysctlbyname(name, &buffer, &size, nil, 0) == 0 else { return nil }
        return buffer.withUnsafeBufferPointer { String(cString: $0.baseAddress!) }
    }

    /// Works for both 4- and 8-byte integer sysctls: the kernel fills the low
    /// bytes and the rest stay zero (little-endian).
    static func uint64(_ name: String) -> UInt64? {
        var value: UInt64 = 0
        var size = MemoryLayout<UInt64>.size
        guard sysctlbyname(name, &value, &size, nil, 0) == 0 else { return nil }
        return value
    }

    static func int(_ name: String) -> Int? {
        uint64(name).map { Int($0) }
    }

    static func timeval(_ name: String) -> Darwin.timeval? {
        var value = Darwin.timeval()
        var size = MemoryLayout<Darwin.timeval>.size
        guard sysctlbyname(name, &value, &size, nil, 0) == 0 else { return nil }
        return value
    }
}

nonisolated struct SystemInfo: Sendable {
    let chipName: String
    let logicalCPUs: Int
    let pCoreCount: Int
    let eCoreCount: Int
    let pCoreName: String
    let eCoreName: String
    let pCoreL1i: UInt64
    let pCoreL1d: UInt64
    let pCoreL2: UInt64
    let eCoreL1i: UInt64
    let eCoreL1d: UInt64
    let eCoreL2: UInt64
    let memoryTotal: UInt64
    let pageSize: UInt64
    let bootTime: Date

    /// The E-cluster owns the lowest CPU ids on every M-series chip so far;
    /// this is observed behavior, not a documented contract (plan/02).
    func isEfficiencyCore(_ coreIndex: Int) -> Bool {
        coreIndex < eCoreCount
    }

    static func current() -> SystemInfo {
        let logical = Sysctl.int("hw.ncpu") ?? ProcessInfo.processInfo.activeProcessorCount
        let perfLevels = Sysctl.int("hw.nperflevels") ?? 1
        let eCores = perfLevels > 1 ? (Sysctl.int("hw.perflevel1.logicalcpu") ?? 0) : 0

        let bootTime: Date
        if let tv = Sysctl.timeval("kern.boottime") {
            bootTime = Date(timeIntervalSince1970: TimeInterval(tv.tv_sec) + TimeInterval(tv.tv_usec) / 1_000_000)
        } else {
            bootTime = Date()
        }

        return SystemInfo(
            chipName: Sysctl.string("machdep.cpu.brand_string") ?? "Apple Silicon",
            logicalCPUs: logical,
            pCoreCount: Sysctl.int("hw.perflevel0.logicalcpu") ?? logical,
            eCoreCount: eCores,
            pCoreName: Sysctl.string("hw.perflevel0.name") ?? "Performance",
            eCoreName: Sysctl.string("hw.perflevel1.name") ?? "Efficiency",
            pCoreL1i: Sysctl.uint64("hw.perflevel0.l1icachesize") ?? 0,
            pCoreL1d: Sysctl.uint64("hw.perflevel0.l1dcachesize") ?? 0,
            pCoreL2: Sysctl.uint64("hw.perflevel0.l2cachesize") ?? 0,
            eCoreL1i: Sysctl.uint64("hw.perflevel1.l1icachesize") ?? 0,
            eCoreL1d: Sysctl.uint64("hw.perflevel1.l1dcachesize") ?? 0,
            eCoreL2: Sysctl.uint64("hw.perflevel1.l2cachesize") ?? 0,
            memoryTotal: Sysctl.uint64("hw.memsize") ?? 0,
            pageSize: Sysctl.uint64("hw.pagesize") ?? 16_384,
            bootTime: bootTime
        )
    }
}
