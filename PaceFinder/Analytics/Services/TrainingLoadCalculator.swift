import Foundation

struct TrainingLoadCalculator {

    /// Standard ACWR (Gabbett 2016).
    /// Acute load = 7-day total / 7 (daily avg this week).
    /// Chronic load = 28-day total / 28 (daily avg over 4 weeks).
    /// Ratio ≈ 1.0 at steady-state; sweet spot 0.8–1.3.
    func acwr(acute7dMeters: Double, chronic28dMeters: Double) -> Double {
        guard chronic28dMeters > 0 else { return 0 }
        // (acute/7) / (chronic/28) = acute * 4 / chronic
        return (acute7dMeters * 4.0) / chronic28dMeters
    }

    /// Week-over-week 10% rule: flags a jump of more than 10% relative to the
    /// previous completed week (not a rolling average).
    func violatesTenPercentRule(thisWeekMeters: Double, lastWeekMeters: Double) -> Bool {
        guard lastWeekMeters > 0 else { return false }
        return (thisWeekMeters - lastWeekMeters) / lastWeekMeters > 0.10
    }

    func longestRunRatio(longestRunMeters: Double, weekTotalMeters: Double) -> Double {
        guard weekTotalMeters > 0 else { return 0 }
        return longestRunMeters / weekTotalMeters
    }

    func streak(from activities: [RunningActivity]) -> Int {
        guard !activities.isEmpty else { return 0 }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let activeDays = Set(activities.map { calendar.startOfDay(for: $0.startDate) })
        var streak = 0
        var current = today
        while activeDays.contains(current) {
            streak += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: current) else { break }
            current = prev
        }
        return streak
    }

    func rollingAverage(weeks: [WeeklyMileage], weekCount: Int) -> Double {
        let relevant = Array(weeks.suffix(weekCount))
        guard !relevant.isEmpty else { return 0 }
        let total = relevant.map(\.totalMeters).reduce(0, +)
        return total / Double(relevant.count)
    }
}
