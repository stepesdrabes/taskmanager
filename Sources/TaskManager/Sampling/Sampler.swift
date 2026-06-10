import Foundation

/// Created inside the sampling task and confined to it — only the `Sendable`
/// `Snapshot` it returns ever crosses to the main actor.
nonisolated final class Sampler {
    private let cpu = CPUSampler()
    private let memory = MemorySampler()
    private let gpu = GPUSampler()
    private let disk = DiskSampler()

    func sample() -> Snapshot {
        let storage = disk.sample()
        return Snapshot(
            date: Date(),
            cpu: cpu.sample(),
            memory: memory.sample(),
            gpu: gpu.sample(),
            disks: storage.disks,
            volumes: storage.volumes
        )
    }
}
