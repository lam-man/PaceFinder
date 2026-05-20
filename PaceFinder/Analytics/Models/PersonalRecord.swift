import Foundation

enum PRDistance: String, CaseIterable {
    case oneK = "1K"
    case fiveK = "5K"
    case tenK = "10K"
    case halfMarathon = "Half Marathon"
    case marathon = "Marathon"

    var meters: Double {
        switch self {
        case .oneK: return 1_000
        case .fiveK: return 5_000
        case .tenK: return 10_000
        case .halfMarathon: return 21_097.5
        case .marathon: return 42_195
        }
    }
}

struct PersonalRecord {
    let distance: PRDistance
    let pace: Double? // min/km
    let date: Date?
}

struct PRReport {
    let records: [PersonalRecord]
    let longestRun: RunningActivity?
    let longestDuration: RunningActivity?
}
