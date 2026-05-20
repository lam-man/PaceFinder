import Foundation

final class MileageAggregator {

    private let calendar: Calendar

    init(calendar: Calendar = MileageAggregator.isoCalendar) {
        self.calendar = calendar
    }

    static var isoCalendar: Calendar {
        var calendar = Calendar(identifier: .iso8601)
        calendar.firstWeekday = 2
        calendar.minimumDaysInFirstWeek = 4
        calendar.timeZone = .current
        return calendar
    }

    func earliestActivityYear(in activities: [MileageActivity]) -> Int? {
        guard let earliest = activities.map(\.startDate).min() else { return nil }
        return calendar.component(.year, from: earliest)
    }

    func selectableYearRange(in activities: [MileageActivity], referenceDate: Date = Date()) -> ClosedRange<Int> {
        let currentYear = calendar.component(.year, from: referenceDate)
        let earliestYear = earliestActivityYear(in: activities) ?? currentYear
        return earliestYear...currentYear
    }

    func aggregate(
        activities: [MileageActivity],
        granularity: MileageGranularity,
        referenceDate: Date = Date()
    ) -> MileageBucket {
        switch granularity {
        case .week:
            return buildWeekBucket(activities: activities, referenceDate: referenceDate)
        case .month:
            return buildMonthBucket(activities: activities, referenceDate: referenceDate)
        case .halfYear:
            return buildHalfYearBucket(activities: activities, referenceDate: referenceDate)
        case .year(let year):
            return buildYearBucket(activities: activities, year: year)
        }
    }

    private func buildWeekBucket(activities: [MileageActivity], referenceDate: Date) -> MileageBucket {
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: referenceDate) else {
            return MileageBucket(granularity: .week, bars: [])
        }

        let sums = aggregateByDay(activities: activities, interval: weekInterval)
        let labels = mondayFirstWeekdaySymbols()
        var bars: [MileageBar] = []

        for offset in 0..<7 {
            guard let startDate = calendar.date(byAdding: .day, value: offset, to: weekInterval.start),
                  let endDate = calendar.date(byAdding: .day, value: 1, to: startDate)
            else {
                continue
            }

            bars.append(MileageBar(
                startDate: startDate,
                endDate: endDate,
                label: labels[offset],
                distanceMeters: sums[startDate, default: 0]
            ))
        }

        return MileageBucket(granularity: .week, bars: bars)
    }

    private func buildMonthBucket(activities: [MileageActivity], referenceDate: Date) -> MileageBucket {
        guard let monthInterval = calendar.dateInterval(of: .month, for: referenceDate),
              let dayCountRange = calendar.range(of: .day, in: .month, for: referenceDate)
        else {
            return MileageBucket(granularity: .month, bars: [])
        }

        let sums = aggregateByDay(activities: activities, interval: monthInterval)
        var bars: [MileageBar] = []

        for day in dayCountRange {
            guard let startDate = calendar.date(byAdding: .day, value: day - 1, to: monthInterval.start),
                  let endDate = calendar.date(byAdding: .day, value: 1, to: startDate)
            else {
                continue
            }

            bars.append(MileageBar(
                startDate: startDate,
                endDate: endDate,
                label: String(day),
                distanceMeters: sums[startDate, default: 0]
            ))
        }

        return MileageBucket(granularity: .month, bars: bars)
    }

    private func buildHalfYearBucket(activities: [MileageActivity], referenceDate: Date) -> MileageBucket {
        guard let currentWeek = calendar.dateInterval(of: .weekOfYear, for: referenceDate),
              let startDate = calendar.date(byAdding: .weekOfYear, value: -25, to: currentWeek.start)
        else {
            return MileageBucket(granularity: .halfYear, bars: [])
        }

        var bars: [MileageBar] = []
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = .current
        formatter.dateFormat = "M/d"

        for offset in 0..<26 {
            guard let barStart = calendar.date(byAdding: .weekOfYear, value: offset, to: startDate),
                  let barEnd = calendar.date(byAdding: .day, value: 7, to: barStart)
            else {
                continue
            }

            let total = activities.reduce(into: 0.0) { partialResult, activity in
                guard activity.distanceMeters > 0,
                      activity.startDate >= barStart,
                      activity.startDate < barEnd else {
                    return
                }
                partialResult += activity.distanceMeters
            }

            bars.append(MileageBar(
                startDate: barStart,
                endDate: barEnd,
                label: formatter.string(from: barStart),
                distanceMeters: total
            ))
        }

        return MileageBucket(granularity: .halfYear, bars: bars)
    }

    private func buildYearBucket(activities: [MileageActivity], year: Int) -> MileageBucket {
        var components = DateComponents()
        components.calendar = calendar
        components.year = year
        components.month = 1
        components.day = 1

        guard let yearStart = components.date,
              let yearEnd = calendar.date(byAdding: .year, value: 1, to: yearStart)
        else {
            return MileageBucket(granularity: .year(year), bars: [])
        }

        var bars: [MileageBar] = []
        let labels = shortMonthSymbols()

        for monthIndex in 0..<12 {
            guard let startDate = calendar.date(byAdding: .month, value: monthIndex, to: yearStart),
                  let endDate = calendar.date(byAdding: .month, value: 1, to: startDate)
            else {
                continue
            }

            let total = activities.reduce(into: 0.0) { partialResult, activity in
                guard activity.distanceMeters > 0,
                      activity.startDate >= startDate,
                      activity.startDate < endDate,
                      activity.startDate < yearEnd else {
                    return
                }
                partialResult += activity.distanceMeters
            }

            bars.append(MileageBar(
                startDate: startDate,
                endDate: endDate,
                label: labels[monthIndex],
                distanceMeters: total
            ))
        }

        return MileageBucket(granularity: .year(year), bars: bars)
    }

    private func aggregateByDay(
        activities: [MileageActivity],
        interval: DateInterval
    ) -> [Date: Double] {
        activities.reduce(into: [Date: Double]()) { partialResult, activity in
            guard activity.distanceMeters > 0,
                  interval.contains(activity.startDate) else {
                return
            }
            let dayStart = calendar.startOfDay(for: activity.startDate)
            partialResult[dayStart, default: 0] += activity.distanceMeters
        }
    }

    private func mondayFirstWeekdaySymbols() -> [String] {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = .current
        let symbols = formatter.shortWeekdaySymbols

        guard symbols.count == 7 else { return symbols }
        return Array(symbols[1...6]) + [symbols[0]]
    }

    private func shortMonthSymbols() -> [String] {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = .current
        return formatter.shortMonthSymbols
    }
}
