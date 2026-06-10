import Foundation
import Observation

@Observable @MainActor
final class MetricsStore {
    private(set) var history = RingBuffer<Snapshot>(capacity: 120)
    let system = SystemInfo.current()

    var latest: Snapshot? { history.last }

    @ObservationIgnored private var task: Task<Void, Never>?

    func start() {
        guard task == nil else { return }
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

    func stop() {
        task?.cancel()
        task = nil
    }

    private var samplingInterval: Duration {
        let configured = UserDefaults.standard.double(forKey: "updateInterval")
        return .seconds(configured >= 0.5 ? configured : 1)
    }

    private func append(_ snapshot: Snapshot) {
        history.append(snapshot)
    }
}
