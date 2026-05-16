//
//  RunningActivity.swift
//  SmoothWalker
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
    var distance: Double? // meters
    var averageSpeed: Double? // m/s
    var averageHeartRate: Double? // bpm
    var maxHeartRate: Double? // bpm
    
    // Advanced metrics (if available)
    var averagePower: Double? // watts
    var groundContactTime: Double? // milliseconds
    var strideLength: Double? // meters
    var verticalOscillation: Double? // meters
    var estimatedCadence: Double? // steps per minute, calculated from workout step samples
    var cadenceNote: String?
    
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
