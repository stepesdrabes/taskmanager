import Darwin
import Foundation

nonisolated final class ProcessSampler {
    private var previousCPUTime: [pid_t: UInt64] = [:]
    private var previousDate: Date?
    private let timebaseNumer: UInt64
    private let timebaseDenom: UInt64

    init() {
        var info = mach_timebase_info_data_t()
        mach_timebase_info(&info)
        timebaseNumer = UInt64(info.numer)
        timebaseDenom = UInt64(info.denom)
    }

    func sample() -> [ProcessRow] {
        let now = Date()
        let elapsed = previousDate.map { now.timeIntervalSince($0) } ?? 0
        previousDate = now

        let estimated = proc_listallpids(nil, 0)
        guard estimated > 0 else { return [] }
        var pids = [pid_t](repeating: 0, count: Int(estimated) + 64)
        let count = proc_listallpids(&pids, Int32(pids.count * MemoryLayout<pid_t>.size))
        guard count > 0 else { return [] }

        var rows: [ProcessRow] = []
        rows.reserveCapacity(Int(count))
        var currentTimes: [pid_t: UInt64] = [:]

        for pid in pids.prefix(Int(count)) where pid > 0 {
            var usage = rusage_info_current()
            let result = withUnsafeMutablePointer(to: &usage) {
                $0.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) {
                    proc_pid_rusage(pid, RUSAGE_INFO_CURRENT, $0)
                }
            }
            // Restricted pids (other users' processes) fail here — skip them.
            guard result == 0 else { continue }

            let cpuTime = usage.ri_user_time &+ usage.ri_system_time
            currentTimes[pid] = cpuTime

            var cpu = 0.0
            // cpuTime < old means the pid was reused — treat as a fresh process.
            if elapsed > 0, let old = previousCPUTime[pid], cpuTime >= old {
                let deltaNanos = (cpuTime - old) * timebaseNumer / timebaseDenom
                cpu = Double(deltaNanos) / (elapsed * 1_000_000_000)
            }

            rows.append(ProcessRow(
                id: pid,
                name: name(of: pid),
                cpu: cpu,
                memory: usage.ri_phys_footprint
            ))
        }
        previousCPUTime = currentTimes
        return rows
    }

    private func name(of pid: pid_t) -> String {
        var buffer = [CChar](repeating: 0, count: 64)
        let length = proc_name(pid, &buffer, UInt32(buffer.count))
        guard length > 0 else { return "pid \(pid)" }
        return String(decoding: buffer.prefix(Int(length)).map { UInt8(bitPattern: $0) }, as: UTF8.self)
    }
}
