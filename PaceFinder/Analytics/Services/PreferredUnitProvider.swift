import Foundation
import HealthKit

enum DistanceDisplayUnit {
    case kilometers
    case miles

    var symbol: String {
        switch self {
        case .kilometers:
            return "km"
        case .miles:
            return "mi"
        }
    }

    var unitLength: UnitLength {
        switch self {
        case .kilometers:
            return .kilometers
        case .miles:
            return .miles
        }
    }

    func convert(meters: Double) -> Double {
        Measurement(value: meters, unit: UnitLength.meters)
            .converted(to: unitLength)
            .value
    }
}

final class PreferredUnitProvider {

    private let healthStore: HKHealthStore

    init(healthStore: HKHealthStore = HealthData.healthStore) {
        self.healthStore = healthStore
    }

    func fetchPreferredDistanceUnit(completion: @escaping (DistanceDisplayUnit) -> Void) {
        guard HKHealthStore.isHealthDataAvailable(),
              let distanceType = HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)
        else {
            completion(.kilometers)
            return
        }

        healthStore.preferredUnits(for: [distanceType]) { units, _ in
            guard let unit = units[distanceType] else {
                completion(.kilometers)
                return
            }

            if unit == .mile() {
                completion(.miles)
            } else {
                completion(.kilometers)
            }
        }
    }
}
