import Darwin

nonisolated final class CPUSampler {
    private struct Ticks {
        var user: UInt32 = 0
        var system: UInt32 = 0
        var idle: UInt32 = 0
        var nice: UInt32 = 0

        // Tick counters are UInt32 and wrap; modular subtraction keeps deltas correct.
        func delta(since old: Ticks) -> (busy: UInt64, total: UInt64) {
            let busy = UInt64(user &- old.user) + UInt64(system &- old.system) + UInt64(nice &- old.nice)
            return (busy, busy + UInt64(idle &- old.idle))
        }
    }

    private var previous: [Ticks] = []

    func sample() -> CPUSnapshot {
        let ticks = readTicks()
        defer { previous = ticks }

        var coreBusy = [Double](repeating: 0, count: ticks.count)
        var busySum: UInt64 = 0
        var totalSum: UInt64 = 0
        if previous.count == ticks.count {
            for i in ticks.indices {
                let d = ticks[i].delta(since: previous[i])
                coreBusy[i] = d.total > 0 ? Double(d.busy) / Double(d.total) : 0
                busySum += d.busy
                totalSum += d.total
            }
        }

        var loads = [Double](repeating: 0, count: 3)
        getloadavg(&loads, 3)
        let counts = processAndThreadCounts()

        return CPUSnapshot(
            totalBusy: totalSum > 0 ? Double(busySum) / Double(totalSum) : 0,
            coreBusy: coreBusy,
            processCount: counts.processes,
            threadCount: counts.threads,
            load1: loads[0],
            load5: loads[1],
            load15: loads[2]
        )
    }

    private func readTicks() -> [Ticks] {
        var coreCount: natural_t = 0
        var info: processor_info_array_t?
        var infoCount: mach_msg_type_number_t = 0
        guard host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &coreCount, &info, &infoCount) == KERN_SUCCESS,
              let info else { return [] }
        defer {
            vm_deallocate(
                mach_task_self_,
                vm_address_t(bitPattern: info),
                vm_size_t(infoCount) * vm_size_t(MemoryLayout<integer_t>.size)
            )
        }

        let stride = Int(CPU_STATE_MAX)
        return (0..<Int(coreCount)).map { core in
            Ticks(
                user: UInt32(bitPattern: info[core * stride + Int(CPU_STATE_USER)]),
                system: UInt32(bitPattern: info[core * stride + Int(CPU_STATE_SYSTEM)]),
                idle: UInt32(bitPattern: info[core * stride + Int(CPU_STATE_IDLE)]),
                nice: UInt32(bitPattern: info[core * stride + Int(CPU_STATE_NICE)])
            )
        }
    }

    private func processAndThreadCounts() -> (processes: Int, threads: Int) {
        var pset = processor_set_name_t()
        guard processor_set_default(mach_host_self(), &pset) == KERN_SUCCESS else { return (0, 0) }
        defer { mach_port_deallocate(mach_task_self_, pset) }

        var info = processor_set_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<processor_set_load_info>.size / MemoryLayout<natural_t>.size)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                processor_set_statistics(pset, PROCESSOR_SET_LOAD_INFO, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return (0, 0) }
        return (Int(info.task_count), Int(info.thread_count))
    }
}
