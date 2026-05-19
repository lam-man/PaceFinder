import XCTest
@testable import PaceFinder

final class HRZoneCalculatorTests: XCTestCase {

    private let calc = HRZoneCalculator()
    private let maxHR = 200.0

    func testZone1() {
        XCTAssertEqual(calc.zoneFor(heartRate: 110, maxHR: maxHR), .z1)
    }

    func testZone2() {
        XCTAssertEqual(calc.zoneFor(heartRate: 130, maxHR: maxHR), .z2)
    }

    func testZone3() {
        XCTAssertEqual(calc.zoneFor(heartRate: 150, maxHR: maxHR), .z3)
    }

    func testZone4() {
        XCTAssertEqual(calc.zoneFor(heartRate: 170, maxHR: maxHR), .z4)
    }

    func testZone5() {
        XCTAssertEqual(calc.zoneFor(heartRate: 190, maxHR: maxHR), .z5)
    }

    func testBelowZone1ReturnsNil() {
        XCTAssertNil(calc.zoneFor(heartRate: 90, maxHR: maxHR))
    }

    func testZeroMaxHRReturnsNil() {
        XCTAssertNil(calc.zoneFor(heartRate: 150, maxHR: 0))
    }

    func testEasyPercent() {
        let durations = [
            ZoneDuration(zone: .z1, seconds: 1200),
            ZoneDuration(zone: .z2, seconds: 1200),
            ZoneDuration(zone: .z3, seconds: 600),
            ZoneDuration(zone: .z4, seconds: 0),
            ZoneDuration(zone: .z5, seconds: 0)
        ]
        let pct = calc.easyPercent(from: durations)
        XCTAssertEqual(pct, 0.8, accuracy: 0.001)
    }

    func testZoneDurations() {
        let samples: [(hr: Double, duration: TimeInterval)] = [
            (hr: 110, duration: 300),
            (hr: 130, duration: 300),
            (hr: 150, duration: 300)
        ]
        let result = calc.zoneDurations(from: samples, maxHR: maxHR)
        XCTAssertEqual(result.count, 5)
        let z1 = result.first { $0.zone == .z1 }?.seconds ?? 0
        let z2 = result.first { $0.zone == .z2 }?.seconds ?? 0
        let z3 = result.first { $0.zone == .z3 }?.seconds ?? 0
        XCTAssertEqual(z1, 300)
        XCTAssertEqual(z2, 300)
        XCTAssertEqual(z3, 300)
    }
}
