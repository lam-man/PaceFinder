//
//  RunningActivityTableCell.swift
//  SmoothWalker
//
//  Created by Wen Lin on 11/8/25.
//  Copyright © 2025 Apple. All rights reserved.
//

import UIKit

@available(iOS 16.0, *)
class RunningActivityTableViewCell: UITableViewCell {
    
    static let identifier = "RunningActivityTableViewCell"
    
    // UI Elements
    private let dateLabel = UILabel()
    private let durationLabel = UILabel()
    private let distanceLabel = UILabel()
    private let paceLabel = UILabel()
    private let heartRateLabel = UILabel()
    private let speedLabel = UILabel()
    private let powerLabel = UILabel()
    
    private let stackView = UIStackView()
    private let topRowStack = UIStackView()
    private let middleRowStack = UIStackView()
    private let bottomRowStack = UIStackView()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupViews()
        setupConstraints()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupViews() {
        // Configure labels
        dateLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        dateLabel.textColor = .label
        
        durationLabel.font = .systemFont(ofSize: 14, weight: .medium)
        durationLabel.textColor = .secondaryLabel
        
        distanceLabel.font = .systemFont(ofSize: 14, weight: .regular)
        distanceLabel.textColor = .label
        
        paceLabel.font = .systemFont(ofSize: 14, weight: .regular)
        paceLabel.textColor = .label
        
        heartRateLabel.font = .systemFont(ofSize: 14, weight: .regular)
        heartRateLabel.textColor = .systemRed
        
        speedLabel.font = .systemFont(ofSize: 14, weight: .regular)
        speedLabel.textColor = .systemBlue
        
        powerLabel.font = .systemFont(ofSize: 14, weight: .regular)
        powerLabel.textColor = .systemOrange
        
        // Configure stack views
        topRowStack.axis = .horizontal
        topRowStack.distribution = .equalSpacing
        topRowStack.alignment = .center
        
        middleRowStack.axis = .horizontal
        middleRowStack.distribution = .equalSpacing
        middleRowStack.alignment = .center
        
        bottomRowStack.axis = .horizontal
        bottomRowStack.distribution = .equalSpacing
        bottomRowStack.alignment = .center
        
        stackView.axis = .vertical
        stackView.spacing = 8
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        // Add labels to rows
        topRowStack.addArrangedSubview(dateLabel)
        topRowStack.addArrangedSubview(durationLabel)
        
        middleRowStack.addArrangedSubview(distanceLabel)
        middleRowStack.addArrangedSubview(paceLabel)
        
        bottomRowStack.addArrangedSubview(heartRateLabel)
        bottomRowStack.addArrangedSubview(speedLabel)
        bottomRowStack.addArrangedSubview(powerLabel)
        
        stackView.addArrangedSubview(topRowStack)
        stackView.addArrangedSubview(middleRowStack)
        stackView.addArrangedSubview(bottomRowStack)
        
        contentView.addSubview(stackView)
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            stackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12)
        ])
    }
    
    func configure(with activity: RunningActivity) {
        // Date
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short
        dateLabel.text = dateFormatter.string(from: activity.startDate)
        
        // Duration
        let durationFormatter = DateComponentsFormatter()
        durationFormatter.allowedUnits = [.hour, .minute, .second]
        durationFormatter.unitsStyle = .abbreviated
        durationLabel.text = durationFormatter.string(from: activity.duration) ?? "Unknown"
        
        // Distance
        if let distance = activity.distance {
            let distanceKm = distance / 1000.0
            distanceLabel.text = String(format: "%.2f km", distanceKm)
        } else {
            distanceLabel.text = "Distance: N/A"
        }
        
        // Pace
        if let pace = activity.averagePaceMinutesPerKm {
            let minutes = Int(pace)
            let seconds = Int((pace - Double(minutes)) * 60)
            paceLabel.text = String(format: "%d:%02d /km", minutes, seconds)
        } else {
            paceLabel.text = "Pace: N/A"
        }
        
        // Heart Rate
        if let heartRate = activity.averageHeartRate {
            heartRateLabel.text = String(format: "♥ %.0f bpm", heartRate)
        } else {
            heartRateLabel.text = "♥ N/A"
        }
        
        // Speed
        if let speed = activity.averageSpeed {
            let speedKmh = speed * 3.6 // Convert m/s to km/h
            speedLabel.text = String(format: "⚡ %.1f km/h", speedKmh)
        } else {
            speedLabel.text = "⚡ N/A"
        }
        
        // Power
        if let power = activity.averagePower {
            powerLabel.text = String(format: "⚡ %.0f W", power)
        } else {
            powerLabel.text = "⚡ N/A"
        }
    }
}
