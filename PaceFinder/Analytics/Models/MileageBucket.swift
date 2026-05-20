import Foundation

enum MileageGranularity: Equatable {
    case week
    case month
    case halfYear
    case year(Int)
}

struct MileageActivity: Equatable {
    let startDate: Date
    let distanceMeters: Double
}

struct MileageBar: Identifiable, Equatable {
    let startDate: Date
    let endDate: Date
    let label: String
    let distanceMeters: Double

    var id: Date { startDate }
}

struct MileageBucket: Equatable {
    let granularity: MileageGranularity
    let bars: [MileageBar]

    var totalDistanceMeters: Double {
        bars.reduce(0) { $0 + $1.distanceMeters }
    }

    var hasData: Bool {
        bars.contains { $0.distanceMeters > 0 }
    }

    static let empty = MileageBucket(granularity: .week, bars: [])
}
