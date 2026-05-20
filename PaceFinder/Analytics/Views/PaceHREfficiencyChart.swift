import UIKit
import SwiftUI
import Charts

@available(iOS 16.0, *)
final class PaceHREfficiencyChart: UIViewController {

    var activities: [RunningActivity] = [] {
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

        let host = UIHostingControllerBridge(rootView: PaceHRSwiftUIView(activities: activities))
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

private struct PaceHRPoint: Identifiable {
    let id = UUID()
    let date: Date
    let pace: Double
    let hr: Double
}

@available(iOS 16.0, *)
struct PaceHRSwiftUIView: View {

    let activities: [RunningActivity]

    private var points: [PaceHRPoint] {
        activities.compactMap { a in
            guard let pace = a.averagePaceMinutesPerKm, let hr = a.averageHeartRate else { return nil }
            return PaceHRPoint(date: a.startDate, pace: pace, hr: hr)
        }
        .sorted { $0.date < $1.date }
    }

    var body: some View {
        if points.isEmpty {
            Text("No pace/HR data available")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding()
        } else {
            Chart(points) { point in
                LineMark(
                    x: .value("Date", point.date),
                    y: .value("HR (bpm)", point.hr)
                )
                .foregroundStyle(.red)
                PointMark(
                    x: .value("Date", point.date),
                    y: .value("HR (bpm)", point.hr)
                )
                .foregroundStyle(.red)
                .symbolSize(30)
            }
            .chartXAxis {
                AxisMarks(values: .automatic) { _ in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                }
            }
            .chartYAxisLabel("Avg HR (bpm)")
            .padding()
        }
    }
}
