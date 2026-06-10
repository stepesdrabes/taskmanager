import Foundation
import IOKit

nonisolated final class GPUSampler {
    func sample() -> GPUSnapshot? {
        guard let props = Self.acceleratorProperties(),
              let perf = props["PerformanceStatistics"] as? [String: Any] else { return nil }

        func fraction(_ key: String) -> Double? {
            (perf[key] as? NSNumber).map { min(max($0.doubleValue / 100, 0), 1) }
        }
        func bytes(_ key: String) -> UInt64? {
            (perf[key] as? NSNumber).map { UInt64(max($0.int64Value, 0)) }
        }

        return GPUSnapshot(
            device: fraction("Device Utilization %"),
            renderer: fraction("Renderer Utilization %"),
            tiler: fraction("Tiler Utilization %"),
            usedMemory: bytes("In use system memory"),
            allocatedMemory: bytes("Alloc system memory")
        )
    }

    /// Properties of the first accelerator that exposes PerformanceStatistics.
    /// Matches the generic IOAccelerator class so any chip generation works.
    static func acceleratorProperties() -> [String: Any]? {
        var iterator = io_iterator_t()
        guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IOAccelerator"), &iterator) == KERN_SUCCESS else {
            return nil
        }
        defer { IOObjectRelease(iterator) }

        while case let entry = IOIteratorNext(iterator), entry != 0 {
            defer { IOObjectRelease(entry) }
            var props: Unmanaged<CFMutableDictionary>?
            guard IORegistryEntryCreateCFProperties(entry, &props, kCFAllocatorDefault, 0) == KERN_SUCCESS,
                  let dict = props?.takeRetainedValue() as? [String: Any] else { continue }
            if dict["PerformanceStatistics"] != nil {
                return dict
            }
        }
        return nil
    }

    static func staticFacts() -> (name: String?, coreCount: Int?) {
        guard let props = acceleratorProperties() else { return (nil, nil) }
        let name: String? = if let string = props["model"] as? String {
            string
        } else if let data = props["model"] as? Data {
            String(decoding: data.prefix(while: { $0 != 0 }), as: UTF8.self)
        } else {
            nil
        }
        return (name, (props["gpu-core-count"] as? NSNumber)?.intValue)
    }
}
