# Rules

commit rule: do commits in format "feat(frontend): test test", "fix(backend): lmao".
commit rule: NO Co-Authored-By / co-author trailers in commit messages.
code styles rule: do not put over-engineered messages into the code -> only actually helpful

# Project

TaskManager — a native macOS system monitor in the spirit of Windows Task Manager: a SwiftUI sidebar with **CPU / Memory / GPU / Disk / Network / Energy / Processes / System Info** sections. Most are live charts; System Info is a searchable list of static facts. Targets **macOS 26 only, Apple Silicon**. Zero dependencies beyond Apple frameworks (SwiftUI, Charts, IOKit, SystemConfiguration, Metal, Darwin).

# Build & run

- `make dev` — `swift run`, fast iteration loop while coding
- `make run` — release build, assemble + ad-hoc sign `build/TaskManager.app`, then open it
- `make clean` — remove `.build/` and `build/`

The app is a SwiftPM executable (no `.xcodeproj`). The `Makefile` hand-assembles the `.app` bundle from the built binary plus `Support/Info.plist`, then `codesign --force -s -` (ad-hoc, no entitlements). `make dev` runs the bare binary; `TaskManagerApp.init()` calls `setActivationPolicy(.regular)` + `activate()` so an unbundled run still gets a Dock icon and focus.

# How it fits together

```
        ┌─────────────── background sampling Task (utility QoS) ───────────────┐
        │  Sampler  ──owns──►  CPUSampler, MemorySampler, GPUSampler,          │
        │    │                 DiskSampler, NetworkSampler, EnergySampler      │
        │    └─ sample() ─► Snapshot (Sendable value type) ──┐                 │
        └────────────────────────────────────────────────────│────────────────┘
                                                              ▼  await
   @MainActor @Observable MetricsStore  ──  RingBuffer<Snapshot>(capacity: 120)
                                                              │
                                                              ▼  reads `history`
                        SwiftUI views (ContentView → section views → Components)
```

One sample per tick (default 1 s) produces one immutable `Snapshot`. The store keeps the last 120 in a ring buffer; views derive their series by mapping over `history`. Processes are sampled separately (see below).

## Directory layout

