//
//  SplitTableViewCell.swift
//  SmoothWalker
//
//  Created on 1/10/26.
//  Copyright © 2026 Apple. All rights reserved.
//

import UIKit

@available(iOS 16.0, *)
class SplitTableViewCell: UITableViewCell {
    
    static let identifier = "SplitTableViewCell"
    
    // UI Elements
    private let kmLabel = UILabel()
    private let timeLabel = UILabel()
    private let paceLabel = UILabel()
    private let heartRateLabel = UILabel()
    private let powerLabel = UILabel()
    
    private let stackView = UIStackView()
    
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
        let labels = [kmLabel, timeLabel, paceLabel, heartRateLabel, powerLabel]
        
        for label in labels {
            label.font = .monospacedDigitSystemFont(ofSize: 14, weight: .regular)
            label.textAlignment = .center
            label.textColor = .label
        }
        
        // KM label is bold
        kmLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        
        // Heart rate in red
        heartRateLabel.textColor = .systemRed
        
        // Power in orange
        powerLabel.textColor = .systemOrange
        
        // Configure stack view
        stackView.axis = .horizontal
        stackView.distribution = .fillEqually
        stackView.alignment = .center
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        stackView.addArrangedSubview(kmLabel)
        stackView.addArrangedSubview(timeLabel)
        stackView.addArrangedSubview(paceLabel)
        stackView.addArrangedSubview(heartRateLabel)
        stackView.addArrangedSubview(powerLabel)
        
        contentView.addSubview(stackView)
        
        selectionStyle = .none
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            stackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12)
        ])
    }
    
    func configure(with split: RunningSplit) {
        // Kilometer number
        kmLabel.text = "\(split.splitNumber)"
        
        // Time for this split
        timeLabel.text = split.formattedDuration
        
        // Pace
        paceLabel.text = split.formattedPace
        
        // Heart Rate
        if let hr = split.averageHeartRate {
            heartRateLabel.text = String(format: "%.0f", hr)
        } else {
            heartRateLabel.text = "-"
        }
        
        // Power
        if let power = split.averagePower {
            powerLabel.text = String(format: "%.0f", power)
        } else {
            powerLabel.text = "-"
        }
        
        // Highlight faster/slower splits with background color
        highlightPace(split.paceMinutesPerKm)
    }
    
    private func highlightPace(_ pace: Double) {
        // Visual indication could be added here based on relative pace
        // For now, keep default background
        backgroundColor = .systemBackground
    }
}
