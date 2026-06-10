import Foundation

/// Created inside the sampling task and confined to it — only the `Sendable`
/// `Snapshot` it returns ever crosses to the main actor.
nonisolated final class Sampler {
    private let cpu = CPUSampler()
    private let memory = MemorySampler()

    func sample() -> Snapshot {
        Snapshot(date: Date(), cpu: cpu.sample(), memory: memory.sample())
    }
}
