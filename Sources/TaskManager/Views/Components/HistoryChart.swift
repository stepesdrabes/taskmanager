import Charts
import SwiftUI

/// Big history chart, Windows Task Manager style: fixed-width window, newest
/// sample anchored to the right edge, no animation on updates. Single series is
/// filled; multiple series are lines, or stacked areas when `stacked` is set.
struct HistoryChart: View {
    struct Series: Identifiable {
        let label: String
        let color: Color
        let values: [Double]   // oldest first
        var id: String { label }
    }

    let series: [Series]
    let capacity: Int
    var yDomain: ClosedRange<Double>?            // nil → 0...niceMax(window max)
    var yLabel: (Double) -> String = { $0.formatted() }
    var stacked: Bool = false

    @State private var hoverIndex: Int?

    /// A translucent fill only reads well with one series; overlapping fills
    /// turn muddy, so multiple non-stacked series render as lines.
    private var showFill: Bool { series.count == 1 && !stacked }

    var body: some View {
        Chart {
            ForEach(series) { s in
                let offset = capacity - s.values.count
                ForEach(Array(s.values.enumerated()), id: \.offset) { index, value in
                    let x = index + offset
                    if stacked {
                        AreaMark(
                            x: .value("Time", x),
                            y: .value("Value", value),
                            stacking: .standard
                        )
                        .foregroundStyle(by: .value("Series", s.label))
                        .interpolationMethod(.monotone)
                    } else {
                        if showFill {
                            AreaMark(
                                x: .value("Time", x),
                                y: .value("Value", value),
                                series: .value("Series", s.label),
                                stacking: .unstacked
                            )
                            .foregroundStyle(.linearGradient(
                                colors: [s.color.opacity(0.35), s.color.opacity(0.03)],
                                startPoint: .top,
                                endPoint: .bottom
                            ))
                            .interpolationMethod(.monotone)
                        }
                        LineMark(
                            x: .value("Time", x),
                            y: .value("Value", value),
                            series: .value("Series", s.label)
                        )
                        .foregroundStyle(s.color)
                        .lineStyle(StrokeStyle(lineWidth: 1.5))
                        .interpolationMethod(.monotone)
                    }
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
                        ChartTooltip(rows: tooltipRows(at: hoverIndex))
                    }
            }
        }
        .chartForegroundStyleScale(domain: series.map(\.label), range: series.map(\.color))
        .chartLegend(.hidden)
        .chartXScale(domain: 0...(capacity - 1))
        .chartYScale(domain: resolvedYDomain)
        .chartXAxis(.hidden)
        .chartYAxis {
            AxisMarks { value in
                AxisGridLine()
                AxisValueLabel {
                    if let number = value.as(Double.self) {
                        Text(yLabel(number))
                    }
                }
            }
        }
        .chartXHover(capacity: capacity, selection: $hoverIndex)
    }

    private var resolvedYDomain: ClosedRange<Double> {
        if let yDomain { return yDomain }
        let windowMax = series.flatMap(\.values).max() ?? 0
        return 0...Format.niceMax(windowMax)
    }

    private func tooltipRows(at index: Int) -> [ChartTooltip.Row] {
        func value(_ s: Series) -> Double? {
            let i = index - (capacity - s.values.count)
            return s.values.indices.contains(i) ? s.values[i] : nil
        }
        var rows = series.compactMap { s -> ChartTooltip.Row? in
            value(s).map { .init(label: s.label, color: s.color, value: yLabel($0)) }
        }
        if stacked, rows.count > 1 {
            let total = series.compactMap(value).reduce(0, +)
            rows.append(.init(label: "Total", color: .primary, value: yLabel(total)))
        }
        return rows
    }
}
