import XCTest
@testable import PaceFinder

final class TrainingLoadCalculatorTests: XCTestCase {

    private let calc = TrainingLoadCalculator()

    // MARK: - ACWR

    /// At steady-state training load ACWR must equal 1.0 (Gabbett 2016).
    func testACWREquilibrium() {
        let weeklyLoad = 60_000.0
        let result = calc.acwr(acute7dMeters: weeklyLoad, chronic28dMeters: weeklyLoad * 4)
        XCTAssertEqual(result, 1.0, accuracy: 0.001)
    }

    /// Doubling acute load while chronic stays flat → ACWR ≈ 2.0.
    func testACWROvertraining() {
        let result = calc.acwr(acute7dMeters: 80_000, chronic28dMeters: 4 * 40_000)
        XCTAssertEqual(result, 2.0, accuracy: 0.001)
    }

    func testACWRZeroChronic() {
        XCTAssertEqual(calc.acwr(acute7dMeters: 50_000, chronic28dMeters: 0), 0)
    }

    // MARK: - 10% rule (week-over-week)

    func testTenPercentRuleViolated() {
        // 60 km vs 50 km last week = +20 % → violated
        XCTAssertTrue(calc.violatesTenPercentRule(thisWeekMeters: 60_000, lastWeekMeters: 50_000))
    }

    func testTenPercentRuleNotViolated() {
        // 54 km vs 50 km last week = +8 % → ok
        XCTAssertFalse(calc.violatesTenPercentRule(thisWeekMeters: 54_000, lastWeekMeters: 50_000))
    }

    func testTenPercentRuleZeroLastWeek() {
        // First week of training: no last-week baseline → not violated
        XCTAssertFalse(calc.violatesTenPercentRule(thisWeekMeters: 10_000, lastWeekMeters: 0))
    }

    // MARK: - Longest run ratio

    func testLongestRunRatio() {
        let ratio = calc.longestRunRatio(longestRunMeters: 15_000, weekTotalMeters: 50_000)
        XCTAssertEqual(ratio, 0.30, accuracy: 0.001)
    }

    // MARK: - Streak

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

    // MARK: - Rolling average

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
