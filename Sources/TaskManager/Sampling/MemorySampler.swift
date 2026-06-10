import Darwin

nonisolated final class MemorySampler {
    private let pageSize = Sysctl.uint64("hw.pagesize") ?? 16_384

    func sample() -> MemorySnapshot {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return .zero }

        let internalPages = UInt64(stats.internal_page_count)
        let purgeable = UInt64(stats.purgeable_count)
        let swap = swapUsage()

        return MemorySnapshot(
            app: (internalPages - min(purgeable, internalPages)) * pageSize,
            wired: UInt64(stats.wire_count) * pageSize,
            compressed: UInt64(stats.compressor_page_count) * pageSize,
            cached: (UInt64(stats.external_page_count) + purgeable) * pageSize,
            free: UInt64(stats.free_count) * pageSize,
            swapUsed: swap.used,
            swapTotal: swap.total,
            pressure: MemoryPressure(rawValue: Sysctl.int("kern.memorystatus_vm_pressure_level") ?? 1) ?? .normal
        )
    }

    private func swapUsage() -> (used: UInt64, total: UInt64) {
        var swap = xsw_usage()
        var size = MemoryLayout<xsw_usage>.size
        guard sysctlbyname("vm.swapusage", &swap, &size, nil, 0) == 0 else { return (0, 0) }
        return (swap.xsu_used, swap.xsu_total)
    }
}
