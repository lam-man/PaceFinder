import Charts
import SwiftUI

@available(iOS 16.0, *)
struct MileageChart: View {
    let bucket: MileageBucket
    let unit: DistanceDisplayUnit
    private let calendar = MileageAggregator.isoCalendar
    private let dateFormatter = DateFormatter()

    var body: some View {
        Chart(bucket.bars) { bar in
            BarMark(
                x: .value("Date", bar.startDate),
                y: .value("Distance", unit.convert(meters: bar.distanceMeters))
            )
            .foregroundStyle(style(for: bar))
            .accessibilityLabel(accessibilityLabel(for: bar))
            .accessibilityValue(accessibilityValue(for: bar))
        }
        .chartYAxis {
            AxisMarks(position: .leading)
        }
        .chartXAxis {
            AxisMarks(values: xAxisValues()) { value in
                AxisGridLine()
                AxisTick()
                AxisValueLabel(format: axisDateFormatStyle())
            }
        }
        .chartPlotStyle { plotArea in
            plotArea.background(Color(.secondarySystemBackground).opacity(0.25))
        }
    }

    private func style(for bar: MileageBar) -> AnyShapeStyle {
        let today = calendar.startOfDay(for: Date())
        let barDay = calendar.startOfDay(for: bar.startDate)

        if barDay > today {
            return AnyShapeStyle(Color.gray.opacity(0.35))
        }

        if barDay == today {
            return AnyShapeStyle(Color.accentColor)
        }

        return AnyShapeStyle(Color.blue.gradient)
    }

    private func accessibilityLabel(for bar: MileageBar) -> String {
        dateFormatter.calendar = calendar
        dateFormatter.locale = .current
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .none
        return dateFormatter.string(from: bar.startDate)
    }

    private func accessibilityValue(for bar: MileageBar) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 1
        let value = unit.convert(meters: bar.distanceMeters)
        let distance = formatter.string(from: NSNumber(value: value)) ?? "0"
        return "\(distance) \(unit.symbol)"
    }

    private func xAxisValues() -> AxisMarkValues {
        switch bucket.granularity {
        case .week:
            return .stride(by: .day)
        case .month:
            let count = bucket.bars.count > 30 ? 5 : (bucket.bars.count > 28 ? 4 : 3)
            return .stride(by: .day, count: count)
        case .halfYear:
            return .stride(by: .weekOfYear, count: 4)
        case .year:
            return .stride(by: .month)
        }
    }

    private func axisDateFormatStyle() -> Date.FormatStyle {
        switch bucket.granularity {
        case .week:
            return .dateTime.weekday(.abbreviated)
        case .month:
            return .dateTime.day(.defaultDigits)
        case .halfYear:
            return .dateTime.month(.abbreviated).day(.defaultDigits)
        case .year:
            return .dateTime.month(.abbreviated)
        }
    }
}
