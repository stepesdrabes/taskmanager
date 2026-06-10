# 05 — Build Order

Each commit compiles and runs. Conventional-commit messages per CLAUDE.md; no co-author trailers.

1. [x] `chore: init swift package with minimal app window`
   — `git init`, `.gitignore` (`.build/`, `build/`, `.DS_Store`), `Package.swift`, `TaskManagerApp.swift` showing an empty window incl. activation-policy fix. `swift run` shows a focusable window.
2. [x] `feat(build): add makefile and app bundle packaging`
   — Makefile, `Support/Info.plist`, ad-hoc codesign. `make run` launches the bundle with Dock icon.
3. [x] `feat(model): add snapshot types, ring buffer and system info`
   — `Snapshots.swift`, `RingBuffer.swift`, `SystemInfo.swift`, `Formatters.swift`.
4. [x] `feat(sampling): add cpu sampler with per-core usage`
   — `CPUSampler` + `Sampler` skeleton returning CPU-only snapshots.
5. [x] `feat(store): add metrics store with sampling loop`
   — `MetricsStore`, occlusion pause/resume, baseline reset. Temporary debug text proves live numbers.
6. [x] `feat(ui): add sidebar navigation with section placeholders`
   — `ContentView`, `Section` enum, `SidebarIcon`.
7. [x] `feat(ui): add shared chart, sparkline and stat grid components`
   — `HistoryChart`, `Sparkline`, `StatGrid`, `SectionHeader`.
8. [x] `feat(cpu): add cpu view with history chart and stats`
9. [x] `feat(cpu): add per-core sparkline grid toggle`
10. [ ] `feat(memory): add memory sampler`
11. [ ] `feat(memory): add memory view with composition bar`
12. [ ] `feat(gpu): add gpu sampler` — verify the PerformanceStatistics keys here (risk #1)
13. [ ] `feat(gpu): add gpu view`
14. [ ] `feat(disk): add disk sampler with per-disk io rates and volumes`
15. [ ] `feat(disk): add disk view with throughput chart and capacity bars`
16. [ ] `feat(network): add network sampler with primary interface detection`
17. [ ] `feat(network): add network view`
18. [ ] `feat(settings): add update interval setting and section shortcuts`
19. [ ] `docs: update readme and claude.md to match implementation`
20. [ ] `feat(processes): add process sampler`
21. [ ] `feat(processes): add sortable process table with end task`
22. [ ] `fix(ui): polish spacing, tints and dark mode` — the eyeball pass
