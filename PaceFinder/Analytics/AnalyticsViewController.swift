import UIKit
import HealthKit

@available(iOS 16.0, *)
class AnalyticsViewController: UIViewController {

    private let analyticsService = AnalyticsService()
    private let loadCalc = TrainingLoadCalculator()

    private let scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()

    private let contentStack: UIStackView = {
        let s = UIStackView()
        s.translatesAutoresizingMaskIntoConstraints = false
        s.axis = .vertical
        s.spacing = 16
        return s
    }()

    private let periodControl: UISegmentedControl = {
        let sc = UISegmentedControl(items: ["Week", "Month", "Year", "All"])
        sc.selectedSegmentIndex = 0
        sc.translatesAutoresizingMaskIntoConstraints = false
        return sc
    }()

    private var mileageChartVC: WeeklyMileageChart?
    private var zoneChartVC: HRZoneStackedBar?
    private var paceHRChartVC: PaceHREfficiencyChart?

    private var mileageReport: MileageReport?
    private var intensityReport: IntensityReport?
    private var prReport: PRReport?
    private var cachedActivities: [RunningActivity] = []

    /// Prevents overlapping loads when the user taps the segment control rapidly.
    private var isLoadingData = false

    /// First error encountered during the last load cycle (nil = success / no error yet).
    private var loadError: AnalyticsError?

