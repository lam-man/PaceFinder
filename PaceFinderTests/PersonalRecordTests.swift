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

    func testPRForFiveK() {
        let activities = [
            makeActivity(distance: 5_000, speed: 3.5),
            makeActivity(distance: 5_000, speed: 3.0),
            makeActivity(distance: 5_000, speed: 4.0)
        ]

        let prs = PRDistance.allCases.map { distance -> PersonalRecord in
            let qualifying = activities.filter { ($0.distance ?? 0) >= distance.meters }
            let best = qualifying.min { lhs, rhs in
                let lp = lhs.averagePaceMinutesPerKm ?? Double.greatestFiniteMagnitude
                let rp = rhs.averagePaceMinutesPerKm ?? Double.greatestFiniteMagnitude
                return lp < rp
            }
            return PersonalRecord(distance: distance, pace: best?.averagePaceMinutesPerKm, date: best?.startDate)
        }

        let fivekPR = prs.first { $0.distance == .fiveK }
        XCTAssertNotNil(fivekPR?.pace)
        if let pace = fivekPR?.pace {
            XCTAssertEqual(pace, 1000.0 / 4.0 / 60.0, accuracy: 0.01)
        }
    }

    func testNoDataForMarathon() {
        let activities = [makeActivity(distance: 10_000, speed: 3.0)]

        let qualifying = activities.filter { ($0.distance ?? 0) >= PRDistance.marathon.meters }
        let best = qualifying.min { lhs, rhs in
            let lp = lhs.averagePaceMinutesPerKm ?? Double.greatestFiniteMagnitude
            let rp = rhs.averagePaceMinutesPerKm ?? Double.greatestFiniteMagnitude
            return lp < rp
        }
        let pr = PersonalRecord(distance: .marathon, pace: best?.averagePaceMinutesPerKm, date: best?.startDate)
        XCTAssertNil(pr.pace)
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
