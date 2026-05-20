import Foundation
import HealthKit

enum PreferredUnitSource {
    case preferred
    case fallbackNoHealthData
    case fallbackAuthorizationDenied
    case fallbackUnavailable
    case fallbackError
}

struct PreferredDistanceUnitSelection {
    let unit: DistanceDisplayUnit
    let source: PreferredUnitSource
}

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

    func fetchPreferredDistanceUnit(completion: @escaping (PreferredDistanceUnitSelection) -> Void) {
        guard HKHealthStore.isHealthDataAvailable(),
              let distanceType = HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)
        else {
            completion(PreferredDistanceUnitSelection(unit: .kilometers, source: .fallbackNoHealthData))
            return
        }

        if healthStore.authorizationStatus(for: distanceType) == .sharingDenied {
            completion(PreferredDistanceUnitSelection(unit: .kilometers, source: .fallbackAuthorizationDenied))
            return
        }

        healthStore.preferredUnits(for: [distanceType]) { units, error in
            if error != nil {
                completion(PreferredDistanceUnitSelection(unit: .kilometers, source: .fallbackError))
                return
            }

            guard let unit = units[distanceType] else {
                completion(PreferredDistanceUnitSelection(unit: .kilometers, source: .fallbackUnavailable))
                return
            }

            if unit == .mile() {
                completion(PreferredDistanceUnitSelection(unit: .miles, source: .preferred))
            } else {
                completion(PreferredDistanceUnitSelection(unit: .kilometers, source: .preferred))
            }
        }
    }
}
