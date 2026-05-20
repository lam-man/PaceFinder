//
//  RunningActivity.swift
//  PaceFinder
//
//  Created by Wen Lin on 11/8/25.
//  Copyright © 2025 Apple. All rights reserved.
//

import Foundation
import HealthKit

/// A representation of a complete running activity with all associated metrics
struct RunningActivity {
    let workoutIdentifier: UUID
    let startDate: Date
    let endDate: Date
    let duration: TimeInterval
    
    // Core metrics
    var distance: Double? = nil // meters
    var averageSpeed: Double? = nil // m/s
    var averageHeartRate: Double? = nil // bpm
    var maxHeartRate: Double? = nil // bpm
    
    // Advanced metrics (if available)
    var averagePower: Double? = nil // watts
    var groundContactTime: Double? = nil // milliseconds
    var strideLength: Double? = nil // meters
    var verticalOscillation: Double? = nil // meters
    var estimatedCadence: Double? = nil // steps per minute, calculated from workout step samples
    var cadenceNote: String? = nil
    
    // Calculated properties
    var averagePaceMinutesPerKm: Double? {
        guard let speed = averageSpeed, speed > 0 else { return nil }
        return (1000.0 / speed) / 60.0 // Convert m/s to min/km
    }
}

/// A representation of running metrics collected during a workout
struct RunningMetrics {
    let type: HKQuantityTypeIdentifier
    let value: Double
    let unit: HKUnit
    let startDate: Date
    let endDate: Date
}
