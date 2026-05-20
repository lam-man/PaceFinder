import Foundation
import HealthKit

// MARK: - Error type

enum AnalyticsError: Error {
    case healthKitUnavailable
    case authorizationDenied
    case fetchFailed
}

@available(iOS 16.0, *)
class AnalyticsService {

    private let dataManager = RunningDataManager()
    private let zoneCalc = HRZoneCalculator()
    private let loadCalc = TrainingLoadCalculator()

    private var userMaxHR: Double {
        let stored = UserDefaults.standard.double(forKey: "userHRmax")
        if stored > 0 { return stored }
        let age = UserDefaults.standard.double(forKey: "userAge")
        let effectiveAge = age > 0 ? age : 30
        return 220 - effectiveAge
    }

    // MARK: - Fetch methods

    func fetchMileageReport(completion: @escaping (Result<MileageReport, AnalyticsError>) -> Void) {
        guard HKHealthStore.isHealthDataAvailable() else {
            completion(.failure(.healthKitUnavailable))
            return
        }
        HealthData.requestRunningDataAccess { [weak self] success in
            guard let self = self else { return }
            guard success else {
                completion(.failure(.authorizationDenied))
                return
            }
            let endDate = Date()
            let calendar = Calendar.current
            guard let startDate = calendar.date(byAdding: .weekOfYear, value: -12, to: endDate) else {
                completion(.success(MileageReport(weeks: [], acwr: 0, streakDays: 0, rollingAvgMeters4Weeks: 0)))
                return
            }

            self.dataManager.fetchRunningActivities(from: startDate, to: endDate) { [weak self] activities in
                guard let self = self else { return }
                let weeks = self.buildWeeklyMileage(from: activities, startDate: startDate, endDate: endDate)
                let streak = self.loadCalc.streak(from: activities)
                let rolling4 = self.loadCalc.rollingAverage(weeks: weeks, weekCount: 4)

                // Standard ACWR: acute = last 7 days total; chronic = last 28 days total
                let acute7d = weeks.last?.totalMeters ?? 0
                let chronic28d = weeks.suffix(4).map(\.totalMeters).reduce(0, +)
                let acwr = self.loadCalc.acwr(acute7dMeters: acute7d, chronic28dMeters: chronic28d)

                completion(.success(MileageReport(
                    weeks: weeks,
                    acwr: acwr,
                    streakDays: streak,
                    rollingAvgMeters4Weeks: rolling4
                )))
            }
        }
    }

    func fetchIntensityReport(completion: @escaping (Result<IntensityReport, AnalyticsError>) -> Void) {
        guard HKHealthStore.isHealthDataAvailable() else {
            completion(.failure(.healthKitUnavailable))
            return
        }
        HealthData.requestRunningDataAccess { [weak self] success in
            guard let self = self else { return }
            guard success else {
                completion(.failure(.authorizationDenied))
                return
            }
            let endDate = Date()
            guard let startDate = Calendar.current.date(byAdding: .day, value: -28, to: endDate) else {
                completion(.success(IntensityReport(zoneDurations: [], easyPercent: 0, hardPercent: 0)))
                return
            }

            self.dataManager.fetchRunningActivities(from: startDate, to: endDate) { [weak self] activities in
                guard let self = self else { return }
                let maxHR = self.userMaxHR
                let samples: [(hr: Double, duration: TimeInterval)] = activities.compactMap { activity in
                    guard let hr = activity.averageHeartRate else { return nil }
                    return (hr: hr, duration: activity.duration)
                }
                let zoneDurations = self.zoneCalc.zoneDurations(from: samples, maxHR: maxHR)
                let easyPct = self.zoneCalc.easyPercent(from: zoneDurations)
                let total = zoneDurations.map(\.seconds).reduce(0, +)
                let hard = total > 0 ? (1.0 - easyPct) : 0
                completion(.success(IntensityReport(zoneDurations: zoneDurations, easyPercent: easyPct, hardPercent: hard)))
            }
        }
    }

    func fetchPRReport(completion: @escaping (Result<PRReport, AnalyticsError>) -> Void) {
        guard HKHealthStore.isHealthDataAvailable() else {
            completion(.failure(.healthKitUnavailable))
            return
        }
        HealthData.requestRunningDataAccess { [weak self] success in
            guard let self = self else { return }
            guard success else {
                completion(.failure(.authorizationDenied))
                return
            }
            let endDate = Date()
            guard let startDate = Calendar.current.date(byAdding: .day, value: -365, to: endDate) else {
                completion(.success(PRReport(records: [], longestRun: nil, longestDuration: nil)))
                return
            }

            self.dataManager.fetchRunningActivities(from: startDate, to: endDate) { activities in
                let records = PRDistance.allCases.map { distance -> PersonalRecord in
                    // Use ±5% tolerance so a 6 km easy run doesn't count as a 5 K PR.
                    let lower = distance.meters * 0.95
                    let upper = distance.meters * 1.05
                    let qualifying = activities.filter {
                        let d = $0.distance ?? 0
                        return d >= lower && d <= upper
                    }
                    let best = qualifying.min { lhs, rhs in
                        let lp = lhs.averagePaceMinutesPerKm ?? Double.greatestFiniteMagnitude
                        let rp = rhs.averagePaceMinutesPerKm ?? Double.greatestFiniteMagnitude
                        return lp < rp
                    }
                    return PersonalRecord(distance: distance, pace: best?.averagePaceMinutesPerKm, date: best?.startDate)
                }

                let longestRun = activities.max { ($0.distance ?? 0) < ($1.distance ?? 0) }
                let longestDuration = activities.max { $0.duration < $1.duration }

                completion(.success(PRReport(records: records, longestRun: longestRun, longestDuration: longestDuration)))
            }
        }
    }

    // MARK: - Helpers

    private func buildWeeklyMileage(from activities: [RunningActivity], startDate: Date, endDate: Date) -> [WeeklyMileage] {
        let calendar = Calendar.current
        var result: [WeeklyMileage] = []
        var weekStart = calendar.startOfWeek(for: startDate)

        while weekStart <= endDate {
            guard let weekEnd = calendar.date(byAdding: .weekOfYear, value: 1, to: weekStart) else { break }
            let weekActivities = activities.filter { $0.startDate >= weekStart && $0.startDate < weekEnd }
            let total = weekActivities.compactMap(\.distance).reduce(0, +)
            let longest = weekActivities.compactMap(\.distance).max() ?? 0
            result.append(WeeklyMileage(
                weekStart: weekStart,
                totalMeters: total,
                longestRunMeters: longest,
                runCount: weekActivities.count
            ))
            weekStart = weekEnd
        }
        return result
    }
}

private extension Calendar {
    func startOfWeek(for date: Date) -> Date {
        let components = dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return self.date(from: components) ?? date
    }
}
