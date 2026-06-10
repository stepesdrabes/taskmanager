# 02 — System Metrics APIs

All APIs below were verified working **without root** on macOS 26.3 / M1 Pro. None require entitlements; all of them require the app to be **unsandboxed** (App Sandbox denies IOKit matching and filters several sysctls). This is the same toolbox used by Stats (exelban/stats) and iStat Menus.

## CPU

**Per-core usage** — `host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &ncpu, &info, &count)`.
Returns 4 tick counters per logical core (`CPU_STATE_USER/SYSTEM/IDLE/NICE`, see `mach/machine.h`). Usage % = tick deltas between two samples / total delta.

- Ticks are `UInt32` and wrap — always diff with wrap-safe `new &- old`.
- The returned array must be freed with `vm_deallocate` (use `defer`).
- **Core order on M-series is E-first**: indices `0..<hw.perflevel1.logicalcpu` are Efficiency cores, the rest Performance cores (verified via IODeviceTree `cluster-type` on M1 Pro: cpu0–1 = E, cpu2–7 = P). Keep this mapping in one helper — it is observed behavior, not a documented contract.

**Aggregate usage** — `host_statistics(HOST_CPU_LOAD_INFO)` (or sum the per-core deltas).

**Topology / static facts** (sysctl):
- Chip name: `machdep.cpu.brand_string` ("Apple M1 Pro")
- Core counts: `hw.nperflevels`, `hw.perflevel0.logicalcpu` (P), `hw.perflevel1.logicalcpu` (E), `hw.perflevel{N}.name`
- Caches per perflevel: `hw.perflevelN.l1icachesize`, `.l1dcachesize`, `.l2cachesize` (top-level `hw.l1*` returns E-core values — don't use)

**Processes / threads count** — `processor_set_default()` + `processor_set_statistics(PROCESSOR_SET_LOAD_INFO)` → `task_count`, `thread_count`. One call, no PID iteration. (`kern.num_tasks`/`kern.num_threads` are static limits, not live counts — don't use.)

**Load average** — `getloadavg(&loads, 3)`. **Uptime** — `sysctl kern.boottime` → `timeval`.

**Frequency** — no public API on Apple Silicon. Deferred (see overview).

## Memory

`host_statistics64(mach_host_self(), HOST_VM_INFO64, ...)` → `vm_statistics64`.
Page size: `vm_kernel_page_size` — **16 KB on Apple Silicon, never hardcode 4096**.

Activity-Monitor-compatible math (pages × page size):

| Display value | Formula |
|---|---|
| App Memory | `internal_page_count − purgeable_count` |
| Wired | `wire_count` |
| Compressed | `compressor_page_count` |
| **Memory Used** | App + Wired + Compressed |
| Cached Files | `external_page_count + purgeable_count` |
| Free | `free_count` |

- Total RAM: `sysctl hw.memsize`.
- Swap: `sysctlbyname("vm.swapusage")` → `xsw_usage { xsu_total, xsu_used, xsu_avail }`. Swap total is elastic on macOS (grows on demand) — display "X of Y allocated", never a percentage.
- Pressure: `sysctlbyname("kern.memorystatus_vm_pressure_level")` → 1 normal / 2 warning / 4 critical (undocumented but stable for a decade). For instant change events: `DispatchSource.makeMemoryPressureSource(eventMask: [.normal, .warning, .critical])` (public API).

## GPU

IOKit registry read — no connection open needed:

```
IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IOAccelerator"), &iterator)
→ IORegistryEntryCreateCFProperties(entry, ...)
```

Match the generic class `"IOAccelerator"` (not `"AGXAccelerator"`) so it works on any chip generation. On the accelerator node:

- `"PerformanceStatistics"` dict → `"Device Utilization %"` (headline), `"Renderer Utilization %"`, `"Tiler Utilization %"`, `"In use system memory"`, `"Alloc system memory"`
- Top-level: `"gpu-core-count"` (14 on this machine), `"model"` ("Apple M1 Pro")

**Every key is optional** — the set is undocumented and shifts between chips/OS releases. Parse defensively, render "—" for absent values. There is no per-GPU-core data anywhere; unified memory means "GPU memory" = shared system memory in use.

Use `kIOMainPortDefault` (`kIOMasterPortDefault` is deprecated since macOS 12).

## Disk

**Live I/O throughput** — enumerate IOKit class `"IOBlockStorageDriver"`, read its `"Statistics"` dict (public constants in `IOKit/storage/IOBlockStorageDriver.h`): `"Bytes (Read)"`, `"Bytes (Write)"`, `"Operations (Read/Write)"`, `"Total Time (Read/Write)"`. Counters are cumulative since boot → diff two samples for B/s. Clamp negative deltas to 0 (device removal).

Report **per physical disk** (e.g. `disk0`) — all APFS volumes in a container share one physical store, so per-volume I/O is not meaningful.

**Volume capacity** — `FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys:)` + `URL.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey, .volumeTotalCapacityKey, .volumeNameKey, .volumeIsInternalKey])`. `volumeAvailableCapacityForImportantUsage` is the figure that matches Finder (accounts for purgeable space) — use it, not `statfs` free blocks.

## Network

**Counters** — `sysctl` with `mib = [CTL_NET, PF_ROUTE, 0, 0, NET_RT_IFLIST2, 0]`, walk `if_msghdr2` records (`ifm_type == RTM_IFINFO2`) → `if_data64` → `ifi_ibytes`/`ifi_obytes` (**64-bit**). Map `ifm_index` → name via `if_indextoname()`.

> Why not `getifaddrs` for counters: its `if_data` counters are `u_int32_t` and wrap every 4 GiB — minutes on a fast link. Same for `ifi_baudrate` (caps at ~4.3 Gbps). Use `getifaddrs` only for **addresses** (`AF_INET`/`AF_INET6` + `getnameinfo(NI_NUMERICHOST)`).

> **macOS 26 caveat (found during implementation, verified by hexdump on 26.3):** for non-platform binaries the kernel degrades the `if_data64` *byte* counters anyway — quantized to 256 B and wrapped at 2^32. Packet counters and baudrate stay exact; platform binaries (netstat) get full values. Consequence: compute rates with 32-bit wrap-safe deltas (`new &- old`, discard deltas > 2 GiB as resets), and accumulate display totals since sampling start — true since-boot byte totals are not available to this app.

- **Primary interface**: `SCDynamicStoreCopyValue(nil, "State:/Network/Global/IPv4")` → `"PrimaryInterface"` (e.g. `"en0"`).
- **Display names**: `SCNetworkInterfaceCopyAll()` → match BSD name → `SCNetworkInterfaceGetLocalizedDisplayName` ("Wi-Fi", "Thunderbolt Ethernet").
- **SSID**: requires Location Services authorization since Sonoma — skipped by design. (RSSI/channel via CoreWLAN would work without it if ever wanted.)

## Processes (optional tab)

`proc_listallpids()` → per PID:
- `proc_pid_rusage(pid, RUSAGE_INFO_V4, ...)` → CPU % = Δ(`ri_user_time` + `ri_system_time`) / wall-clock interval (100 % = one core, matching Activity Monitor); memory = `ri_phys_footprint`.
- Name via `proc_name()`.
- Skip PIDs that error — details of other users' processes are partially restricted without root; that's expected and fine.

"End Task" = `kill(pid, SIGTERM)`; show an alert on `EPERM`. No SIGKILL escalation in v1.
