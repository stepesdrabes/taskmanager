import Charts
import SwiftUI

struct MemoryView: View {
    @Environment(MetricsStore.self) private var store
    @State private var display: MemoryDisplay = .used
    @State private var hoverIndex: Int?

    private enum MemoryDisplay: String, CaseIterable, Identifiable {
        case used = "Used"
        case breakdown = "Breakdown"
        var id: Self { self }
    }

    var body: some View {
        SectionScrollView(title: "Memory", subtitle: Format.bytes(store.system.memoryTotal)) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline) {
                    Text(display == .used ? "Memory used (colored by pressure)" : "Memory breakdown")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Picker("Display", selection: $display) {
                        ForEach(MemoryDisplay.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .fixedSize()
                }
                if display == .used {
                    usedChart
                } else {
                    breakdownChart
                }
            }

            if let memory = store.latest?.memory {
                CompositionBar(
                    segments: [
                        .init(label: "App", value: memory.app, color: .green),
                        .init(label: "Wired", value: memory.wired, color: .indigo),
                        .init(label: "Compressed", value: memory.compressed, color: .orange),
                        .init(label: "Cached", value: memory.cached, color: .gray),
                    ],
                    total: store.system.memoryTotal
                )

                StatGrid(items: items(for: memory))

                HStack(spacing: 6) {
                    Circle()
                        .fill(pressureColor(memory.pressure))
                        .frame(width: 8, height: 8)
                    Text("Memory pressure: \(pressureLabel(memory.pressure))")
                        .font(.callout)
                }
            }
        }
    }

    // MARK: Used chart, segmented by pressure level

    private struct PressureSegment: Identifiable {
        let id: Int
        let color: Color
        let points: [(x: Int, y: Double)]
    }

    private var usedChart: some View {
        Chart {
            ForEach(pressureSegments) { segment in
                ForEach(segment.points, id: \.x) { point in
                    AreaMark(
                        x: .value("Time", point.x),
                        y: .value("Used", point.y),
                        series: .value("Area", "area-\(segment.id)"),
                        stacking: .unstacked
                    )
                    .foregroundStyle(.linearGradient(
                        colors: [segment.color.opacity(0.35), segment.color.opacity(0.03)],
                        startPoint: .top,
                        endPoint: .bottom
                    ))
                    .interpolationMethod(.monotone)

                    LineMark(
                        x: .value("Time", point.x),
                        y: .value("Used", point.y),
                        series: .value("Line", "line-\(segment.id)")
                    )
                    .foregroundStyle(segment.color)
                    .lineStyle(StrokeStyle(lineWidth: 1.5))
                    .interpolationMethod(.monotone)
                }
            }

            if let hoverIndex {
                RuleMark(x: .value("Time", hoverIndex))
                    .foregroundStyle(.secondary.opacity(0.4))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    .annotation(
                        position: .top,
                        alignment: .center,
                        spacing: 4,
                        overflowResolution: .init(x: .fit(to: .chart), y: .fit(to: .chart))
                    ) {
                        ChartTooltip(rows: usedRows(at: hoverIndex))
                    }
            }
        }
        .chartXScale(domain: 0...(store.history.capacity - 1))
        .chartYScale(domain: 0...Double(store.system.memoryTotal))
        .chartXAxis(.hidden)
        .chartYAxis {
            AxisMarks { value in
                AxisGridLine()
                AxisValueLabel {
                    if let number = value.as(Double.self) {
                        Text(Format.bytes(UInt64(number)))
                    }
                }
            }
        }
        .chartXHover(capacity: store.history.capacity, selection: $hoverIndex)
        .frame(height: 240)
    }

    /// Splits history into runs of equal pressure; each run shares its first
    /// point with the previous run so the line stays connected.
    private var pressureSegments: [PressureSegment] {
        let snapshots = store.history.elements
        let offset = store.history.capacity - snapshots.count
        var segments: [PressureSegment] = []
        var points: [(x: Int, y: Double)] = []
        var pressure: MemoryPressure?

        func close() {
            if points.count > 1, let pressure {
                segments.append(PressureSegment(id: segments.count, color: pressureColor(pressure), points: points))
            }
        }

        for (index, snapshot) in snapshots.enumerated() {
            if snapshot.memory.pressure != pressure {
                close()
                points = points.last.map { [$0] } ?? []
                pressure = snapshot.memory.pressure
            }
            points.append((x: index + offset, y: Double(snapshot.memory.used)))
        }
        close()
        return segments
    }

    private func usedRows(at index: Int) -> [ChartTooltip.Row] {
        let snapshots = store.history.elements
        let i = index - (store.history.capacity - snapshots.count)
        guard snapshots.indices.contains(i) else { return [] }
        let memory = snapshots[i].memory
        return [
            .init(label: "Used", color: MonitorSection.memory.tint, value: Format.bytes(memory.used)),
            .init(label: "Pressure", color: pressureColor(memory.pressure), value: pressureLabel(memory.pressure)),
        ]
    }

    /// Stacked so the bands sum to total memory in use (App at the bottom).
    private var breakdownChart: some View {
        let snapshots = store.history.elements
        return HistoryChart(
            series: [
                .init(label: "App", color: .green, values: snapshots.map { Double($0.memory.app) }),
                .init(label: "Wired", color: .indigo, values: snapshots.map { Double($0.memory.wired) }),
                .init(label: "Compressed", color: .orange, values: snapshots.map { Double($0.memory.compressed) }),
                .init(label: "Cached", color: .gray, values: snapshots.map { Double($0.memory.cached) }),
            ],
            capacity: store.history.capacity,
            yDomain: 0...Double(store.system.memoryTotal),
            yLabel: { Format.bytes(UInt64($0)) },
            stacked: true
        )
        .frame(height: 240)
    }

    private func items(for memory: MemorySnapshot) -> [StatGrid.Item] {
        [
            .init(label: "Memory used", value: Format.bytes(memory.used)),
            .init(label: "App memory", value: Format.bytes(memory.app)),
            .init(label: "Wired", value: Format.bytes(memory.wired)),
            .init(label: "Compressed", value: Format.bytes(memory.compressed)),
            .init(label: "Cached files", value: Format.bytes(memory.cached)),
            .init(label: "Swap used", value: "\(Format.bytes(memory.swapUsed)) of \(Format.bytes(memory.swapTotal)) allocated"),
        ]
    }

    private func pressureColor(_ pressure: MemoryPressure) -> Color {
        switch pressure {
        case .normal: .green
        case .warning: .yellow
        case .critical: .red
        }
    }

    private func pressureLabel(_ pressure: MemoryPressure) -> String {
        switch pressure {
        case .normal: "Normal"
        case .warning: "Warning"
        case .critical: "Critical"
        }
    }
}