    /// Preferred distance unit queried from HealthKit (defaults to km).
    private var distanceUnit: HKUnit = HKUnit.meterUnit(with: .kilo)

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Analytics"
        view.backgroundColor = .systemGroupedBackground

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "gear"),
            style: .plain,
            target: self,
            action: #selector(openSettings)
        )

        setupScrollView()
        loadPreferredDistanceUnit()
        loadData()
    }

    // MARK: - Preferred unit

    private func loadPreferredDistanceUnit() {
        guard let distanceType = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning) else { return }
        HealthData.healthStore.preferredUnits(for: [distanceType]) { [weak self] result, _ in
            if let unit = result[distanceType] {
                DispatchQueue.main.async { self?.distanceUnit = unit }
            }
        }
    }

    private func formatDistance(_ meters: Double) -> String {
        let qty = HKQuantity(unit: .meter(), doubleValue: meters)
        guard qty.is(compatibleWith: distanceUnit) else {
            return String(format: "%.2f km", meters / 1_000.0)
        }
        let value = qty.doubleValue(for: distanceUnit)
        return String(format: "%.2f %@", value, distanceUnit.unitString)
    }

    private func formatPace(_ minutesPerKm: Double?) -> String {
        guard let minutesPerKm else { return "No data" }
        // Convert to min/mi if user prefers imperial
        let paceValue: Double
        let unitLabel: String
        if distanceUnit == HKUnit.mile() {
            paceValue = minutesPerKm * 1.60934
            unitLabel = "/mi"
        } else {
            paceValue = minutesPerKm
            unitLabel = "/km"
        }
        let minutes = Int(paceValue)
        let seconds = Int((paceValue - Double(minutes)) * 60)
        return String(format: "%d:%02d %@", minutes, seconds, unitLabel)
    }

    // MARK: - Setup

    private func setupScrollView() {
        view.addSubview(scrollView)
        scrollView.addSubview(contentStack)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentStack.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 16),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 16),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -16),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -16),
            contentStack.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -32)
        ])

        contentStack.addArrangedSubview(periodControl)
        periodControl.addTarget(self, action: #selector(periodChanged), for: .valueChanged)
    }

    private func rebuildContent() {
        contentStack.arrangedSubviews.filter { $0 !== periodControl }.forEach {
            contentStack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }

        [mileageChartVC, zoneChartVC, paceHRChartVC].compactMap { $0 }.forEach {
            $0.willMove(toParent: nil)
            $0.view.removeFromSuperview()
            $0.removeFromParent()
        }

        // Show an actionable banner if the last load produced an error.
        if let error = loadError {
            addErrorBanner(for: error)
            return
        }

        addSectionHeader("Training Load")
        addMileageChart()
        addACWRCard()
        addTenPercentCard()
        addLongRunRatioCard()
        addStreakCard()
        addSectionHeader("Heart Rate")
        addHRSection()
        addSectionHeader("Personal Records")
        addPRSection()
    }

    private func addSectionHeader(_ text: String) {
        let label = UILabel()
        label.text = text
        label.font = .preferredFont(forTextStyle: .headline)
        label.textColor = .label
        contentStack.addArrangedSubview(label)
    }

    /// Shows a full-width card explaining the load error and how to resolve it.
    private func addErrorBanner(for error: AnalyticsError) {
        let (title, message, action): (String, String, String?)
        switch error {
        case .authorizationDenied:
            title   = "Health Access Required"
            message = "Analytics needs permission to read your workouts."
            action  = "Open Settings"
        case .healthKitUnavailable:
            title   = "HealthKit Not Available"
            message = "This device does not support HealthKit."
            action  = nil
        case .fetchFailed:
            title   = "Could Not Load Data"
            message = "An error occurred while fetching your workouts. Pull to refresh."
            action  = nil
        }

        let card = SummaryCard(title: title, value: message, subtitle: action, valueColor: .systemOrange)
        contentStack.addArrangedSubview(card)

        // For authorization errors, provide a deep-link button to Settings.app.
        if error == .authorizationDenied {
            let button = UIButton(type: .system)
            button.setTitle("Open Health Settings", for: .normal)
            button.translatesAutoresizingMaskIntoConstraints = false
            button.addTarget(self, action: #selector(openHealthSettings), for: .touchUpInside)
            contentStack.addArrangedSubview(button)
        }
    }

    private func addMileageChart() {
        let vc = WeeklyMileageChart()
        vc.weeklyData = mileageReport?.weeks ?? []
        addChild(vc)
        vc.view.translatesAutoresizingMaskIntoConstraints = false
        contentStack.addArrangedSubview(vc.view)
        vc.view.heightAnchor.constraint(equalToConstant: 200).isActive = true
        vc.didMove(toParent: self)
        mileageChartVC = vc
    }

    private func addACWRCard() {
        guard let report = mileageReport else { return }
        let acwr = report.acwr
        let color: UIColor = acwr >= 0.8 && acwr <= 1.3 ? .systemGreen :
                             (acwr > 1.5 ? .systemRed : .systemYellow)
        let card = SummaryCard(
            title: "ACWR (Acute:Chronic Workload)",
            value: String(format: "%.2f", acwr),
            subtitle: acwr >= 0.8 && acwr <= 1.3 ? "Optimal training load" :
                      acwr > 1.5 ? "High injury risk" : "Suboptimal load",
            valueColor: color
        )
        contentStack.addArrangedSubview(card)
    }

    private func addTenPercentCard() {
        guard let report = mileageReport, report.weeks.count >= 2 else { return }
        // Compare current (possibly partial) week against the last fully completed week.
        let currentWeek = report.weeks[report.weeks.count - 1]
        let prevWeek    = report.weeks[report.weeks.count - 2]
        let violated = loadCalc.violatesTenPercentRule(
            thisWeekMeters: currentWeek.totalMeters,
            lastWeekMeters: prevWeek.totalMeters
        )
        guard violated else { return }
        let card = SummaryCard(
            title: "10% Rule Warning",
            value: "Exceeded",
            subtitle: "This week's mileage is more than 10% above last week.",
            valueColor: .systemOrange
        )
        contentStack.addArrangedSubview(card)
    }

    private func addLongRunRatioCard() {
        // Use the last *completed* week (second-to-last in the array) so a partial
        // current week doesn't distort the ratio. Fall back to current week if only
        // one week is available.
        guard let report = mileageReport else { return }
        let completedWeeks = report.weeks.count >= 2
            ? Array(report.weeks.dropLast())
            : report.weeks
        guard let refWeek = completedWeeks.last, refWeek.totalMeters > 0 else { return }

        let ratio = loadCalc.longestRunRatio(
            longestRunMeters: refWeek.longestRunMeters,
            weekTotalMeters: refWeek.totalMeters
        )
        let healthy = ratio >= 0.25 && ratio <= 0.35
        let weekLabel = report.weeks.count >= 2 ? "Last completed week" : "Current week"
        let card = SummaryCard(
            title: "Long Run Ratio (\(weekLabel))",
            value: String(format: "%.0f%%", ratio * 100),
            subtitle: healthy ? "Healthy range (25-35%)" : "Outside healthy range (25-35%)",
            valueColor: healthy ? .systemGreen : .systemOrange
        )
        contentStack.addArrangedSubview(card)
    }

    private func addStreakCard() {
        guard let report = mileageReport else { return }
        let card = SummaryCard(
            title: "Current Streak",
            value: "\(report.streakDays) day\(report.streakDays == 1 ? "" : "s")",
            subtitle: "Consecutive days with at least one run"
        )
        contentStack.addArrangedSubview(card)
    }

    private func addHRSection() {
        guard let report = intensityReport else {
            let noDataCard = SummaryCard(
                title: "Heart Rate Zones",
                value: "No data",
                subtitle: "No heart rate data available"
            )
            contentStack.addArrangedSubview(noDataCard)
            return
        }

        let totalHRSeconds = report.zoneDurations.map(\.seconds).reduce(0, +)
        if totalHRSeconds == 0 {
            let noDataCard = SummaryCard(
                title: "Heart Rate Zones",
                value: "No data",
                subtitle: "No heart rate data available"
            )
            contentStack.addArrangedSubview(noDataCard)
            return
        }

        let zoneVC = HRZoneStackedBar()
        zoneVC.zoneDurations = report.zoneDurations
        addChild(zoneVC)
        zoneVC.view.translatesAutoresizingMaskIntoConstraints = false
        contentStack.addArrangedSubview(zoneVC.view)
        zoneVC.view.heightAnchor.constraint(equalToConstant: 200).isActive = true
        zoneVC.didMove(toParent: self)
        zoneChartVC = zoneVC

        let easyPct = report.easyPercent * 100
        let is8020 = easyPct >= 80
        let card8020 = SummaryCard(
            title: "80/20 Indicator (4-week)",
            value: String(format: "%.0f%% easy", easyPct),
            subtitle: is8020 ? "Meets 80/20 guideline" : "Too much hard effort",
            valueColor: is8020 ? .systemGreen : .systemOrange
        )
        contentStack.addArrangedSubview(card8020)

        // HR Drift requires per-second samples which are not yet stored.
        // Card is intentionally omitted until per-sample HR is plumbed through.

        let paceVC = PaceHREfficiencyChart()
        paceVC.activities = cachedActivities
        addChild(paceVC)
        paceVC.view.translatesAutoresizingMaskIntoConstraints = false
        contentStack.addArrangedSubview(paceVC.view)
        paceVC.view.heightAnchor.constraint(equalToConstant: 200).isActive = true
        paceVC.didMove(toParent: self)
        paceHRChartVC = paceVC
    }

    private func addPRSection() {
        guard let report = prReport else { return }

        for pr in report.records {
            let paceStr = formatPace(pr.pace)
            let dateStr = pr.date.map {
                DateFormatter.localizedString(from: $0, dateStyle: .medium, timeStyle: .none)
            } ?? ""
            let card = SummaryCard(
                title: pr.distance.rawValue,
                value: paceStr,
                subtitle: dateStr.isEmpty ? nil : dateStr
            )
            contentStack.addArrangedSubview(card)
        }

        if let longest = report.longestRun {
            let distStr = formatDistance(longest.distance ?? 0)
            let dateStr = DateFormatter.localizedString(from: longest.startDate, dateStyle: .medium, timeStyle: .none)
            let card = SummaryCard(title: "Longest Run", value: distStr, subtitle: dateStr)
            contentStack.addArrangedSubview(card)
        }

        if let longestDur = report.longestDuration {
            let formatter = DateComponentsFormatter()
            formatter.allowedUnits = [.hour, .minute, .second]
            formatter.unitsStyle = .abbreviated
            let durStr = formatter.string(from: longestDur.duration) ?? "N/A"
            let dateStr = DateFormatter.localizedString(from: longestDur.startDate, dateStyle: .medium, timeStyle: .none)
            let card = SummaryCard(title: "Longest Duration", value: durStr, subtitle: dateStr)
            contentStack.addArrangedSubview(card)
        }
    }

    // MARK: - Data Loading

    private func loadData() {
        guard !isLoadingData else { return }
        isLoadingData = true
        loadError = nil        // reset before fresh load

        let group = DispatchGroup()

        group.enter()
        analyticsService.fetchMileageReport { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let report): self?.mileageReport = report
                case .failure(let err):   self?.loadError = self?.loadError ?? err
                }
                group.leave()
            }
        }

        group.enter()
        analyticsService.fetchIntensityReport { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let report): self?.intensityReport = report
                case .failure(let err):   self?.loadError = self?.loadError ?? err
                }
                group.leave()
            }
        }

        group.enter()
        analyticsService.fetchPRReport { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let report): self?.prReport = report
                case .failure(let err):   self?.loadError = self?.loadError ?? err
                }
                group.leave()
            }
        }

        group.enter()
        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -90, to: endDate) ?? endDate
        RunningDataManager().fetchRunningActivities(from: startDate, to: endDate) { [weak self] activities in
            DispatchQueue.main.async {
                self?.cachedActivities = activities
                group.leave()
            }
        }

        group.notify(queue: .main) { [weak self] in
            self?.isLoadingData = false
            self?.rebuildContent()
        }
    }

    // MARK: - Actions

    @objc private func periodChanged() {
        guard !isLoadingData else { return }
        loadData()
    }

    @objc private func openSettings() {
        let settingsVC = SettingsViewController()
        navigationController?.pushViewController(settingsVC, animated: true)
    }

    @objc private func openHealthSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}
