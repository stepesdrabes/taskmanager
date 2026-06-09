# 01 — Overview & Scope

## Goal

A native macOS app that works like Windows Task Manager's Performance tab: a sidebar with CPU, Memory, GPU, Disk, Network (and Processes), each showing live, beautiful charts. Native look matching the macOS System Settings app. Slim and performant.

Target environment: macOS 26 (Tahoe), Apple Silicon. Developed and verified on an M1 Pro (2 E-cores + 6 P-cores, 14-core GPU, 16 GB RAM) with Xcode 26.5 / Swift 6.3.

## Decisions

- **macOS 26 only.** Building against the macOS 26 SDK gives the Liquid Glass design (floating glass sidebar, glass toolbars) automatically. No back-deployment burden.
- **Unsandboxed, ad-hoc signed.** The metric APIs (IOKit matching, Mach host calls, raw sysctl) are blocked under App Sandbox. This is a local tool, not an App Store candidate. `codesign --force -s -`, no entitlements.
- **Zero dependencies.** Apple frameworks only: SwiftUI, Charts, IOKit, SystemConfiguration, Darwin.
- **Swift Package + Makefile**, no `.xcodeproj`. Builds entirely from the command line; the Makefile assembles `build/TaskManager.app` from the SPM binary + `Support/Info.plist`.
- **Processes tab included**, built last (sortable table, CPU %/memory per process, "End Task" via SIGTERM).

## Deliberately out of scope for v1 (and why)

- **Live CPU frequency** — not exposed by any public API on Apple Silicon (`hw.cpufrequency` doesn't exist there). Root-free workarounds exist via the private `IOReport` library (what NeoAsitop/socpowerbud use), but it is undocumented and has broken across macOS releases. The CPU tab omits the "Speed" row rather than faking it. Possible later as an explicitly experimental feature.
- **Temperatures / fans** — require private SMC or IOHID interfaces with chip-specific undocumented keys. Best-effort at most, later.
- **Per-GPU-core utilization** — macOS does not expose it at all (even root-only `powermetrics` reports a single GPU figure). The GPU tab shows aggregate Device/Renderer/Tiler utilization plus core count; it never fakes per-core data.
- **Wi-Fi SSID** — gated behind Location Services permission since Sonoma. Skipped; everything else network-related works without prompts.

## Plan documents

| File | Contents |
|---|---|
| `02-metrics-apis.md` | The exact system APIs per metric, verified root-free, with caveats |
| `03-architecture.md` | Project layout, data model, concurrency design, app bundle assembly |
| `04-ui-spec.md` | Per-section UI spec, components, chart rules, native touches |
| `05-build-order.md` | Commit-by-commit build sequence |
| `06-verification.md` | How to verify each piece + design risks |
