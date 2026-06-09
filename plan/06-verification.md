# 06 — Verification & Risks

## Verification playbook

Run after commit 5, then after every section commit, with Activity Monitor open beside the app.

**Run modes**
- `make dev` for iteration; `make run` once per phase — bundle launches, Dock icon appears, `codesign -dv build/TaskManager.app` verifies.

**CPU**
- `yes > /dev/null &` → overall settles near 12.5 % (1 of 8 cores) and exactly one P-core sparkline pins at ~100 % (the scheduler may migrate it). `killall yes` after.
- At idle, E-cores (0–1) are visibly busier than P-cores — confirms the E/P index mapping.
- Processes / Threads vs Activity Monitor's CPU-tab footer (small drift OK). Up time and load avg vs `uptime`.

**Memory**
- App / Wired / Compressed / Cached / Swap match Activity Monitor's Memory tab within one sample. Total = 16 GB. Pressure dot green under normal load.

**GPU**
- Idle ≈ 0–5 %. Play a 4K YouTube video or a WebGL demo → utilization rises. Cross-check the curve shape against Activity Monitor → Window → GPU History.

**Disk**
- `dd if=/dev/zero of=/tmp/ddtest bs=1m count=2048 && rm /tmp/ddtest` → write series spikes; magnitude comparable to Activity Monitor's Disk tab.
- Free space figure matches Finder → Get Info on Macintosh HD (that's what the importantUsage key is for).

**Network**
- Large download (`curl -o /dev/null <big file URL>`) → receive series matches Activity Monitor's Network tab. IPs match `ifconfig en0`.

**Slimness / edge cases**
- Minimize the window → the app's own CPU in Activity Monitor drops to ~0 (occlusion pause works). Restore → charts resume with **no negative or giant spike** (baseline reset works).
- Sleep/wake the Mac with the app running → same no-spike check.
- Change interval in Settings → cadence changes within one tick, no task restart needed.
- Self-footprint targets: ~1–2 % CPU at 1 s interval, < 100 MB RAM; opening the per-core grid changes neither materially.

**Look**
- Sidebar matches System Settings in light and dark mode; charts never animate/flicker on update; window resizes cleanly; ⌘1–⌘6 switch sections; ⌘, opens Settings.

## Risks & mitigations

1. **GPU `PerformanceStatistics` keys are fragile** (undocumented, shift between chips/OS). → All-optional parsing, "—" placeholders; verify at commit 12; if `Device Utilization %` is absent, promote `Renderer Utilization %` to the headline series.
2. **E-first core ordering is observed, not contractual.** → Mapping lives in one `SystemInfo` helper; a future chip with different ordering is a one-line fix.
3. **`defaultIsolation(MainActor)` vs C interop** — the likeliest compile friction. → Strict convention: every Model/Sampling type explicitly `nonisolated`; keep the sampler-created-inside-the-task pattern; never share sampler instances.
4. **Delta-rate spikes after pause/sleep.** → Discard the first sample after every `start()`; test sleep/wake explicitly.
5. **Throughput chart axis jitter.** → "Nice max" rounding (1/2/5×10ⁿ) in `Formatters.swift` is load-bearing; never use raw window max.
6. **Swap total is elastic** on macOS. → Label "allocated", never compute used/total %.
7. **Processes table perf** (~600 rows × 2 s into a SwiftUI Table). → Own slow cadence, sample only while visible, stable Identifiable rows; fallback: top 100 by CPU.
8. **Ad-hoc signing** → Gatekeeper blocks the app on other Macs. Fine for a personal tool; out of scope otherwise.
