import XCTest
@testable import PaceFinder

final class PersonalRecordTests: XCTestCase {

    private func makeActivity(distance: Double, speed: Double, date: Date = Date()) -> RunningActivity {
        RunningActivity(
            workoutIdentifier: UUID(),
            startDate: date,
            endDate: date.addingTimeInterval(distance / speed),
            duration: distance / speed,
            distance: distance,
            averageSpeed: speed
        )
    }

    // Helper matching the ±5% tolerance used in AnalyticsService
    private func prsFrom(_ activities: [RunningActivity]) -> [PersonalRecord] {
        PRDistance.allCases.map { distance -> PersonalRecord in
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
    }

    func testPRForFiveK() {
        let activities = [
            makeActivity(distance: 5_000, speed: 3.5),
            makeActivity(distance: 5_000, speed: 3.0),
            makeActivity(distance: 5_000, speed: 4.0)  // fastest 5 K
        ]
        let prs = prsFrom(activities)
        let fivekPR = prs.first { $0.distance == .fiveK }
        XCTAssertNotNil(fivekPR?.pace)
        if let pace = fivekPR?.pace {
            XCTAssertEqual(pace, 1_000.0 / 4.0 / 60.0, accuracy: 0.01)
        }
    }

    /// A 6 km easy run must NOT register as the 5 K PR (outside ±5% band).
    func testSixKRunDoesNotCountAsFiveKPR() {
        let fiveKTempo  = makeActivity(distance: 5_000, speed: 3.5)  // 4:46/km
        let sixKEasy    = makeActivity(distance: 6_000, speed: 4.0)  // 4:10/km — faster pace but wrong distance
        let prs = prsFrom([fiveKTempo, sixKEasy])
        let fivekPR = prs.first { $0.distance == .fiveK }
        // Should use the actual 5 K run, not the 6 K run
        XCTAssertEqual(fivekPR?.pace ?? 0, 1_000.0 / 3.5 / 60.0, accuracy: 0.01)
    }

    func testNoDataForMarathon() {
        let activities = [makeActivity(distance: 10_000, speed: 3.0)]
        let prs = prsFrom(activities)
        let marathonPR = prs.first { $0.distance == .marathon }
        XCTAssertNil(marathonPR?.pace)
    }

    func testLongestRun() {
        let activities = [
            makeActivity(distance: 10_000, speed: 3.0),
            makeActivity(distance: 21_097, speed: 3.2),
            makeActivity(distance: 5_000, speed: 4.0)
        ]
        let longestRun = activities.max { ($0.distance ?? 0) < ($1.distance ?? 0) }
        XCTAssertEqual(longestRun?.distance ?? 0, 21_097, accuracy: 1)
    }
}
