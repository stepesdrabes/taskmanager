import Charts
import SwiftUI

struct MemoryView: View {
    @Environment(MetricsStore.self) private var store
    @Environment(Localizer.self) private var loc
    @State private var display: MemoryDisplay = .used
    @State private var hoverIndex: Int?

    private enum MemoryDisplay: Hashable {
        case used, breakdown
    }

    var body: some View {
        SectionScrollView(title: loc("section.memory"), subtitle: Format.bytes(store.system.memoryTotal)) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline) {
                    Text(display == .used ? loc("memory.usedColored") : loc("memory.breakdownTitle"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Picker(loc("memory.display"), selection: $display) {
                        Text(loc("memory.used")).tag(MemoryDisplay.used)
                        Text(loc("memory.breakdown")).tag(MemoryDisplay.breakdown)
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
                        .init(label: loc("memory.app"), value: memory.app, color: .green),
                        .init(label: loc("memory.wired"), value: memory.wired, color: .indigo),
                        .init(label: loc("memory.compressed"), value: memory.compressed, color: .orange),
                        .init(label: loc("memory.cached"), value: memory.cached, color: .gray),
                    ],
                    total: store.system.memoryTotal
                )

                StatGrid(items: items(for: memory))

                HStack(spacing: 6) {
                    Circle()
                        .fill(pressureColor(memory.pressure))
                        .frame(width: 8, height: 8)
                    Text(loc("memory.pressureInline", ["state": pressureLabel(memory.pressure)]))
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
            .init(label: loc("memory.used"), color: MonitorSection.memory.tint, value: Format.bytes(memory.used)),
            .init(label: loc("memory.pressureTooltip"), color: pressureColor(memory.pressure), value: pressureLabel(memory.pressure)),
        ]
    }

    /// Stacked so the bands sum to total memory in use (App at the bottom).
    private var breakdownChart: some View {
        let snapshots = store.history.elements
        return HistoryChart(
            series: [
                .init(label: loc("memory.app"), color: .green, values: snapshots.map { Double($0.memory.app) }),
                .init(label: loc("memory.wired"), color: .indigo, values: snapshots.map { Double($0.memory.wired) }),
                .init(label: loc("memory.compressed"), color: .orange, values: snapshots.map { Double($0.memory.compressed) }),
                .init(label: loc("memory.cached"), color: .gray, values: snapshots.map { Double($0.memory.cached) }),
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
            .init(label: loc("memory.memoryUsed"), value: Format.bytes(memory.used)),
            .init(label: loc("memory.appMemory"), value: Format.bytes(memory.app)),
            .init(label: loc("memory.wired"), value: Format.bytes(memory.wired)),
            .init(label: loc("memory.compressed"), value: Format.bytes(memory.compressed)),
            .init(label: loc("memory.cachedFiles"), value: Format.bytes(memory.cached)),
            .init(label: loc("memory.swapUsed"), value: loc("memory.swap", ["used": Format.bytes(memory.swapUsed), "total": Format.bytes(memory.swapTotal)])),
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
        case .normal: loc("memory.pressureNormal")
        case .warning: loc("memory.pressureWarning")
        case .critical: loc("memory.pressureCritical")
        }
    }
}
