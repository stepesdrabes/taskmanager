import Foundation
import IOKit
import IOKit.ps

nonisolated final class EnergySampler {
    func sample() -> EnergySnapshot? {
        guard let battery = batteryRegistry(), battery["BatteryInstalled"] as? Bool ?? false else {
            return nil
        }

        let power = powerSource()
        let designCapacity = battery["DesignCapacity"] as? Int ?? 0
        // Nominal full-charge capacity matches the "Maximum Capacity" macOS shows.
        let fullCharge = battery["NominalChargeCapacity"] as? Int
            ?? battery["AppleRawMaxCapacity"] as? Int ?? 0
        let voltage = Double(battery["Voltage"] as? Int ?? 0) / 1000
        let amperage = Double(battery["Amperage"] as? Int ?? 0) / 1000

        return EnergySnapshot(
            charge: Double(power.charge) / 100,
            isCharging: battery["IsCharging"] as? Bool ?? false,
            isFullyCharged: battery["FullyCharged"] as? Bool ?? false,
            onAC: battery["ExternalConnected"] as? Bool ?? (power.state == kIOPSACPowerValue),
            powerWatts: abs(voltage * amperage),
            timeToEmpty: power.timeToEmpty,
            timeToFull: power.timeToFull,
            cycleCount: battery["CycleCount"] as? Int ?? 0,
            health: designCapacity > 0 ? Double(fullCharge) / Double(designCapacity) : 0,
            temperature: Double(battery["Temperature"] as? Int ?? 0) / 100,
            designCapacity: designCapacity,
            currentCapacity: fullCharge,
            voltage: voltage
        )
    }

    private func batteryRegistry() -> [String: Any]? {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }
        var props: Unmanaged<CFMutableDictionary>?
        guard IORegistryEntryCreateCFProperties(service, &props, kCFAllocatorDefault, 0) == KERN_SUCCESS else {
            return nil
        }
        return props?.takeRetainedValue() as? [String: Any]
    }

    private struct PowerInfo {
        var charge = 0
        var state = ""
        var timeToEmpty = 0
        var timeToFull = 0
    }

    private func powerSource() -> PowerInfo {
        guard let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef],
              let first = sources.first,
              let description = IOPSGetPowerSourceDescription(blob, first)?.takeUnretainedValue() as? [String: Any] else {
            return PowerInfo()
        }
        return PowerInfo(
            charge: description[kIOPSCurrentCapacityKey] as? Int ?? 0,
            state: description[kIOPSPowerSourceStateKey] as? String ?? "",
            timeToEmpty: description[kIOPSTimeToEmptyKey] as? Int ?? 0,
            timeToFull: description[kIOPSTimeToFullChargeKey] as? Int ?? 0
        )
    }
}
