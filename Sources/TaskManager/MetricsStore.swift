import Foundation
import Observation

@Observable @MainActor
final class MetricsStore {
    private(set) var history = RingBuffer<Snapshot>(capacity: 120)
    let system = SystemInfo.current()
    var selectedSection: MonitorSection? = .cpu

    var latest: Snapshot? { history.last }

    private(set) var processes: [ProcessRow] = []

    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private var processTask: Task<Void, Never>?
    @ObservationIgnored private var processSamplingRequested = false

    func start() {
        if task == nil {
            task = Task.detached(priority: .utility) { [weak self] in
                let sampler = Sampler()
                let clock = ContinuousClock()
                // The first sample only primes the delta baselines (CPU ticks etc.)
                // and is discarded — its rates would span the whole pause/sleep gap.
                _ = sampler.sample()
                while !Task.isCancelled {
                    guard let self else { return }
                    let interval = await self.samplingInterval
                    try? await clock.sleep(for: interval, tolerance: .seconds(0.1))
                    if Task.isCancelled { return }
                    let snapshot = sampler.sample()
                    await self.append(snapshot)
                }
            }
        }
        if processSamplingRequested {
            spawnProcessTask()
        }
    }

    func stop() {
        task?.cancel()
        task = nil
        processTask?.cancel()
        processTask = nil
    }

    /// Process rows refresh on their own slower cadence, and only while the
    /// Processes tab is visible.
    func startProcessSampling() {
        processSamplingRequested = true
        spawnProcessTask()
    }

    func stopProcessSampling() {
        processSamplingRequested = false
        processTask?.cancel()
        processTask = nil
    }

    private func spawnProcessTask() {
        guard processTask == nil else { return }
        processTask = Task.detached(priority: .utility) { [weak self] in
            let sampler = ProcessSampler()
            let clock = ContinuousClock()
            _ = sampler.sample()
            // Short first interval so the table fills quickly, then 2 s.
            var interval: Duration = .seconds(0.5)
            while !Task.isCancelled {
                try? await clock.sleep(for: interval, tolerance: .seconds(0.2))
                interval = .seconds(2)
                if Task.isCancelled { return }
                let rows = sampler.sample()
                await self?.setProcesses(rows)
            }
        }
    }

    private func setProcesses(_ rows: [ProcessRow]) {
        processes = rows
    }

    private var samplingInterval: Duration {
        let configured = UserDefaults.standard.double(forKey: "updateInterval")
        return .seconds(configured >= 0.5 ? configured : 1)
    }

    private func append(_ snapshot: Snapshot) {
        history.append(snapshot)
    }
}
