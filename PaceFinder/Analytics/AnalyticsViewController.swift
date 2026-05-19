import UIKit

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
        loadData()
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
        guard let report = mileageReport,
              let lastWeek = report.weeks.last else { return }
        let violated = loadCalc.violatesTenPercentRule(
            thisWeekMeters: lastWeek.totalMeters,
            avgMeters4Weeks: report.rollingAvgMeters4Weeks
        )
        guard violated else { return }
        let card = SummaryCard(
            title: "⚠️ 10% Rule Warning",
            value: "Exceeded",
            subtitle: "This week's mileage is more than 10% above your 4-week average.",
            valueColor: .systemOrange
        )
        contentStack.addArrangedSubview(card)
    }

    private func addLongRunRatioCard() {
        guard let report = mileageReport, let lastWeek = report.weeks.last, lastWeek.totalMeters > 0 else { return }
        let ratio = loadCalc.longestRunRatio(longestRunMeters: lastWeek.longestRunMeters, weekTotalMeters: lastWeek.totalMeters)
        let healthy = ratio >= 0.25 && ratio <= 0.35
        let card = SummaryCard(
            title: "Long Run Ratio",
            value: String(format: "%.0f%%", ratio * 100),
            subtitle: healthy ? "Healthy range (25–35%)" : "Outside healthy range (25–35%)",
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
            let noDataCard = SummaryCard(title: "Heart Rate Zones", value: "No data", subtitle: "No heart rate data available")
            contentStack.addArrangedSubview(noDataCard)
            return
        }

        let totalHRSeconds = report.zoneDurations.map(\.seconds).reduce(0, +)
        if totalHRSeconds == 0 {
            let noDataCard = SummaryCard(title: "Heart Rate Zones", value: "No data", subtitle: "No heart rate data available")
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
            subtitle: is8020 ? "✅ Meets 80/20 guideline" : "⚠️ Too much hard effort",
            valueColor: is8020 ? .systemGreen : .systemOrange
        )
        contentStack.addArrangedSubview(card8020)

        let driftCard = HRDriftCard(driftPercent: nil)
        contentStack.addArrangedSubview(driftCard)

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
            let paceStr: String
            if let pace = pr.pace {
                let mins = Int(pace)
                let secs = Int((pace - Double(mins)) * 60)
                paceStr = String(format: "%d:%02d /km", mins, secs)
            } else {
                paceStr = "No data"
            }
            let dateStr = pr.date.map { DateFormatter.localizedString(from: $0, dateStyle: .medium, timeStyle: .none) } ?? ""
            let card = SummaryCard(title: pr.distance.rawValue, value: paceStr, subtitle: dateStr.isEmpty ? nil : dateStr)
            contentStack.addArrangedSubview(card)
        }

        if let longest = report.longestRun {
            let distStr = String(format: "%.2f km", (longest.distance ?? 0) / 1000.0)
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
        let group = DispatchGroup()

        group.enter()
        analyticsService.fetchMileageReport { [weak self] report in
            DispatchQueue.main.async {
                self?.mileageReport = report
                group.leave()
            }
        }

        group.enter()
        analyticsService.fetchIntensityReport { [weak self] report in
            DispatchQueue.main.async {
                self?.intensityReport = report
                group.leave()
            }
        }

        group.enter()
        analyticsService.fetchPRReport { [weak self] report in
            DispatchQueue.main.async {
                self?.prReport = report
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
            self?.rebuildContent()
        }
    }

    // MARK: - Actions

    @objc private func periodChanged() {
        loadData()
    }

    @objc private func openSettings() {
        let settingsVC = SettingsViewController()
        navigationController?.pushViewController(settingsVC, animated: true)
    }
}
