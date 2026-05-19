import Foundation

struct TrainingLoadCalculator {

    func acwr(recentWeekMeters: Double, rollingAvgDailyMeters28: Double) -> Double {
        guard rollingAvgDailyMeters28 > 0 else { return 0 }
        let acuteLoad = recentWeekMeters / 7.0
        return acuteLoad / rollingAvgDailyMeters28
    }

    func violatesTenPercentRule(thisWeekMeters: Double, avgMeters4Weeks: Double) -> Bool {
        guard avgMeters4Weeks > 0 else { return false }
        return thisWeekMeters > avgMeters4Weeks * 1.10
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
