import Foundation

struct ZoneDuration {
    let zone: HRZone
    let seconds: TimeInterval
}

struct IntensityReport {
    let zoneDurations: [ZoneDuration]
    let easyPercent: Double
    let hardPercent: Double
}
