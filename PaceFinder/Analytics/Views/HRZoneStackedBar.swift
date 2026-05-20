import UIKit
import SwiftUI
import Charts

@available(iOS 16.0, *)
final class HRZoneStackedBar: UIViewController {

    var zoneDurations: [ZoneDuration] = [] {
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

        let host = UIHostingControllerBridge(rootView: HRZoneSwiftUIView(zoneDurations: zoneDurations))
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
struct HRZoneSwiftUIView: View {

    let zoneDurations: [ZoneDuration]

    private var total: Double {
        zoneDurations.map(\.seconds).reduce(0, +)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(HRZone.allCases, id: \.rawValue) { zone in
                let duration = zoneDurations.first(where: { $0.zone == zone })?.seconds ?? 0
                let pct = total > 0 ? duration / total : 0
                HStack {
                    Text(zone.displayName)
                        .font(.caption)
                        .frame(width: 50, alignment: .leading)
                    GeometryReader { geo in
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(zone.color))
                            .frame(width: geo.size.width * pct)
                    }
                    .frame(height: 20)
                    Text(String(format: "%.0f%%", pct * 100))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .frame(width: 35, alignment: .trailing)
                }
            }
        }
        .padding()
    }
}
