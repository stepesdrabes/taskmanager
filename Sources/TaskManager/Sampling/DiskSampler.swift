import Foundation
import IOKit

nonisolated final class DiskSampler {
    private struct Counters {
        var read: UInt64 = 0
        var written: UInt64 = 0
    }

    private var previous: [String: Counters] = [:]
    private var previousDate: Date?

    func sample() -> (disks: [DiskSnapshot], volumes: [VolumeSnapshot]) {
        let now = Date()
        let elapsed = previousDate.map { now.timeIntervalSince($0) } ?? 0
        previousDate = now

        let current = readDrivers()
        defer { previous = current }

        var disks: [DiskSnapshot] = []
        for (bsdName, counters) in current {
            var readRate = 0.0
            var writeRate = 0.0
            if elapsed > 0, let old = previous[bsdName] {
                // Clamp to 0 on counter reset (device re-attach etc.).
                readRate = Double(counters.read >= old.read ? counters.read - old.read : 0) / elapsed
                writeRate = Double(counters.written >= old.written ? counters.written - old.written : 0) / elapsed
            }
            disks.append(DiskSnapshot(
                id: bsdName,
                readPerSec: readRate,
                writePerSec: writeRate,
                totalRead: counters.read,
                totalWritten: counters.written
            ))
        }
        disks.sort { $0.id.localizedStandardCompare($1.id) == .orderedAscending }

        return (disks, volumes())
    }

    private func readDrivers() -> [String: Counters] {
        var iterator = io_iterator_t()
        guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IOBlockStorageDriver"), &iterator) == KERN_SUCCESS else {
            return [:]
        }
        defer { IOObjectRelease(iterator) }

        var result: [String: Counters] = [:]
        while case let entry = IOIteratorNext(iterator), entry != 0 {
            defer { IOObjectRelease(entry) }
            guard let stats = IORegistryEntryCreateCFProperty(entry, "Statistics" as CFString, kCFAllocatorDefault, 0)?
                .takeRetainedValue() as? [String: Any] else { continue }
            // The whole-disk IOMedia child carries the BSD name.
            guard let bsdName = IORegistryEntrySearchCFProperty(
                entry, kIOServicePlane, "BSD Name" as CFString, kCFAllocatorDefault,
                IOOptionBits(kIORegistryIterateRecursively)
            ) as? String else { continue }

            result[bsdName] = Counters(
                read: (stats["Bytes (Read)"] as? NSNumber).map { UInt64(max($0.int64Value, 0)) } ?? 0,
                written: (stats["Bytes (Write)"] as? NSNumber).map { UInt64(max($0.int64Value, 0)) } ?? 0
            )
        }
        return result
    }

    private func volumes() -> [VolumeSnapshot] {
        let keys: [URLResourceKey] = [
            .volumeNameKey, .volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey,
        ]
        guard let urls = FileManager.default.mountedVolumeURLs(
            includingResourceValuesForKeys: keys,
            options: [.skipHiddenVolumes]
        ) else { return [] }

        return urls.compactMap { url in
            guard let values = try? url.resourceValues(forKeys: Set(keys)),
                  let total = values.volumeTotalCapacity, total > 0 else { return nil }
            return VolumeSnapshot(
                id: url.path,
                name: values.volumeName ?? url.lastPathComponent,
                total: UInt64(total),
                available: UInt64(max(values.volumeAvailableCapacityForImportantUsage ?? 0, 0))
            )
        }
    }
}
