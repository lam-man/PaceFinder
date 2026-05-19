import Foundation

struct WeeklyMileage {
    let weekStart: Date
    let totalMeters: Double
    let longestRunMeters: Double
    let runCount: Int
}

struct MileageReport {
    let weeks: [WeeklyMileage]
    let acwr: Double
    let streakDays: Int
    let rollingAvgMeters4Weeks: Double
}
