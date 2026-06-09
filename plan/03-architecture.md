# 03 — Architecture

## Project setup

Swift Package executable + Makefile that assembles a real `.app` bundle. No `.xcodeproj`, no Xcode GUI needed.

**Package.swift** (key lines):

```swift
// swift-tools-version: 6.2
platforms: [.macOS(.v26)],
.executableTarget(
    name: "TaskManager",
    swiftSettings: [.defaultIsolation(MainActor.self)]
)
```

**Makefile targets**:

| Target | Action |
|---|---|
| `make build` | `swift build -c release` → assemble `build/TaskManager.app/Contents/{MacOS,Resources}` → copy binary + `Support/Info.plist` → `codesign --force -s - build/TaskManager.app` |
| `make run` | build + `open build/TaskManager.app` |
| `make dev` | `swift run` (fast iteration) |
| `make clean` | remove `.build/` and `build/` |

**Support/Info.plist**: `CFBundlePackageType=APPL`, `CFBundleExecutable`, `CFBundleIdentifier=com.stepandrabek.taskmanager`, `CFBundleName`, `CFBundleShortVersionString`/`CFBundleVersion`, `CFBundleInfoDictionaryVersion=6.0`, `LSMinimumSystemVersion=26.0`, `NSPrincipalClass=NSApplication`, `NSHighResolutionCapable=true`.

**`swift run` gotcha**: an unbundled binary can't take focus and gets a grayed-out menu bar. Fix: always call `NSApplication.shared.setActivationPolicy(.regular)` + `NSApp.activate()` at launch — harmless inside the real bundle, makes `make dev` usable.

**Sandbox**: ad-hoc signing with no entitlements file = unsandboxed = all metric APIs work. Keep it that way.

## Directory layout

```
Package.swift, Makefile, Support/Info.plist, .gitignore
Sources/TaskManager/
  TaskManagerApp.swift          # @main, WindowGroup + Settings scenes, ⌘1..⌘6 Commands, occlusion observer
  MetricsStore.swift            # @Observable store + sampling loop (concurrency heart)
  Model/
    Snapshots.swift             # all Sendable snapshot structs
    RingBuffer.swift            # fixed-capacity generic ring buffer
    SystemInfo.swift            # one-shot static facts (chip, topology, caches, RAM, GPU model)
    Formatters.swift            # bytes, B/s, %, uptime, "nice" axis max
  Sampling/
    Sampler.swift               # orchestrator: owns sub-samplers, sample() -> Snapshot
    CPUSampler.swift  MemorySampler.swift  GPUSampler.swift
    DiskSampler.swift NetworkSampler.swift ProcessSampler.swift
  Views/
    ContentView.swift           # NavigationSplitView shell
    Section.swift               # enum: section + SF Symbol + tint
    CPUView / MemoryView / GPUView / DiskView / NetworkView / ProcessesView / SettingsView
    Components/
      HistoryChart.swift        # big Swift Charts area+line chart
      Sparkline.swift           # Canvas-drawn mini chart (per-core grid)
      StatGrid.swift            # Windows-TM-style label/value columns
      CompositionBar.swift      # stacked memory bar + legend
      SectionHeader.swift       # big title left, hardware name right
      SidebarIcon.swift         # white symbol on colored rounded rect (Settings look)
```

~22 source files. One file per metric reader, one view per section.

## Concurrency model (the load-bearing design)

The module compiles with `defaultIsolation(MainActor.self)` — everything is `@MainActor` by default (right for a UI app, kills most strict-concurrency friction). Consequence: **every type in `Model/` and `Sampling/` must be explicitly `nonisolated`**. This is the #1 convention of the codebase.

- **Snapshot structs** — `nonisolated struct ...: Sendable`, value types only. The full shape:
  - `Snapshot { date, cpu, memory, gpu?, disks[], volumes[], interfaces[] }`
  - `CPUSnapshot { totalBusy, coreBusy[], processCount, threadCount, load1/5/15 }` (coreBusy index = logical CPU id)
  - `MemorySnapshot { app, wired, compressed, cached, free, swapUsed, swapTotal, pressure }`
  - `GPUSnapshot { device?, renderer?, tiler?, usedMemory?, allocatedMemory? }` (all optional)
  - `DiskSnapshot { id (BSD name), readPerSec, writePerSec, totalRead, totalWritten }`
  - `VolumeSnapshot { path, name, total, available }`
  - `InterfaceSnapshot { id, displayName, rxPerSec, txPerSec, totalRx, totalTx, ipv4[], ipv6[], isPrimary }`
- **Samplers** — `nonisolated final class`es holding previous counters (CPU ticks, disk/network byte totals) for delta computation. They are **not** Sendable and don't need to be: the orchestrating `Sampler` is created *inside* the sampling task and never leaves it. Only Sendable snapshots cross the actor boundary. Do not refactor the sampler into a shared property — this pattern is what makes Swift 6 strict concurrency a non-issue.
- **Store + loop**:

```swift
@Observable @MainActor final class MetricsStore {
    private(set) var history = RingBuffer<Snapshot>(capacity: 120)
    let system: SystemInfo
    private var task: Task<Void, Never>?

    func start() {
        guard task == nil else { return }
        task = Task.detached(priority: .utility) { [weak self] in
            let sampler = Sampler()              // created inside the task — never shared
            let clock = ContinuousClock()
            while !Task.isCancelled {
                let snap = sampler.sample()      // first call only primes baselines
                await self?.append(snap)
                let interval = UserDefaults.standard.double(forKey: "updateInterval")
                try? await clock.sleep(for: .seconds(max(interval, 0.5)), tolerance: .seconds(0.1))
            }
        }
    }
    func stop() { task?.cancel(); task = nil }
}
```

- **Ring buffer**: one buffer of whole `Snapshot`s, capacity 120 (~2 min at 1 s). Views derive their series by mapping — no per-metric buffers. Fixed allocation, ~tens of KB total.
- **Pause when invisible**: observe `NSApplication.didChangeOcclusionStateNotification`; window not visible → `stop()`, visible → `start()`. Cancel the task entirely (a parked sleep still wakes the process).
- **Baseline reset**: every delta-based rate is garbage after a gap (pause, sleep/wake). The first sample after each `start()` only primes counters and is discarded — prevents giant fake spikes.
- **Memory pressure events**: a `DispatchSource.makeMemoryPressureSource` listener nudges an immediate refresh of the pressure indicator between ticks.

## Performance budget

- App visible at 1 s interval: ~1–2 % CPU, < 100 MB RAM.
- App hidden/minimized: ~0 % (sampling paused).
- Per-core grid open: no material change (Canvas sparklines, not Chart views).
- Timer tolerance 100 ms → kernel coalesces wakeups.
