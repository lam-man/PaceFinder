import UIKit
import SwiftUI

@available(iOS 16.0, *)
final class AnalyticsViewController: UIViewController {

    private let runningDataManager = RunningDataManager()
    private let mileageAggregator = MileageAggregator()
    private let preferredUnitProvider = PreferredUnitProvider()
    private let calendar = MileageAggregator.isoCalendar

    private var activities: [MileageActivity] = []
    private var yearRange: ClosedRange<Int>
    private var selectedYear: Int
    private var preferredUnit: DistanceDisplayUnit = .kilometers
    private var loadedYearData = Set<Int>()
    private var hasLoadedPreferredUnit = false
    private var hasLoadedActivities = false
    private var didRenderInitialContent = false

    private let segmentedControl = UISegmentedControl(items: [
        NSLocalizedString("ANALYTICS_SEGMENT_WEEK", value: "Week", comment: "Analytics segment title"),
        NSLocalizedString("ANALYTICS_SEGMENT_MONTH", value: "Month", comment: "Analytics segment title"),
        NSLocalizedString("ANALYTICS_SEGMENT_HALF_YEAR", value: "Half Year", comment: "Analytics segment title"),
        NSLocalizedString("ANALYTICS_SEGMENT_YEAR", value: "Year", comment: "Analytics segment title")
    ])
    private let totalDistanceLabel = UILabel()
    private let unitStatusLabel = UILabel()
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
    }

    private func setupViews() {
        totalDistanceLabel.translatesAutoresizingMaskIntoConstraints = false
        totalDistanceLabel.font = .preferredFont(forTextStyle: .title3)
        totalDistanceLabel.textAlignment = .center

        unitStatusLabel.translatesAutoresizingMaskIntoConstraints = false
        unitStatusLabel.font = .preferredFont(forTextStyle: .footnote)
        unitStatusLabel.textColor = .secondaryLabel
        unitStatusLabel.textAlignment = .center
        unitStatusLabel.numberOfLines = 0

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
        noDataLabel.text = NSLocalizedString("ANALYTICS_NO_MILEAGE_DATA", value: "No mileage data yet", comment: "Analytics empty state message")
        noDataLabel.textColor = .secondaryLabel
        noDataLabel.textAlignment = .center
        noDataLabel.isUserInteractionEnabled = false

        chartHostingController.view.translatesAutoresizingMaskIntoConstraints = false
        addChild(chartHostingController)
        chartHostingController.didMove(toParent: self)

        view.addSubview(totalDistanceLabel)
        view.addSubview(unitStatusLabel)
        view.addSubview(segmentedControl)
        view.addSubview(yearSelector)
        view.addSubview(chartHostingController.view)
        view.addSubview(noDataLabel)

        NSLayoutConstraint.activate([
            totalDistanceLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            totalDistanceLabel.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            totalDistanceLabel.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),

            unitStatusLabel.topAnchor.constraint(equalTo: totalDistanceLabel.bottomAnchor, constant: 4),
            unitStatusLabel.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            unitStatusLabel.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),

            segmentedControl.topAnchor.constraint(equalTo: unitStatusLabel.bottomAnchor, constant: 12),
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
        preferredUnitProvider.fetchPreferredDistanceUnit { [weak self] selection in
            DispatchQueue.main.async {
                self?.preferredUnit = selection.unit
                self?.unitStatusLabel.text = self?.statusText(for: selection.source)
                self?.hasLoadedPreferredUnit = true
                self?.refreshInitialContentIfReady()
            }
        }
    }

    private func requestAuthorizationAndLoadActivities() {
        HealthData.requestRunningDataAccess { [weak self] success in
            guard let self else { return }

            guard success else {
                DispatchQueue.main.async {
                    self.hasLoadedActivities = true
                    self.refreshInitialContentIfReady()
                }
                return
            }

            self.loadActivityBoundariesAndRecentWindow()
        }
    }

    @objc private func granularityChanged() {
        loadMissingDataIfNeeded(for: currentGranularity()) { [weak self] in
            self?.refreshContent()
        }
    }

    @objc private func previousYearTapped() {
        selectedYear = max(yearRange.lowerBound, selectedYear - 1)
        loadMissingDataIfNeeded(for: .year(selectedYear)) { [weak self] in
            self?.refreshContent()
        }
    }

    @objc private func nextYearTapped() {
        selectedYear = min(yearRange.upperBound, selectedYear + 1)
        loadMissingDataIfNeeded(for: .year(selectedYear)) { [weak self] in
            self?.refreshContent()
        }
    }

    private func refreshContent() {
        let granularity = currentGranularity()
        let bucket = mileageAggregator.aggregate(activities: activities, granularity: granularity)

        totalDistanceLabel.text = "Total: \(formatDistance(bucket.totalDistanceMeters)) \(preferredUnit.symbol)"
        chartHostingController.rootView = MileageChart(bucket: bucket, unit: preferredUnit)

        noDataLabel.isHidden = bucket.hasData

        yearSelector.isHidden = segmentedControl.selectedSegmentIndex != 3
        yearLabel.text = String(selectedYear)
        previousYearButton.isEnabled = selectedYear > yearRange.lowerBound
        nextYearButton.isEnabled = selectedYear < yearRange.upperBound
    }

    private func loadActivityBoundariesAndRecentWindow() {
        runningDataManager.fetchEarliestRunningWorkoutDate { [weak self] earliestDate in
            guard let self else { return }

            let currentYear = self.calendar.component(.year, from: Date())
            let earliestYear = earliestDate.map { self.calendar.component(.year, from: $0) } ?? currentYear

            DispatchQueue.main.async {
                self.yearRange = earliestYear...currentYear
                self.selectedYear = min(max(self.selectedYear, self.yearRange.lowerBound), self.yearRange.upperBound)
            }

            let twoYearsAgo = self.calendar.date(byAdding: .year, value: -2, to: Date()) ?? Date()
            let startDate = earliestDate.map { max($0, twoYearsAgo) } ?? twoYearsAgo

            self.runningDataManager.fetchRunningActivities(from: startDate, to: Date()) { [weak self] recentActivities in
                guard let self else { return }

                DispatchQueue.main.async {
                    self.mergeActivities(recentActivities)
                    self.hasLoadedActivities = true
                    self.refreshInitialContentIfReady()
                }
            }
        }
    }

    private func loadMissingDataIfNeeded(for granularity: MileageGranularity, completion: @escaping () -> Void) {
        guard case .year(let year) = granularity else {
            completion()
            return
        }

        guard !loadedYearData.contains(year) else {
            completion()
            return
        }

        var components = DateComponents()
        components.year = year
        components.month = 1
        components.day = 1

        guard let startDate = calendar.date(from: components),
              let endDate = calendar.date(byAdding: .year, value: 1, to: startDate) else {
            completion()
            return
        }

        runningDataManager.fetchRunningActivities(from: startDate, to: endDate) { [weak self] activities in
            DispatchQueue.main.async {
                self?.mergeActivities(activities)
                self?.loadedYearData.insert(year)
                completion()
            }
        }
    }

    private func mergeActivities(_ fetchedActivities: [RunningActivity]) {
        guard !fetchedActivities.isEmpty else { return }

        var merged = Dictionary(uniqueKeysWithValues: activities.map { ($0.startDate.timeIntervalSince1970, $0) })
        for activity in fetchedActivities {
            guard let distance = activity.distance else { continue }
            let mileageActivity = MileageActivity(startDate: activity.startDate, distanceMeters: distance)
            merged[mileageActivity.startDate.timeIntervalSince1970] = mileageActivity
        }

        activities = merged.values.sorted { $0.startDate > $1.startDate }
    }

    private func refreshInitialContentIfReady() {
        guard hasLoadedPreferredUnit, hasLoadedActivities else { return }
        guard !didRenderInitialContent else { return }

        didRenderInitialContent = true
        refreshContent()
    }

    private func statusText(for source: PreferredUnitSource) -> String? {
        switch source {
        case .preferred:
            return nil
        case .fallbackAuthorizationDenied:
            return NSLocalizedString(
                "ANALYTICS_UNIT_STATUS_AUTH_DENIED",
                value: "Using kilometers. Enable Health access to use your preferred distance unit.",
                comment: "Message shown when Health permission is denied for preferred units"
            )
        case .fallbackNoHealthData, .fallbackUnavailable, .fallbackError:
            return NSLocalizedString(
                "ANALYTICS_UNIT_STATUS_FALLBACK",
                value: "Using kilometers because preferred distance unit is unavailable.",
                comment: "Message shown when preferred units cannot be loaded"
            )
        }
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
