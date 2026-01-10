//
//  RunningActivityDetailViewController.swift
//  SmoothWalker
//
//  Created on 1/10/26.
//  Copyright © 2026 Apple. All rights reserved.
//

import UIKit

@available(iOS 16.0, *)
class RunningActivityDetailViewController: UITableViewController {
    
    private let activity: RunningActivity
    
    // Section definitions
    private enum Section: Int, CaseIterable {
        case summary = 0
        case splits = 1
        
        var title: String? {
            switch self {
            case .summary: return "Summary"
            case .splits: return "Splits"
            }
        }
    }
    
    // MARK: - Initialization
    
    init(activity: RunningActivity) {
        self.activity = activity
        super.init(style: .insetGrouped)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - View Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupViewController()
        setupTableView()
    }
    
    private func setupViewController() {
        title = "Run Details"
        navigationController?.navigationBar.prefersLargeTitles = false
        
        // Set navigation title to date
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short
        title = dateFormatter.string(from: activity.startDate)
    }
    
    private func setupTableView() {
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "SummaryCell")
        tableView.register(SplitTableViewCell.self, forCellReuseIdentifier: SplitTableViewCell.identifier)
    }
    
    // MARK: - Table View Data Source
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return Section.allCases.count
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let sectionType = Section(rawValue: section) else { return 0 }
        
        switch sectionType {
        case .summary:
            return 6 // Distance, Duration, Pace, Heart Rate, Power, Cadence
        case .splits:
            return activity.splits.count
        }
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        guard let sectionType = Section(rawValue: section) else { return nil }
        
        if sectionType == .splits && activity.splits.isEmpty {
            return nil
        }
        
        return sectionType.title
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let sectionType = Section(rawValue: indexPath.section) else {
            return UITableViewCell()
        }
        
        switch sectionType {
        case .summary:
            return configureSummaryCell(for: indexPath)
        case .splits:
            return configureSplitCell(for: indexPath)
        }
    }
    
    // MARK: - Cell Configuration
    
    private func configureSummaryCell(for indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "SummaryCell", for: indexPath)
        
        var content = cell.defaultContentConfiguration()
        
        switch indexPath.row {
        case 0: // Distance
            content.text = "Distance"
            if let distance = activity.distance {
                content.secondaryText = String(format: "%.2f km", distance / 1000.0)
            } else {
                content.secondaryText = "N/A"
            }
            
        case 1: // Duration
            content.text = "Duration"
            let formatter = DateComponentsFormatter()
            formatter.allowedUnits = [.hour, .minute, .second]
            formatter.unitsStyle = .abbreviated
            content.secondaryText = formatter.string(from: activity.duration) ?? "N/A"
            
        case 2: // Pace
            content.text = "Average Pace"
            if let pace = activity.averagePaceMinutesPerKm {
                let minutes = Int(pace)
                let seconds = Int((pace - Double(minutes)) * 60)
                content.secondaryText = String(format: "%d:%02d /km", minutes, seconds)
            } else {
                content.secondaryText = "N/A"
            }
            
        case 3: // Heart Rate
            content.text = "Average Heart Rate"
            if let hr = activity.averageHeartRate {
                content.secondaryText = String(format: "%.0f bpm", hr)
            } else {
                content.secondaryText = "N/A"
            }
            
        case 4: // Power
            content.text = "Average Power"
            if let power = activity.averagePower {
                content.secondaryText = String(format: "%.0f W", power)
            } else {
                content.secondaryText = "N/A"
            }
            
        case 5: // Cadence
            content.text = "Average Cadence"
            if let cadence = activity.cadence {
                content.secondaryText = String(format: "%.0f spm", cadence)
            } else {
                content.secondaryText = "N/A"
            }
            
        default:
            break
        }
        
        cell.contentConfiguration = content
        cell.selectionStyle = .none
        
        return cell
    }
    
    private func configureSplitCell(for indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: SplitTableViewCell.identifier, for: indexPath) as? SplitTableViewCell else {
            return UITableViewCell()
        }
        
        let split = activity.splits[indexPath.row]
        cell.configure(with: split)
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard let sectionType = Section(rawValue: section),
              sectionType == .splits,
              !activity.splits.isEmpty else {
            return nil
        }
        
        // Create custom header with column labels
        let headerView = SplitHeaderView()
        return headerView
    }
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        guard let sectionType = Section(rawValue: section),
              sectionType == .splits,
              !activity.splits.isEmpty else {
            return UITableView.automaticDimension
        }
        
        return 50
    }
}

// MARK: - Split Header View

@available(iOS 16.0, *)
class SplitHeaderView: UIView {
    
    private let titleLabel = UILabel()
    private let kmLabel = UILabel()
    private let timeLabel = UILabel()
    private let paceLabel = UILabel()
    private let hrLabel = UILabel()
    private let powerLabel = UILabel()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupViews() {
        backgroundColor = .systemGroupedBackground
        
        titleLabel.text = "Splits"
        titleLabel.font = .systemFont(ofSize: 20, weight: .bold)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let labels = [kmLabel, timeLabel, paceLabel, hrLabel, powerLabel]
        let titles = ["KM", "TIME", "PACE", "♥", "W"]
        
        for (label, title) in zip(labels, titles) {
            label.text = title
            label.font = .systemFont(ofSize: 11, weight: .semibold)
            label.textColor = .secondaryLabel
            label.textAlignment = .center
        }
        
        let stackView = UIStackView(arrangedSubviews: labels)
        stackView.axis = .horizontal
        stackView.distribution = .fillEqually
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(titleLabel)
        addSubview(stackView)
        
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4)
        ])
    }
}
