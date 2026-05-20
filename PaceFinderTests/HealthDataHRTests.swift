import XCTest
@testable import PaceFinder

final class HealthDataHRTests: XCTestCase {
    func testNormalizeHeartRateSamplesFiltersAndSortsByDate() {
        let start = Date(timeIntervalSince1970: 1_000)
        let end = Date(timeIntervalSince1970: 1_100)
        let samples = [
            HeartRateSample(date: Date(timeIntervalSince1970: 1_120), bpm: 160),
            HeartRateSample(date: Date(timeIntervalSince1970: 1_050), bpm: 150),
            HeartRateSample(date: Date(timeIntervalSince1970: 990), bpm: 140),
            HeartRateSample(date: Date(timeIntervalSince1970: 1_010), bpm: 145)
        ]

        let normalized = HealthData.normalizeHeartRateSamples(samples, between: start, and: end)

        XCTAssertEqual(normalized?.map(\.bpm), [145, 150])
    }

    func testNormalizeHeartRateSamplesReturnsNilForEmptyResult() {
        let start = Date(timeIntervalSince1970: 2_000)
        let end = Date(timeIntervalSince1970: 2_100)
        let samples = [HeartRateSample(date: Date(timeIntervalSince1970: 1_900), bpm: 150)]

        let normalized = HealthData.normalizeHeartRateSamples(samples, between: start, and: end)

        XCTAssertNil(normalized)
    }

    func testAverageHeartRateCalculatesMean() {
        let samples = [
            HeartRateSample(date: Date(timeIntervalSince1970: 1_000), bpm: 140),
            HeartRateSample(date: Date(timeIntervalSince1970: 1_010), bpm: 160)
        ]

        let average = HealthData.averageHeartRate(from: samples)

        XCTAssertEqual(average, 150)
    }
}
