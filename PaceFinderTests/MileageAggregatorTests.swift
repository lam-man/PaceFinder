import XCTest
@testable import PaceFinder

final class MileageAggregatorTests: XCTestCase {

    private var calendar: Calendar!
    private var aggregator: MileageAggregator!

    override func setUp() {
        super.setUp()
        var isoCalendar = Calendar(identifier: .iso8601)
        isoCalendar.timeZone = TimeZone(secondsFromGMT: 0)!
        isoCalendar.firstWeekday = 2
        isoCalendar.minimumDaysInFirstWeek = 4

        calendar = isoCalendar
        aggregator = MileageAggregator(calendar: isoCalendar)
    }

    func testWeeklyAggregationUsesMondayBoundaryAndCombinesSameDayRuns() {
        let reference = makeDate(2026, 5, 20)
        let monday = makeDate(2026, 5, 18)
        let sundayPreviousWeek = makeDate(2026, 5, 17)

        let activities = [
            MileageActivity(startDate: monday, distanceMeters: 1000),
            MileageActivity(startDate: monday.addingTimeInterval(3600), distanceMeters: 2500),
            MileageActivity(startDate: sundayPreviousWeek, distanceMeters: 3000)
        ]

        let bucket = aggregator.aggregate(activities: activities, granularity: .week, referenceDate: reference)

        XCTAssertEqual(bucket.bars.count, 7)
        XCTAssertEqual(bucket.bars[0].distanceMeters, 3500, accuracy: 0.001)
        XCTAssertEqual(bucket.totalDistanceMeters, 3500, accuracy: 0.001)
    }

    func testMonthAggregationHandlesLeapYearAndMonthEnd() {
        let reference = makeDate(2024, 2, 16)
        let activities = [
            MileageActivity(startDate: makeDate(2024, 2, 29), distanceMeters: 5000),
            MileageActivity(startDate: makeDate(2024, 2, 1), distanceMeters: 1200)
        ]

        let bucket = aggregator.aggregate(activities: activities, granularity: .month, referenceDate: reference)

        XCTAssertEqual(bucket.bars.count, 29)
        XCTAssertEqual(bucket.bars[0].distanceMeters, 1200, accuracy: 0.001)
        XCTAssertEqual(bucket.bars[28].distanceMeters, 5000, accuracy: 0.001)
        XCTAssertEqual(bucket.totalDistanceMeters, 6200, accuracy: 0.001)
    }

    func testHalfYearAggregationBuilds26MondayAlignedWeeks() {
        let reference = makeDate(2026, 5, 20)
        let monday = makeDate(2026, 5, 18)
        let firstWeek = makeDate(2025, 11, 24)

        let activities = [
            MileageActivity(startDate: firstWeek, distanceMeters: 2100),
            MileageActivity(startDate: monday, distanceMeters: 4200)
        ]

        let bucket = aggregator.aggregate(activities: activities, granularity: .halfYear, referenceDate: reference)

        XCTAssertEqual(bucket.bars.count, 26)
        XCTAssertEqual(calendar.component(.weekday, from: bucket.bars[0].startDate), 2)
        XCTAssertEqual(bucket.bars[0].distanceMeters, 2100, accuracy: 0.001)
        XCTAssertEqual(bucket.bars[25].distanceMeters, 4200, accuracy: 0.001)
    }

    func testYearAggregationReturns12MonthsAndKeepsCrossYearOwnership() {
        let activities = [
            MileageActivity(startDate: makeDate(2025, 12, 31), distanceMeters: 6000),
            MileageActivity(startDate: makeDate(2026, 1, 1), distanceMeters: 3000)
        ]

        let yearBucket = aggregator.aggregate(activities: activities, granularity: .year(2026), referenceDate: makeDate(2026, 5, 20))
        let range = aggregator.selectableYearRange(in: activities, referenceDate: makeDate(2026, 5, 20))

        XCTAssertEqual(yearBucket.bars.count, 12)
        XCTAssertEqual(yearBucket.bars[0].distanceMeters, 3000, accuracy: 0.001)
        XCTAssertEqual(yearBucket.bars[11].distanceMeters, 0, accuracy: 0.001)
        XCTAssertEqual(range.lowerBound, 2025)
        XCTAssertEqual(range.upperBound, 2026)
    }

    func testEmptyAndSingleActivityScenarios() {
        let empty = aggregator.aggregate(activities: [], granularity: .week, referenceDate: makeDate(2026, 5, 20))
        XCTAssertFalse(empty.hasData)
        XCTAssertEqual(empty.totalDistanceMeters, 0)

        let single = aggregator.aggregate(
            activities: [MileageActivity(startDate: makeDate(2026, 5, 20), distanceMeters: 1234)],
            granularity: .week,
            referenceDate: makeDate(2026, 5, 20)
        )

        XCTAssertTrue(single.hasData)
        XCTAssertEqual(single.totalDistanceMeters, 1234, accuracy: 0.001)
    }

    private func makeDate(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var components = DateComponents()
        components.calendar = calendar
        components.year = year
        components.month = month
        components.day = day
        components.hour = 8
        components.minute = 0
        components.second = 0
        return calendar.date(from: components)!
    }
}
