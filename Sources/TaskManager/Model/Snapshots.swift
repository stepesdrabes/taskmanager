import Foundation

nonisolated struct Snapshot: Sendable {
    let date: Date
    let cpu: CPUSnapshot
    let memory: MemorySnapshot
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
