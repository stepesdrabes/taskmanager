# TaskManager

**Windows Task Manager, for the Mac.** A native, slim macOS system monitor — a System-Settings-style sidebar with live charts for everything your machine is doing.

> 🚧 In development — the full design is in [`plan/`](plan/01-overview.md).

## Features

- **CPU** — overall utilization history plus a Windows-style grid of per-core mini charts (with P-core / E-core badges), processes, threads, load average, uptime, core topology and cache sizes
- **Memory** — usage history, Activity-Monitor-style composition bar (App / Wired / Compressed / Cached / Free), memory pressure, swap
- **GPU** — device / renderer / tiler utilization, shared memory in use, core count
- **Disk** — live read/write throughput per physical disk, totals since boot, volume capacity bars that match Finder
- **Network** — live send/receive throughput per interface, totals since boot, IP addresses
- **Processes** — sortable table (CPU %, memory) with End Task

Everything updates live (configurable 0.5–5 s interval) and the app pauses sampling entirely while its window is hidden — it stays out of your way at ~0 % CPU.

## Requirements

- macOS 26 (Tahoe) or later, Apple Silicon
- Xcode 26 command-line tools (to build)

## Quickstart

```sh
make run    # release build → TaskManager.app → launches it
make dev    # swift run, for development
```

*(Available once the first build-order commits land — see [`plan/05-build-order.md`](plan/05-build-order.md).)*

## How it works

100 % native Swift / SwiftUI / Swift Charts, **zero third-party dependencies**, no Electron, no helpers, no root. Metrics come straight from the OS: Mach host calls for CPU and memory, IOKit for GPU and disk I/O, sysctl routing tables for network — all public-ish, root-free interfaces (details in [`plan/02-metrics-apis.md`](plan/02-metrics-apis.md)).

The app is unsandboxed and ad-hoc signed (the metric APIs don't work under App Sandbox), which makes it a personal/local tool rather than an App Store candidate.

**By design, no private APIs**: live CPU frequency and temperatures aren't exposed by public macOS APIs on Apple Silicon, so v1 deliberately leaves them out instead of faking them. Per-GPU-core usage isn't exposed by macOS at all (even to root tools).
