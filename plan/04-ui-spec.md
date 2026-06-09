# 04 — UI Spec

## Shell

`NavigationSplitView` with a `List(selection:)` in `.listStyle(.sidebar)` — the System Settings pattern. Building against the macOS 26 SDK gives Liquid Glass (floating glass sidebar, glass toolbars) automatically; do not add custom materials behind the sidebar. Sidebar rows are `Label`s using `SidebarIcon`: white SF Symbol on a small (~24 pt) colored `RoundedRectangle`, exactly like System Settings.

| Section | SF Symbol | Tint |
|---|---|---|
| CPU | `cpu` | blue |
| Memory | `memorychip` | green |
| GPU | `cpu.fill` — **no `gpu` symbol exists**, differentiate by tint | purple |
| Disk | `internaldrive` | orange |
| Network | `network` | teal |
| Processes | `list.bullet.rectangle` | gray |

Every section detail: `ScrollView` → `SectionHeader` (big title left, hardware name right — like Windows TM's "CPU … Apple M1 Pro" line) → big chart (~240 pt) → `StatGrid` (label/value columns).

Native touches: `Settings` scene (⌘,), View menu via `.commands` with ⌘1–⌘6 section switching, automatic dark/light (semantic colors only — never hardcoded RGB backgrounds), accent-colored sidebar selection (automatic).

## Chart rules (apply everywhere)

- Big charts: Swift Charts — `AreaMark` with a LinearGradient (tint → clear) + `LineMark` on top, `.interpolationMethod(.monotone)`.
- Fixed X domain of 120 points (index-based) — no axis churn; `.chartXAxis(.hidden)` for the Task-Manager look.
- Percentage charts: `.chartYScale(domain: 0...100)`, fixed.
- Throughput charts (disk/network): Y = "nice" rolling max — max over the visible window rounded up to 1/2/5×10ⁿ B/s. Never raw max (axis jitter).
- **No animation on data updates** — mutate the model without `withAnimation`. Animated 1 Hz updates are the known Swift Charts jank source.
- Per-core grid: hand-drawn `Canvas` sparklines (filled path + stroke from the ring buffer) in `LazyVGrid(columns: [.init(.adaptive(minimum: 140))])`. **Never 8–40 `Chart` views** — each carries axes/scales/layout machinery.

## Sections

### CPU — "CPU" / "Apple M1 Pro"
- Segmented picker top-right: **Overall** | **Logical cores**.
  - Overall: big utilization chart, 0–100 %.
  - Logical cores: grid of per-core sparklines, each titled "Core N" with an E/P badge; E-cores teal, P-cores blue (E-cores are the low indices on M-series).
- StatGrid live: Utilization, Processes, Threads, Up time, Load avg ("1.2 / 1.5 / 1.8").
- StatGrid static (from SystemInfo): Performance cores 6, Efficiency cores 2, Logical processors 8, L1i/L1d + L2 per core type. **No "Base speed" row** — frequency is deferred; omit rather than fake.

### Memory — "Memory" / "16 GB"
- Big chart: Memory Used over time, Y fixed 0…total RAM.
- `CompositionBar`: stacked horizontal bar — App / Wired / Compressed / Cached / Free, distinct colors + legend with values (Activity Monitor style).
- StatGrid: Used, App Memory, Wired, Compressed, Cached Files, Swap ("512 MB of 1 GB allocated"), Memory Pressure with colored dot (green/yellow/red).

### GPU — "GPU" / model string
- Big chart: Device Utilization %, 0–100.
- Two small sparklines side by side: Renderer %, Tiler %.
- StatGrid: Utilization, GPU memory in use / allocated ("shared memory" wording), Cores, Type "Integrated (shared memory)". Absent keys render "—". No per-core grid — the data doesn't exist on macOS.

### Disk — one block per physical disk
- Big chart, two series: Read (green) / Write (red), nice-max Y.
- StatGrid: Read speed, Write speed, Total read / written since boot.
- Below: per-volume capacity bars — "Macintosh HD — 312 GB of 494 GB used" (Finder-matching free space). Don't over-engineer volume→disk mapping (APFS shares one store); a flat "Volumes" list is fine.

### Network
- Picker over active interfaces (up or nonzero traffic), defaulting to the system primary.
- Big chart, two series: Receive (blue) / Send (orange), nice-max Y.
- StatGrid: Receive, Send (live), Total received / sent since boot, Adapter "Wi-Fi (en0)", IPv4, IPv6 (first non-link-local). SSID intentionally omitted (Location-gated).

### Processes (built last)
- SwiftUI `Table` with `KeyPathComparator` sorting: Name, PID, CPU %, Memory.
- Own 2 s cadence, sampled **only while the tab is selected**; plain `[ProcessRow]` array, no history.
- Toolbar "End Task" button → SIGTERM, alert on permission failure.
- If it stutters: cap to top 100 rows by CPU.

### Settings (⌘,)
- One `Form`: update interval `Picker` (0.5 / 1 / 2 / 5 s), `@AppStorage("updateInterval")`, default 1 s. Footnote: "History window: 120 samples".
