//
//  RunningActivityDetailViewController.swift
//  PaceFinder
//
//  Created by Codex on 5/16/26.
//  Copyright © 2026 Apple. All rights reserved.
//

import UIKit

@available(iOS 16.0, *)
class RunningActivityDetailViewController: UITableViewController {
    
    private struct DetailSection {
        let title: String
        let rows: [DetailRow]
    }
    
    private struct DetailRow {
        let title: String
        let value: String
    }
    
    private let activity: RunningActivity
    private lazy var sections = makeSections()
    
    // MARK: - Initializers
    
    init(activity: RunningActivity) {
        self.activity = activity
        super.init(style: .insetGrouped)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - View Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = "Run Details"
        navigationItem.largeTitleDisplayMode = .never
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: Self.cellIdentifier)
    }
    
    // MARK: - Table View Data Source
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return sections.count
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return sections[section].rows.count
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return sections[section].title
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .value1, reuseIdentifier: Self.cellIdentifier)
        let row = sections[indexPath.section].rows[indexPath.row]
        
        cell.textLabel?.text = row.title
        cell.detailTextLabel?.text = row.value
        cell.detailTextLabel?.numberOfLines = 0
        cell.selectionStyle = .none
        
        return cell
    }
    
    // MARK: - Formatting
    
    private static let cellIdentifier = "RunningActivityDetailCell"
    
    private func makeSections() -> [DetailSection] {
        return [
            DetailSection(title: "Summary", rows: [
                DetailRow(title: "Start", value: formattedDate(activity.startDate)),
                DetailRow(title: "End", value: formattedDate(activity.endDate)),
                DetailRow(title: "Duration", value: formattedDuration(activity.duration)),
                DetailRow(title: "Distance", value: formattedDistance(activity.distance))
            ]),
            DetailSection(title: "Performance", rows: [
                DetailRow(title: "Average Pace", value: formattedPace(activity.averagePaceMinutesPerKm)),
                DetailRow(title: "Average Speed", value: formattedSpeed(activity.averageSpeed)),
                DetailRow(title: "Average Heart Rate", value: formattedHeartRate(activity.averageHeartRate)),
                DetailRow(title: "Maximum Heart Rate", value: formattedHeartRate(activity.maxHeartRate)),
                DetailRow(title: "Average Power", value: formattedPower(activity.averagePower))
            ]),
            DetailSection(title: "Running Dynamics", rows: [
                DetailRow(title: "Cadence", value: formattedCadence(activity.estimatedCadence)),
                DetailRow(title: "Cadence Note", value: activity.cadenceNote ?? "Not enough step-count data to calculate cadence."),
                DetailRow(title: "Stride Length", value: formattedMeters(activity.strideLength)),
                DetailRow(title: "Ground Contact Time", value: formattedMilliseconds(activity.groundContactTime)),
                DetailRow(title: "Vertical Oscillation", value: formattedMeters(activity.verticalOscillation))
            ])
        ]
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func formattedDuration(_ duration: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: duration) ?? "Not available"
    }
    
    private func formattedDistance(_ meters: Double?) -> String {
        guard let meters = meters else { return "Not available" }
        return String(format: "%.2f km", meters / 1000.0)
    }
    
    private func formattedPace(_ minutesPerKm: Double?) -> String {
        guard let minutesPerKm = minutesPerKm else { return "Not available" }
        
        let minutes = Int(minutesPerKm)
        let seconds = Int((minutesPerKm - Double(minutes)) * 60)
        return String(format: "%d:%02d /km", minutes, seconds)
    }
    
    private func formattedSpeed(_ metersPerSecond: Double?) -> String {
        guard let metersPerSecond = metersPerSecond else { return "Not available" }
        return String(format: "%.1f km/h", metersPerSecond * 3.6)
    }
    
    private func formattedHeartRate(_ beatsPerMinute: Double?) -> String {
        guard let beatsPerMinute = beatsPerMinute else { return "Not available" }
        return String(format: "%.0f bpm", beatsPerMinute)
    }
    
    private func formattedPower(_ watts: Double?) -> String {
        guard let watts = watts else { return "Not available" }
        return String(format: "%.0f W", watts)
    }
    
    private func formattedCadence(_ stepsPerMinute: Double?) -> String {
        guard let stepsPerMinute = stepsPerMinute else { return "Not enough data" }
        return String(format: "%.0f spm", stepsPerMinute)
    }
    
    private func formattedMeters(_ meters: Double?) -> String {
        guard let meters = meters else { return "Not available" }
        return String(format: "%.2f m", meters)
    }
    
    private func formattedMilliseconds(_ milliseconds: Double?) -> String {
        guard let milliseconds = milliseconds else { return "Not available" }
        return String(format: "%.0f ms", milliseconds)
    }
}
