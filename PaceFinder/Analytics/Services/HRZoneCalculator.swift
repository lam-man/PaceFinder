import Foundation

struct HRZoneCalculator {

    func zoneFor(heartRate bpm: Double, maxHR: Double) -> HRZone? {
        guard maxHR > 0 else { return nil }
        let pct = bpm / maxHR
        return HRZone.allCases.first { pct >= $0.lowerPercent && pct < $0.upperPercent }
            ?? (pct >= 0.90 ? .z5 : nil)
    }

    func zoneDurations(from samples: [(hr: Double, duration: TimeInterval)], maxHR: Double) -> [ZoneDuration] {
        var accumulator: [HRZone: TimeInterval] = [:]
        for sample in samples {
            guard let zone = zoneFor(heartRate: sample.hr, maxHR: maxHR) else { continue }
            accumulator[zone, default: 0] += sample.duration
        }
        return HRZone.allCases.map { zone in
            ZoneDuration(zone: zone, seconds: accumulator[zone] ?? 0)
        }
    }

    func easyPercent(from durations: [ZoneDuration]) -> Double {
        let total = durations.map(\.seconds).reduce(0, +)
        guard total > 0 else { return 0 }
        let easy = durations.filter { $0.zone == .z1 || $0.zone == .z2 }.map(\.seconds).reduce(0, +)
        return easy / total
    }
}
