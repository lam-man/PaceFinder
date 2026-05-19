import UIKit

enum HRZone: Int, CaseIterable {
    case z1 = 1, z2, z3, z4, z5

    var displayName: String {
        switch self {
        case .z1: return "Zone 1"
        case .z2: return "Zone 2"
        case .z3: return "Zone 3"
        case .z4: return "Zone 4"
        case .z5: return "Zone 5"
        }
    }

    var lowerPercent: Double {
        switch self {
        case .z1: return 0.50
        case .z2: return 0.60
        case .z3: return 0.70
        case .z4: return 0.80
        case .z5: return 0.90
        }
    }

    var upperPercent: Double {
        switch self {
        case .z1: return 0.60
        case .z2: return 0.70
        case .z3: return 0.80
        case .z4: return 0.90
        case .z5: return 1.00
        }
    }

    var color: UIColor {
        switch self {
        case .z1: return .systemBlue
        case .z2: return .systemGreen
        case .z3: return .systemYellow
        case .z4: return .systemOrange
        case .z5: return .systemRed
        }
    }
}
