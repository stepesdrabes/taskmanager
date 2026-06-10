import Foundation

nonisolated struct Snapshot: Sendable {
    let date: Date
    let cpu: CPUSnapshot
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
