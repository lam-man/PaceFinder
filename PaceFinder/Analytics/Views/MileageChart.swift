import Charts
import SwiftUI

@available(iOS 16.0, *)
struct MileageChart: View {
    let bucket: MileageBucket
    let unit: DistanceDisplayUnit

    var body: some View {
        Chart(bucket.bars) { bar in
            BarMark(
                x: .value("X", bar.label),
                y: .value("Distance", unit.convert(meters: bar.distanceMeters))
            )
            .foregroundStyle(.blue.gradient)
        }
        .chartYAxis {
            AxisMarks(position: .leading)
        }
    }
}
