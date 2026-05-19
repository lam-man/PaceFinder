import UIKit
import SwiftUI
import Charts

@available(iOS 16.0, *)
final class WeeklyMileageChart: UIViewController {

    var weeklyData: [WeeklyMileage] = [] {
        didSet { updateChart() }
    }

    private var hostingController: UIViewController?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .secondarySystemGroupedBackground
        view.layer.cornerRadius = 12
        view.clipsToBounds = true
        updateChart()
    }

    private func updateChart() {
        guard isViewLoaded else { return }
        hostingController?.willMove(toParent: nil)
        hostingController?.view.removeFromSuperview()
        hostingController?.removeFromParent()

        let chart = WeeklyMileageSwiftUIView(weeklyData: weeklyData)
        let host = UIHostingControllerBridge(rootView: chart)
        addChild(host)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        host.view.backgroundColor = .clear
        view.addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        host.didMove(toParent: self)
        hostingController = host
    }
}

@available(iOS 16.0, *)
struct WeeklyMileageSwiftUIView: View {

    let weeklyData: [WeeklyMileage]

    private var rolling4Avg: Double {
        let last4 = weeklyData.suffix(4)
        guard !last4.isEmpty else { return 0 }
        return last4.map { $0.totalMeters / 1000.0 }.reduce(0, +) / Double(last4.count)
    }

    var body: some View {
        Chart {
            ForEach(weeklyData.indices, id: \.self) { index in
                let week = weeklyData[index]
                BarMark(
                    x: .value("Week", week.weekStart, unit: .weekOfYear),
                    y: .value("Distance (km)", week.totalMeters / 1000.0)
                )
                .foregroundStyle(Color.blue.opacity(0.7))
            }
            RuleMark(y: .value("4-Week Avg", rolling4Avg))
                .foregroundStyle(.orange)
                .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 3]))
                .annotation(position: .top, alignment: .trailing) {
                    Text("4wk avg")
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .weekOfYear)) { _ in
                AxisGridLine()
                AxisTick()
                AxisValueLabel(format: .dateTime.month(.twoDigits).day(.twoDigits))
            }
        }
        .padding()
    }
}
