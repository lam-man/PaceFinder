import UIKit
import SwiftUI

@available(iOS 16.0, *)
final class AnalyticsViewController: UIViewController {

    private let runningDataManager = RunningDataManager()
    private let mileageAggregator = MileageAggregator()
    private let preferredUnitProvider = PreferredUnitProvider()

    private var activities: [MileageActivity] = []
    private var yearRange: ClosedRange<Int>
    private var selectedYear: Int
    private var preferredUnit: DistanceDisplayUnit = .kilometers

    private let segmentedControl = UISegmentedControl(items: ["Week", "Month", "Half Year", "Year"])
    private let totalDistanceLabel = UILabel()
    private let noDataLabel = UILabel()

    private let yearSelector = UIStackView()
    private let previousYearButton = UIButton(type: .system)
    private let nextYearButton = UIButton(type: .system)
    private let yearLabel = UILabel()

    private let chartHostingController: UIHostingController<MileageChart>

    init() {
        let currentYear = Calendar.current.component(.year, from: Date())
        self.selectedYear = currentYear
        self.yearRange = currentYear...currentYear
        self.chartHostingController = UIHostingController(rootView: MileageChart(bucket: .empty, unit: .kilometers))
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "Analytics"
        view.backgroundColor = .systemBackground

        setupViews()
        loadPreferredDistanceUnit()
        requestAuthorizationAndLoadActivities()
        refreshContent()
    }

    private func setupViews() {
        totalDistanceLabel.translatesAutoresizingMaskIntoConstraints = false
        totalDistanceLabel.font = .preferredFont(forTextStyle: .title3)
        totalDistanceLabel.textAlignment = .center

        segmentedControl.translatesAutoresizingMaskIntoConstraints = false
        segmentedControl.selectedSegmentIndex = 0
        segmentedControl.addTarget(self, action: #selector(granularityChanged), for: .valueChanged)

        previousYearButton.translatesAutoresizingMaskIntoConstraints = false
        previousYearButton.setImage(UIImage(systemName: "chevron.left"), for: .normal)
        previousYearButton.addTarget(self, action: #selector(previousYearTapped), for: .touchUpInside)

        yearLabel.translatesAutoresizingMaskIntoConstraints = false
        yearLabel.font = .preferredFont(forTextStyle: .headline)

        nextYearButton.translatesAutoresizingMaskIntoConstraints = false
        nextYearButton.setImage(UIImage(systemName: "chevron.right"), for: .normal)
        nextYearButton.addTarget(self, action: #selector(nextYearTapped), for: .touchUpInside)

        yearSelector.translatesAutoresizingMaskIntoConstraints = false
        yearSelector.axis = .horizontal
        yearSelector.spacing = 12
        yearSelector.alignment = .center
        yearSelector.distribution = .equalCentering
        yearSelector.addArrangedSubview(previousYearButton)
        yearSelector.addArrangedSubview(yearLabel)
        yearSelector.addArrangedSubview(nextYearButton)

        noDataLabel.translatesAutoresizingMaskIntoConstraints = false
        noDataLabel.text = "暂无里程数据"
        noDataLabel.textColor = .secondaryLabel
        noDataLabel.textAlignment = .center
        noDataLabel.isHidden = true

        chartHostingController.view.translatesAutoresizingMaskIntoConstraints = false
        addChild(chartHostingController)
        chartHostingController.didMove(toParent: self)

        view.addSubview(totalDistanceLabel)
        view.addSubview(segmentedControl)
        view.addSubview(yearSelector)
        view.addSubview(chartHostingController.view)
        view.addSubview(noDataLabel)

        NSLayoutConstraint.activate([
            totalDistanceLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            totalDistanceLabel.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            totalDistanceLabel.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),

            segmentedControl.topAnchor.constraint(equalTo: totalDistanceLabel.bottomAnchor, constant: 16),
            segmentedControl.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            segmentedControl.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),

            yearSelector.topAnchor.constraint(equalTo: segmentedControl.bottomAnchor, constant: 12),
            yearSelector.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            chartHostingController.view.topAnchor.constraint(equalTo: yearSelector.bottomAnchor, constant: 16),
            chartHostingController.view.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            chartHostingController.view.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
            chartHostingController.view.heightAnchor.constraint(equalToConstant: 240),

            noDataLabel.centerXAnchor.constraint(equalTo: chartHostingController.view.centerXAnchor),
            noDataLabel.centerYAnchor.constraint(equalTo: chartHostingController.view.centerYAnchor)
        ])
    }

    private func loadPreferredDistanceUnit() {
        preferredUnitProvider.fetchPreferredDistanceUnit { [weak self] unit in
            DispatchQueue.main.async {
                self?.preferredUnit = unit
                self?.refreshContent()
            }
        }
    }

    private func requestAuthorizationAndLoadActivities() {
        HealthData.requestRunningDataAccess { [weak self] success in
            guard let self, success else { return }

            self.runningDataManager.fetchRunningActivities(from: .distantPast, to: Date()) { activities in
                DispatchQueue.main.async {
                    self.activities = activities.compactMap { activity in
                        guard let distance = activity.distance else { return nil }
                        return MileageActivity(startDate: activity.startDate, distanceMeters: distance)
                    }

                    let range = self.mileageAggregator.selectableYearRange(in: self.activities)
                    self.yearRange = range
                    self.selectedYear = min(max(self.selectedYear, range.lowerBound), range.upperBound)
                    self.refreshContent()
                }
            }
        }
    }

    @objc private func granularityChanged() {
        refreshContent()
    }

    @objc private func previousYearTapped() {
        selectedYear = max(yearRange.lowerBound, selectedYear - 1)
        refreshContent()
    }

    @objc private func nextYearTapped() {
        selectedYear = min(yearRange.upperBound, selectedYear + 1)
        refreshContent()
    }

    private func refreshContent() {
        let granularity = currentGranularity()
        let bucket = mileageAggregator.aggregate(activities: activities, granularity: granularity)

        totalDistanceLabel.text = "Total: \(formatDistance(bucket.totalDistanceMeters)) \(preferredUnit.symbol)"
        chartHostingController.rootView = MileageChart(bucket: bucket, unit: preferredUnit)

        noDataLabel.isHidden = bucket.hasData
        chartHostingController.view.isHidden = !bucket.hasData

        yearSelector.isHidden = segmentedControl.selectedSegmentIndex != 3
        yearLabel.text = String(selectedYear)
        previousYearButton.isEnabled = selectedYear > yearRange.lowerBound
        nextYearButton.isEnabled = selectedYear < yearRange.upperBound
    }

    private func currentGranularity() -> MileageGranularity {
        switch segmentedControl.selectedSegmentIndex {
        case 1:
            return .month
        case 2:
            return .halfYear
        case 3:
            return .year(selectedYear)
        default:
            return .week
        }
    }

    private func formatDistance(_ meters: Double) -> String {
        let value = preferredUnit.convert(meters: meters)
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 1
        formatter.minimumFractionDigits = value == 0 ? 0 : 1
        return formatter.string(from: NSNumber(value: value)) ?? "0"
    }
}
