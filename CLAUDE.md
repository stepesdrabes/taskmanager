# Rules

commit rule: do commits in format "feat(frontend): test test", "fix(backend): lmao".
commit rule: NO Co-Authored-By / co-author trailers in commit messages.
code styles rule: do not put over-engineered messages into the code -> only actually helpful

# Project

TaskManager — native macOS system monitor (Windows Task Manager style): SwiftUI sidebar with CPU / Memory / GPU / Disk / Network / Processes sections, live charts, per-core CPU grid. Targets macOS 26 only, Apple Silicon. Zero dependencies beyond Apple frameworks (SwiftUI, Charts, IOKit, SystemConfiguration, Darwin).

The full design lives in `plan/` (read `plan/01-overview.md` first). Build the app following `plan/05-build-order.md`, one commit per step.

# Build commands

(Defined in `plan/03-architecture.md`; available once `Package.swift` + `Makefile` land — commit 1–2 of the build order.)

- `make dev` — `swift run`, fast iteration
- `make run` — release build, assemble + ad-hoc sign `build/TaskManager.app`, open it
- `make clean` — remove `.build/` and `build/`

# Architecture conventions

- The module compiles with `defaultIsolation(MainActor.self)` — every type in `Model/` and `Sampling/` must be explicitly `nonisolated`.
- Samplers are nonisolated classes created **inside** the sampling task and never shared; only `Sendable` snapshot structs cross to the `@MainActor` store. Don't refactor samplers into shared properties.
- The app must stay **unsandboxed** with ad-hoc signing and no entitlements — IOKit matching and several sysctls break under App Sandbox.
- Charts never animate on data updates (1 Hz update jank). Per-core grids use Canvas sparklines, never stacks of `Chart` views.
- All delta-based rates (CPU ticks, disk/network bytes) discard the first sample after a sampling restart — prevents fake spikes after pause/sleep.
- No external package dependencies.

# Adding a metric

1. Add a `nonisolated ... Sendable` struct to `Model/Snapshots.swift` and a field on `Snapshot`.
2. Add a sampler file in `Sampling/`, wire it into `Sampler.sample()`.
3. Read it in a view from the store's ring buffer (`history`), reusing `Components/` (HistoryChart, StatGrid, Sparkline).
