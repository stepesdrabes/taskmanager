import Foundation

nonisolated struct Snapshot: Sendable {
    let date: Date
    let cpu: CPUSnapshot
    let memory: MemorySnapshot
    let gpu: GPUSnapshot?
    let disks: [DiskSnapshot]
    let volumes: [VolumeSnapshot]
    let interfaces: [InterfaceSnapshot]
}

nonisolated struct InterfaceSnapshot: Sendable, Identifiable {
    let id: String           // BSD name, e.g. "en0"
    let displayName: String  // "Wi-Fi", "Thunderbolt Ethernet"
    let rxPerSec: Double
    let txPerSec: Double
    let totalRx: UInt64      // accumulated since sampling started (see NetworkSampler)
    let totalTx: UInt64
    let ipv4: [String]
    let ipv6: [String]       // non-link-local only
    let isPrimary: Bool
}

nonisolated struct DiskSnapshot: Sendable, Identifiable {
    let id: String          // BSD name of the physical disk, e.g. "disk0"
    let readPerSec: Double
    let writePerSec: Double
    let totalRead: UInt64   // cumulative since boot
    let totalWritten: UInt64
}

nonisolated struct VolumeSnapshot: Sendable, Identifiable {
    let id: String          // mount path
    let name: String
    let total: UInt64
    let available: UInt64   // importantUsage capacity — matches Finder

    var used: UInt64 { total - min(available, total) }
}

/// Every field optional: the IOAccelerator key set is undocumented and varies
/// by chip and OS release (plan/02).
nonisolated struct GPUSnapshot: Sendable {
    let device: Double?     // 0...1
    let renderer: Double?
    let tiler: Double?
    let usedMemory: UInt64?
    let allocatedMemory: UInt64?
}

/// Not part of `Snapshot` — sampled on its own cadence, no history kept.
nonisolated struct ProcessRow: Sendable, Identifiable {
    let id: pid_t
    let name: String
    let cpu: Double      // fraction of one core; 1.0 = 100 % (Activity Monitor convention)
    let memory: UInt64   // physical footprint bytes
}

nonisolated enum MemoryPressure: Int, Sendable {
    case normal = 1
    case warning = 2
    case critical = 4
}

nonisolated struct MemorySnapshot: Sendable {
    let app: UInt64         // internal − purgeable pages
    let wired: UInt64
    let compressed: UInt64
    let cached: UInt64      // external + purgeable pages
    let free: UInt64
    let swapUsed: UInt64
    let swapTotal: UInt64   // elastic on macOS — display "allocated", never a %
    let pressure: MemoryPressure

    var used: UInt64 { app + wired + compressed }

    static let zero = MemorySnapshot(
        app: 0, wired: 0, compressed: 0, cached: 0, free: 0,
        swapUsed: 0, swapTotal: 0, pressure: .normal
    )
}

nonisolated struct CPUSnapshot: Sendable {
    let totalBusy: Double    // 0...1
    let coreBusy: [Double]   // 0...1, index == logical CPU id
    let processCount: Int
    let threadCount: Int
    let load1: Double
    let load5: Double
    let load15: Double
}
