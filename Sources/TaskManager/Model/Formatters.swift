import Foundation

nonisolated enum Format {
    static func percent(_ fraction: Double) -> String {
        "\(Int((fraction * 100).rounded()))%"
    }

    static func bytes(_ value: UInt64) -> String {
        Int64(clamping: value).formatted(.byteCount(style: .memory))
    }

    static func bytesPerSecond(_ value: Double) -> String {
        bytes(UInt64(max(0, value))) + "/s"
    }

    /// Decimal units — what Finder and disk vendors use for storage.
    static func storageBytes(_ value: UInt64) -> String {
        Int64(clamping: value).formatted(.byteCount(style: .file))
    }

    static func storageBytesPerSecond(_ value: Double) -> String {
        storageBytes(UInt64(max(0, value))) + "/s"
    }

    /// Windows Task Manager style: D:HH:MM:SS.
    static func uptime(since boot: Date, now: Date = Date()) -> String {
        let total = max(0, Int(now.timeIntervalSince(boot)))
        return String(
            format: "%d:%02d:%02d:%02d",
            total / 86_400, (total % 86_400) / 3_600, (total % 3_600) / 60, total % 60
        )
    }

    /// Rounds up to 1/2/5×10ⁿ so autoscaled chart axes don't jitter.
    static func niceMax(_ raw: Double) -> Double {
        guard raw > 0 else { return 1 }
        let base = pow(10, floor(log10(raw)))
        let mantissa = raw / base
        let nice: Double = mantissa <= 1 ? 1 : (mantissa <= 2 ? 2 : (mantissa <= 5 ? 5 : 10))
        return nice * base
    }
}
