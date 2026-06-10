# TaskManager

**Windows Task Manager, reimagined for the Mac.** 🖥️

A slim, native macOS system monitor with a System-Settings-style sidebar and live charts for everything your machine is doing — CPU, memory, GPU, disk, network, battery, and processes. No Electron, no menu-bar clutter, no background daemon. Just a clean little window that tells you what's going on.

It feels at home on macOS because it *is* macOS — built entirely with SwiftUI and Apple's own frameworks, so it picks up Liquid Glass, dark mode, and your accent color automatically.

## What you get

| | |
|---|---|
| 🧠 **CPU** | Overall usage history plus a Windows-style grid of per-core mini charts, with P-core / E-core badges. Processes, threads, load average, uptime, and your chip's core layout and cache sizes. |
| 📊 **Memory** | A usage graph tinted by memory pressure, a stacked breakdown (App / Wired / Compressed / Cached), an Activity-Monitor-style composition bar, and swap. |
| 🎮 **GPU** | Device, renderer, and tiler utilization, shared memory in use, and core count. |
| 💾 **Disk** | Live read/write throughput per physical disk, totals, and volume capacity bars that match what Finder shows. |
| 🌐 **Network** | Live up/down throughput per interface (your active one is preselected), session totals, and IP addresses. |
| 🔋 **Energy** | Battery charge, live power draw, adapter wattage, health, cycle count, temperature, and time remaining. |
| 📋 **Processes** | A sortable table with per-process CPU, memory, and disk usage, app icons, search, and End Task / Force Kill. |
| 💻 **System Info** | A searchable rundown of your Mac: model, chip, displays, Metal, storage, OS, network, and more. |

Hover any chart to read the exact value at that moment. Everything refreshes live (pick 0.5–5 s in Settings, ⌘,), and **⌘1–⌘8** jump between sections.

It's also a considerate guest: when its window is hidden or minimized, sampling stops entirely, so it idles at essentially **0% CPU**.

## Requirements

- A Mac with **Apple Silicon**
- **macOS 26 (Tahoe)** or later
- **Xcode 26** command-line tools to build it

## Get it running

```sh
make run    # build a release .app and launch it
make dev    # run straight from source while hacking on it
make clean  # remove build artifacts
```

That's it — no signing setup, no dependencies to fetch.

## Languages

TaskManager speaks **English** and **Czech** out of the box, and picks your Mac's language automatically (falling back to English). You can also choose a language by hand in **Settings → Language**.

Each language is a single JSON file in [`Sources/TaskManager/Localizations/`](Sources/TaskManager/Localizations) — `en.json`, `cs.json`, and so on. Adding your own takes a few minutes and **no code**:

1. **Copy `en.json`** to `<code>.json`, where `<code>` is your language's two-letter code — `de` for German, `fr` for French, `pl` for Polish…
2. **Set the `language` block** at the top — the `code` and the `name` that shows up in the Settings dropdown:
   ```json
   "language": { "code": "de", "name": "Deutsch" }
   ```
3. **Translate the right-hand side** of each `"key": "value"` pair. Leave the keys (the left side) exactly as they are — those are what the app looks up.
4. **Keep anything in `{curly braces}`** untouched — they're slots the app fills in at runtime, like `"{used} of {total} allocated"`. Move them around to fit your grammar, just don't rename them.
5. **Rebuild** with `make run`. Your language shows up in Settings automatically.

If a key is ever missing from your file, the app quietly falls back to the English text, so a partial translation still works.

## A few honest notes

- **It runs unsandboxed.** The system APIs it reads (IOKit, low-level sysctls) are blocked by the App Sandbox, so the app ships ad-hoc signed and sandbox-free. That makes it a great personal tool, but not an App Store candidate.
- **No private APIs, ever.** A couple of things you might expect are intentionally left out because macOS doesn't expose them publicly on Apple Silicon: live per-core CPU *frequency* and *temperatures* (private interfaces only), and per-GPU-*core* utilization (which even Apple's own root tools don't report). TaskManager would rather show nothing than make up a number.
- **Power draw updates slowly.** It reads real system wattage from the battery controller, which only refreshes every 30–60 s — so the Energy graph tracks sustained draw, not momentary spikes.
- **Network totals are per session.** macOS 26 fuzzes byte counters for third-party apps, so throughput is computed carefully and totals count from when the app started rather than since boot.

## Under the hood

100% native Swift, SwiftUI, and Swift Charts with **zero third-party dependencies**. Metrics come straight from the OS — Mach calls for CPU and memory, IOKit for GPU, disk, and battery, and routing-table sysctls for network. If you'd like to poke around or add a metric of your own, [`CLAUDE.md`](CLAUDE.md) walks through how the project is put together.