- `TaskManagerApp.swift` — `@main`. Owns the `MetricsStore`, the `WindowGroup`, the `Settings` scene, the `View` command menu (⌘1–⌘7), and the occlusion observer that pauses sampling when the window is hidden.
- `MetricsStore.swift` — the `@MainActor @Observable` store. Runs the sampling loop, holds `history`, `selectedSection`, and the live `processes` array.
- `Localizer.swift` — the localization engine (see Localization below); `Localizations/` holds the per-language JSON.
- `Model/`
  - `Snapshots.swift` — every `Sendable` snapshot struct: the top-level `Snapshot` plus `CPUSnapshot`, `MemorySnapshot`, `GPUSnapshot?`, `[DiskSnapshot]`, `[VolumeSnapshot]`, `[InterfaceSnapshot]`, `EnergySnapshot?`, and the standalone `ProcessRow`.
  - `SystemInfo.swift` — one-shot static facts (chip name, core topology, cache sizes, total RAM, GPU model). Read once at launch via the `Sysctl` helper.
  - `RingBuffer.swift` — fixed-capacity generic ring buffer.
  - `Formatters.swift` — the `Format` enum: bytes, rates, percentages, uptime, and `niceMax` (rounds chart axes to 1/2/5×10ⁿ so they don't jitter).
- `Sampling/`
  - `Sampler.swift` — the orchestrator; owns one of each sub-sampler and builds a `Snapshot` in `sample()`.
  - One file per metric (`CPUSampler`, `MemorySampler`, …). Each holds the previous counters it needs for delta math.
  - `ProcessSampler.swift` — produces `[ProcessRow]`; driven by its own task, not part of `Snapshot`.
- `Views/`
  - `ContentView.swift` — the `NavigationSplitView`: sidebar list + a `switch` that maps the selected `MonitorSection` to its detail view.
  - `MonitorSection.swift` — the section enum; the single source of truth for each section's title, SF Symbol, and tint.
  - One view per section (`CPUView`, `MemoryView`, …) plus `SettingsView`.
  - `Components/` — shared building blocks: `SectionScrollView`, `HistoryChart`, `Sparkline`, `StatGrid`, `CompositionBar`, `SectionHeader`, `SidebarIcon`, `ChartHover`.

## Localization

- One JSON file per language in `Sources/TaskManager/Localizations/` (`en.json` is the source of truth; `cs.json` is the Czech translation). Authored nested by area; bundled as an SPM resource (`.copy("Localizations")`) and copied into the `.app` by the Makefile. `Localizer` locates that resource bundle itself — `Contents/Resources` in the assembled `.app`, or beside the binary under `swift run` — rather than via SwiftPM's generated `Bundle.module`, whose baked-in build-machine path crashes once the app is moved off the build host.
- `Localizer` (`@Observable @MainActor`, injected via `.environment`) loads the chosen language, flattens the nested JSON to dotted keys, fills `{placeholder}` tokens, and falls back English → key. `preference` is `"system"` (default — follow the OS language) or a concrete code; changing it is **live** (views re-render because `strings` is observed).
- Views read `@Environment(Localizer.self) private var loc` and call `loc("section.key")`, or `loc("memory.swap", ["used": a, "total": b])` for templated strings. **No user-facing string literal belongs in a view** — every new string goes into *both* JSON files (English required, others fall back).
- `MonitorSection` carries only a `titleKey`; section names are localized at the call site. `SystemReport.gather(system:loc:)` takes the localizer because its labels are localized too.

## Sampling & concurrency model (the important part)

The module compiles with `defaultIsolation(MainActor.self)`, so everything is `@MainActor` unless said otherwise. The sampling pipeline lives off the main actor and crosses back via `Sendable` values:

- The `Sampler` and every sub-sampler are **`nonisolated` classes created *inside* the detached sampling task** and never shared or stored on the store. They hold mutable state (previous CPU ticks, disk/network byte totals) and are deliberately *not* `Sendable` — confining them to the task is what keeps them safe. **Don't** hoist a sampler into a stored property to "reuse" it; that breaks the model.
- Only the `Snapshot` (a `Sendable` value type) crosses back to the `@MainActor` store, via `await store.append(...)`.
- **Every type in `Model/` and `Sampling/` must be explicitly `nonisolated`** — they're touched from the background task. If you add one and forget, you'll get an isolation error or a surprise hop to main.

Two independent tasks run in the store:
1. **Main metrics loop** (`start()`/`stop()`): samples all sections, sleeps `updateInterval` (re-read each tick from `UserDefaults`) with a 0.1 s tolerance so the kernel can coalesce wakeups. Paused via `NSApplication.didChangeOcclusionStateNotification` when the window isn't visible.
2. **Process loop** (`startProcessSampling()`/`stopProcessSampling()`): a slower (~2 s) loop that only runs while the Processes tab is on screen. Process rows are heavier to gather and need no history, so they live outside the ring buffer.

## Conventions & gotchas

- **Unsandboxed, always.** IOKit service matching and several sysctls are blocked by App Sandbox, so the app stays sandbox-free with ad-hoc signing and no entitlements.
- **Charts never animate on data updates.** Animating a 1 Hz refresh looks janky; mutate the model without `withAnimation`.
- **Per-core grids use `Canvas` sparklines, never a stack of `Chart` views** — dozens of live `Chart`s tank performance.
- **Discard the first sample after any restart.** All delta-based rates (CPU ticks, disk/network bytes) are garbage across a pause/sleep gap, so the first post-restart sample only primes baselines.
- **macOS 26 degrades network byte counters** for non-platform binaries (quantized to 256 B, wrapped at 2³²). Network rates use 32-bit wrap-safe deltas and totals are session-relative — never "since boot".
- **No private APIs.** Live CPU frequency, temperatures, and per-GPU-core stats aren't publicly available on Apple Silicon; we leave them out rather than fake them. Energy/power telemetry is public but slow (~30–60 s refresh).
- **No external package dependencies.** Apple frameworks only.

# Recipes

## Add a metric to an existing section

1. Add fields to the relevant snapshot struct in `Model/Snapshots.swift` (keep it `nonisolated ... Sendable`).
2. Populate them in that section's sampler in `Sampling/`. If it's a rate, store the previous counter on the sampler and compute a wrap-safe delta; clamp negatives to 0.
3. Read it in the section view from `store.latest` (current value) or `store.history.elements` (the series), and surface it with an existing `Components/` piece — `StatGrid.Item` for a number, a new `HistoryChart.Series` for a line. Add any new label to **both** JSON files and reference it via `loc("…")`.

## Add a whole new section

1. Add a `Sendable` snapshot struct + a field on `Snapshot` in `Model/Snapshots.swift`.
2. Add a `nonisolated` sampler in `Sampling/` and wire it into `Sampler.sample()`.
3. Add a case to `MonitorSection` (SF Symbol, tint) and a `section.<name>` entry to every JSON file — this adds the localized sidebar row and ⌘-shortcut automatically. Note: there is no `gpu` SF Symbol; that case reuses `cpu.fill` differentiated by tint.
4. Create `Views/<Name>View.swift` wrapping its content in `SectionScrollView(title: loc("section.<name>"), subtitle:)` (gives the header + scroll-driven toolbar title for free), and add the case to the `switch` in `ContentView`. Localize every label via `loc(…)`.

## Useful shared components

- `SectionScrollView(title:subtitle:) { … }` — the standard section container.
- `HistoryChart` — the big line/area chart. One series → filled; multiple → lines; pass `stacked: true` for a stacked area. Hover tooltips are built in.
- `Sparkline` — lightweight `Canvas` mini-chart for grids.
- `StatGrid` — the label/value stat blocks; build `[StatGrid.Item]`.
- `CompositionBar` — the stacked horizontal bar (used by Memory).

# Verifying changes

`make dev`, then sanity-check numbers against Activity Monitor / `top` / `ioreg` / `pmset -g batt`. For samplers, a quick `swiftc -parse-as-library` harness over `Model/Snapshots.swift` + the one sampler is the fastest way to confirm raw values before wiring up UI. Generate load to see charts move: `yes >/dev/null &` (CPU), `dd if=/dev/zero of=/tmp/x bs=1m count=2048` (disk), a large `curl` download (network).
