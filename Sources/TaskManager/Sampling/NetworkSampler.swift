import Darwin
import Foundation
import SystemConfiguration

/// macOS 26 degrades NET_RT_IFLIST2 byte counters for non-platform binaries:
/// quantized to 256 B and wrapped at 2^32 (packet counters stay exact; verified
/// against netstat). Rates therefore use 32-bit wrap-safe deltas, and totals
/// accumulate since sampling started — true since-boot totals aren't available.
nonisolated final class NetworkSampler {
    private struct Counters {
        var rx: UInt32 = 0
        var tx: UInt32 = 0
    }

    private struct Totals {
        var rx: UInt64 = 0
        var tx: UInt64 = 0
    }

    private var previous: [String: Counters] = [:]
    private var totals: [String: Totals] = [:]
    private var previousDate: Date?

    /// Wrap-safe 32-bit delta; treats implausibly huge jumps (counter reset,
    /// >2 GiB between samples) as 0.
    private func delta(_ new: UInt32, _ old: UInt32) -> UInt64 {
        let difference = new &- old
        return difference > 0x8000_0000 ? 0 : UInt64(difference)
    }

    private func string(fromCString buffer: [CChar]) -> String {
        String(decoding: buffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self)
    }

    func sample() -> [InterfaceSnapshot] {
        let now = Date()
        let elapsed = previousDate.map { now.timeIntervalSince($0) } ?? 0
        previousDate = now

        let counters = byteCounters()
        defer { previous = counters }

        let names = displayNames()
        let ips = addresses()
        let primary = primaryInterface()

        // Only interfaces SystemConfiguration knows by name are real adapters;
        // this drops lo0, utun*, awdl* and friends.
        var interfaces: [InterfaceSnapshot] = []
        for (bsdName, current) in counters {
            guard let displayName = names[bsdName] else { continue }
            var rxRate = 0.0
            var txRate = 0.0
            var total = totals[bsdName] ?? Totals()
            if elapsed > 0, let old = previous[bsdName] {
                let rxDelta = delta(current.rx, old.rx)
                let txDelta = delta(current.tx, old.tx)
                rxRate = Double(rxDelta) / elapsed
                txRate = Double(txDelta) / elapsed
                total.rx += rxDelta
                total.tx += txDelta
                totals[bsdName] = total
            }
            interfaces.append(InterfaceSnapshot(
                id: bsdName,
                displayName: displayName,
                rxPerSec: rxRate,
                txPerSec: txRate,
                totalRx: total.rx,
                totalTx: total.tx,
                ipv4: ips[bsdName]?.v4 ?? [],
                ipv6: ips[bsdName]?.v6 ?? [],
                isPrimary: bsdName == primary
            ))
        }
        interfaces.sort {
            ($0.isPrimary ? 0 : 1, $0.id) < ($1.isPrimary ? 0 : 1, $1.id)
        }
        return interfaces
    }

    /// 64-bit counters from NET_RT_IFLIST2 — getifaddrs' if_data is 32-bit and
    /// wraps every 4 GiB (plan/02).
    private func byteCounters() -> [String: Counters] {
        var mib: [Int32] = [CTL_NET, PF_ROUTE, 0, 0, NET_RT_IFLIST2, 0]
        var length = 0
        guard sysctl(&mib, 6, nil, &length, nil, 0) == 0, length > 0 else { return [:] }
        var buffer = [UInt8](repeating: 0, count: length)
        guard sysctl(&mib, 6, &buffer, &length, nil, 0) == 0 else { return [:] }

        var result: [String: Counters] = [:]
        buffer.withUnsafeBytes { raw in
            var offset = 0
            while offset + MemoryLayout<if_msghdr>.size <= length {
                let header = raw.loadUnaligned(fromByteOffset: offset, as: if_msghdr.self)
                guard header.ifm_msglen > 0 else { break }
                if Int32(header.ifm_type) == RTM_IFINFO2,
                   offset + MemoryLayout<if_msghdr2>.size <= length {
                    let header2 = raw.loadUnaligned(fromByteOffset: offset, as: if_msghdr2.self)
                    var name = [CChar](repeating: 0, count: Int(IF_NAMESIZE) + 1)
                    if if_indextoname(UInt32(header2.ifm_index), &name) != nil {
                        result[string(fromCString: name)] = Counters(
                            rx: UInt32(truncatingIfNeeded: header2.ifm_data.ifi_ibytes),
                            tx: UInt32(truncatingIfNeeded: header2.ifm_data.ifi_obytes)
                        )
                    }
                }
                offset += Int(header.ifm_msglen)
            }
        }
        return result
    }

    private func primaryInterface() -> String? {
        guard let value = SCDynamicStoreCopyValue(nil, "State:/Network/Global/IPv4" as CFString) as? [String: Any] else {
            return nil
        }
        return value["PrimaryInterface"] as? String
    }

    private func displayNames() -> [String: String] {
        guard let all = SCNetworkInterfaceCopyAll() as? [SCNetworkInterface] else { return [:] }
        var names: [String: String] = [:]
        for interface in all {
            if let bsd = SCNetworkInterfaceGetBSDName(interface) as String?,
               let name = SCNetworkInterfaceGetLocalizedDisplayName(interface) as String? {
                names[bsd] = name
            }
        }
        return names
    }

    private func addresses() -> [String: (v4: [String], v6: [String])] {
        var list: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&list) == 0 else { return [:] }
        defer { freeifaddrs(list) }

        var result: [String: (v4: [String], v6: [String])] = [:]
        var pointer = list
        while let current = pointer {
            defer { pointer = current.pointee.ifa_next }
            guard let sockaddr = current.pointee.ifa_addr else { continue }
            let family = Int32(sockaddr.pointee.sa_family)
            guard family == AF_INET || family == AF_INET6 else { continue }

            var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            guard getnameinfo(sockaddr, socklen_t(sockaddr.pointee.sa_len), &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST) == 0 else {
                continue
            }
            let name = String(cString: current.pointee.ifa_name)
            // getnameinfo appends the scope to scoped IPv6 addresses ("fe80::1%en0").
            let address = string(fromCString: host).components(separatedBy: "%")[0]

            var entry = result[name] ?? (v4: [], v6: [])
            if family == AF_INET {
                entry.v4.append(address)
            } else if !address.hasPrefix("fe80") {
                entry.v6.append(address)
            }
            result[name] = entry
        }
        return result
    }
}
