//
//  RunningSplit.swift
//  SmoothWalker
//
//  Created on 1/10/26.
//  Copyright © 2026 Apple. All rights reserved.
//

import Foundation

/// Represents a single split (typically per kilometer) within a running workout
struct RunningSplit {
    let splitNumber: Int           // 1, 2, 3, etc.
    let distance: Double           // meters (typically 1000m per split)
    let startDate: Date
    let endDate: Date
    var activeDuration: TimeInterval? = nil // Actual duration excluding pauses
    
    // Calculated from start/end dates
    var duration: TimeInterval {
        return activeDuration ?? endDate.timeIntervalSince(startDate)
    }
    
    // Pace in minutes per kilometer
    var paceMinutesPerKm: Double {
        guard distance > 0 else { return 0 }
        let timePerKm = (duration / distance) * 1000.0
        return timePerKm / 60.0
    }
    
    // Metrics for this split
    var averageHeartRate: Double?    // bpm
    var averagePower: Double?        // watts
    var averageCadence: Double?      // steps per minute
    var averageSpeed: Double?        // m/s
    var elevation: Double?           // meters gained/lost
    
    // Formatted pace string (e.g., "5:30")
    var formattedPace: String {
        let totalSeconds = paceMinutesPerKm * 60
        let minutes = Int(totalSeconds) / 60
        let seconds = Int(totalSeconds) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    // Formatted duration string (e.g., "5:30")
    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
