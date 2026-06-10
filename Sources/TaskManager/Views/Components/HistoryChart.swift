import Charts
import SwiftUI

/// Big area+line history chart, Windows Task Manager style: fixed-width window,
/// newest sample anchored to the right edge, no animation on updates.
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

    var body: some View {
        Chart {
            ForEach(series) { s in
                let offset = capacity - s.values.count
                ForEach(Array(s.values.enumerated()), id: \.offset) { index, value in
                    AreaMark(
                        x: .value("Time", index + offset),
                        y: .value(s.label, value),
                        stacking: .unstacked
                    )
                    .foregroundStyle(.linearGradient(
                        colors: [s.color.opacity(0.35), s.color.opacity(0.03)],
                        startPoint: .top,
                        endPoint: .bottom
                    ))
                    .interpolationMethod(.monotone)

                    LineMark(
                        x: .value("Time", index + offset),
                        y: .value(s.label, value),
                        series: .value("Series", s.label)
                    )
                    .foregroundStyle(s.color)
                    .lineStyle(StrokeStyle(lineWidth: 1.5))
                    .interpolationMethod(.monotone)
                }
            }
        }
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
    }

    private var resolvedYDomain: ClosedRange<Double> {
        if let yDomain { return yDomain }
        let windowMax = series.flatMap(\.values).max() ?? 0
        return 0...Format.niceMax(windowMax)
    }
}
