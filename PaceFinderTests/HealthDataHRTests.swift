import XCTest
@testable import PaceFinder

final class HealthDataHRTests: XCTestCase {
    private func makeActivity() -> RunningActivity {
        RunningActivity(
            workoutIdentifier: UUID(),
            startDate: Date(timeIntervalSince1970: 1_000),
            endDate: Date(timeIntervalSince1970: 1_100),
            duration: 100
        )
    }

    func testAverageHeartRateCalculatesMean() {
        let samples = [
            HeartRateSample(date: Date(timeIntervalSince1970: 1_000), bpm: 140),
            HeartRateSample(date: Date(timeIntervalSince1970: 1_010), bpm: 160)
        ]

        let average = HealthData.averageHeartRate(from: samples)

        XCTAssertEqual(average, 150)
    }

    func testAverageHeartRateReturnsNilForEmptySamples() {
        XCTAssertNil(HealthData.averageHeartRate(from: []))
    }

    func testHeartRateSampleSupportsHashableAndCodable() throws {
        let sample = HeartRateSample(date: Date(timeIntervalSince1970: 1_000), bpm: 150)
        let data = try JSONEncoder().encode(sample)
        let decoded = try JSONDecoder().decode(HeartRateSample.self, from: data)
        XCTAssertEqual(decoded, sample)
    }

    @available(iOS 16.0, *)
    func testApplyHeartRateResultMapsSamplesAndAverages() {
        var activity = makeActivity()
        let samples = [
            HeartRateSample(date: Date(timeIntervalSince1970: 1_000), bpm: 145),
            HeartRateSample(date: Date(timeIntervalSince1970: 1_010), bpm: 155)
        ]

        RunningDataManager.applyHeartRateResult(.success(samples), to: &activity, workoutID: activity.workoutIdentifier)

        XCTAssertEqual(activity.heartRateSamples, samples)
        XCTAssertEqual(activity.avgHeartRate, 150)
        XCTAssertEqual(activity.maxHeartRate, 155)
    }

    @available(iOS 16.0, *)
    func testApplyHeartRateResultClearsHeartRateOnError() {
        var activity = makeActivity()
        activity.heartRateSamples = [HeartRateSample(date: Date(timeIntervalSince1970: 1_000), bpm: 150)]
        activity.avgHeartRate = 150
        activity.maxHeartRate = 150

        RunningDataManager.applyHeartRateResult(.failure(.notAuthorized), to: &activity, workoutID: activity.workoutIdentifier)

        XCTAssertNil(activity.heartRateSamples)
        XCTAssertNil(activity.avgHeartRate)
        XCTAssertNil(activity.maxHeartRate)
    }
}
