import XCTest
@testable import PaceFinder

final class TrainingLoadCalculatorTests: XCTestCase {

    private let calc = TrainingLoadCalculator()

    func testACWR() {
        let result = calc.acwr(recentWeekMeters: 70_000, rollingAvgDailyMeters28: 8_000)
        XCTAssertEqual(result, 10_000.0 / 8_000.0, accuracy: 0.001)
    }

    func testACWRZeroChronic() {
        XCTAssertEqual(calc.acwr(recentWeekMeters: 50_000, rollingAvgDailyMeters28: 0), 0)
    }

    func testTenPercentRuleViolated() {
        XCTAssertTrue(calc.violatesTenPercentRule(thisWeekMeters: 60_000, avgMeters4Weeks: 50_000))
    }

    func testTenPercentRuleNotViolated() {
        XCTAssertFalse(calc.violatesTenPercentRule(thisWeekMeters: 54_000, avgMeters4Weeks: 50_000))
    }

    func testLongestRunRatio() {
        let ratio = calc.longestRunRatio(longestRunMeters: 15_000, weekTotalMeters: 50_000)
        XCTAssertEqual(ratio, 0.30, accuracy: 0.001)
    }

    func testStreakEmpty() {
        XCTAssertEqual(calc.streak(from: []), 0)
    }

    func testStreakWithGap() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: today)!
        let fourDaysAgo = calendar.date(byAdding: .day, value: -4, to: today)!

        let activities = [today, yesterday, twoDaysAgo, fourDaysAgo].map { date in
            RunningActivity(workoutIdentifier: UUID(), startDate: date, endDate: date.addingTimeInterval(1800), duration: 1800)
        }
        XCTAssertEqual(calc.streak(from: activities), 3)
    }

    func testRollingAverage() {
        let calendar = Calendar.current
        let today = Date()
        let weeks = (0..<6).map { i -> WeeklyMileage in
            let weekStart = calendar.date(byAdding: .weekOfYear, value: -i, to: today)!
            return WeeklyMileage(weekStart: weekStart, totalMeters: Double(i + 1) * 10_000, longestRunMeters: 8_000, runCount: 3)
        }
        let avg = calc.rollingAverage(weeks: weeks, weekCount: 4)
        XCTAssertGreaterThan(avg, 0)
    }
}
