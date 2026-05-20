//import Foundation
//import HealthKit
//
//class RunningDataManager {
//
//    private let healthStore = HealthData.healthStore
//
//    // MARK: - Fetch Running Activities
//
//    /// Fetch running workouts with all associated metrics grouped by workout
//    func fetchRunningActivities(from startDate: Date = getLastWeekStartDate(),
//                               to endDate: Date = Date(),
//                               completion: @escaping ([RunningActivity]) -> Void) {
//
//        // Step 1: Query running workouts
//        fetchRunningWorkouts(from: startDate, to: endDate) { [weak self] workouts in
//            guard !workouts.isEmpty else {
//                completion([])
//                return
//            }
//
//            // Step 2: For each workout, fetch associated metrics
//            self?.fetchMetricsForWorkouts(workouts, completion: completion)
//        }
//    }
//
//    // MARK: - Private Methods
//
//    private func fetchRunningWorkouts(from startDate: Date, to endDate: Date, completion: @escaping ([HKWorkout]) -> Void) {
//        let workoutType = HKWorkoutType.workoutType()
//        let predicate = HKQuery.predicateForWorkouts(with: .running)
//        let datePredicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate)
//        let compoundPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [predicate, datePredicate])
//
//        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
//
//        let query = HKSampleQuery(sampleType: workoutType,
//                                 predicate: compoundPredicate,
//                                 limit: HKObjectQueryNoLimit,
//                                 sortDescriptors: [sortDescriptor]) { query, samples, error in
//
//            guard let workouts = samples as? [HKWorkout], error == nil else {
//                print("Error fetching workouts: \(error?.localizedDescription ?? "Unknown error")")
//                completion([])
//                return
//            }
//
//            completion(workouts)
//        }
//
//        healthStore.execute(query)
//    }
//
//    private func fetchMetricsForWorkouts(_ workouts: [HKWorkout], completion: @escaping ([RunningActivity]) -> Void) {
//        let group = DispatchGroup()
//        var runningActivities: [RunningActivity] = []
//
//        for workout in workouts {
//            group.enter()
//
//            fetchMetricsForSingleWorkout(workout) { activity in
//                if let activity = activity {
//                    runningActivities.append(activity)
//                }
//                group.leave()
//            }
//        }
//
//        group.notify(queue: .main) {
//            // Sort by start date (most recent first)
//            let sortedActivities = runningActivities.sorted { $0.startDate > $1.startDate }
//            completion(sortedActivities)
//        }
//    }
//
//    private func fetchMetricsForSingleWorkout(_ workout: HKWorkout, completion: @escaping (RunningActivity?) -> Void) {
//        let workoutPredicate = HKQuery.predicateForObjects(from: workout)
//        let availableTypes = HealthData.getAvailableRunningDataTypes()
//
//        var activity = RunningActivity(
//            workoutIdentifier: workout.uuid,
//            startDate: workout.startDate,
//            endDate: workout.endDate,
//            duration: workout.duration,
//            distance: workout.totalDistance?.doubleValue(for: .meter()),
//            averageSpeed: nil as Double?,
//            averageHeartRate: nil as Double?,
//            maxHeartRate: nil as Double?,
//            averagePower: nil as Double?,
//            groundContactTime: nil as Double?,
//            strideLength: nil as Double?,
//            verticalOscillation: nil as Double?
//        )
//
//        let group = DispatchGroup()
//
//        // Fetch each available metric type
//        for typeIdentifier in availableTypes {
//            guard let sampleType = getSampleType(for: typeIdentifier) as? HKQuantityType else { continue }
//
//            group.enter()
//
//            let query = HKSampleQuery(sampleType: sampleType,
//                                    predicate: workoutPredicate,
//                                    limit: HKObjectQueryNoLimit,
//                                    sortDescriptors: nil) { query, samples, error in
//
//                defer { group.leave() }
//
//                guard let quantitySamples = samples as? [HKQuantitySample], error == nil else { return }
//
//                if #available(iOS 16.0, *) {
//                    self.processMetricSamples(quantitySamples, for: typeIdentifier, into: &activity)
//                } else {
//                    // Fallback on earlier versions
//                }
//            }
//
//            healthStore.execute(query)
//        }
//
//        group.notify(queue: .main) {
//            completion(activity)
//        }
//    }
//
//    @available(iOS 16.0, *)
//    private func processMetricSamples(_ samples: [HKQuantitySample], for typeIdentifier: String, into activity: inout RunningActivity) {
//        guard !samples.isEmpty else { return }
//
//        let identifier = HKQuantityTypeIdentifier(rawValue: typeIdentifier)
//
//        switch identifier {
//        case .heartRate:
//            guard let unit = preferredUnit(for: typeIdentifier) else { return }
//            let heartRates = samples.map { $0.quantity.doubleValue(for: unit) }
//            activity.avgHeartRate = heartRates.reduce(0, +) / Double(heartRates.count)
//            activity.maxHeartRate = heartRates.max()
//
//        default:
//            // Handle iOS 16.0+ metrics
//            processAdvancedMetrics(samples, for: identifier, into: &activity)
//        }
//    }
//
//    @available(iOS 16.0, *)
//    private func processAdvancedMetrics(_ samples: [HKQuantitySample], for identifier: HKQuantityTypeIdentifier, into activity: inout RunningActivity) {
//        guard let unit = preferredUnit(for: identifier.rawValue) else { return }
//        let values = samples.map { $0.quantity.doubleValue(for: unit) }
//        let averageValue = values.reduce(0, +) / Double(values.count)
//
//        switch identifier {
//        case .runningSpeed:
//            activity.averageSpeed = averageValue
//
//        case .runningPower:
//            activity.averagePower = averageValue
//
//        case .runningGroundContactTime:
//            activity.groundContactTime = averageValue
//
//        case .runningStrideLength:
//            activity.strideLength = averageValue
//
//        case .runningVerticalOscillation:
//            activity.verticalOscillation = averageValue
//
//        default:
//            break
//        }
//    }
//}

import Foundation
import HealthKit

@available(iOS 16.0, *)
class RunningDataManager {

    private enum HeartRateCacheEntry {
        case samples([HeartRateSample])
        case unavailable
    }

    private let healthStore = HealthData.healthStore
    private let heartRateDataProvider: HeartRateDataProviding
    private var heartRateCache: [UUID: HeartRateCacheEntry] = [:]
    private let heartRateCacheQueue = DispatchQueue(label: "RunningDataManager.heartRateCacheQueue")

    init(heartRateDataProvider: HeartRateDataProviding = HealthData()) {
        self.heartRateDataProvider = heartRateDataProvider
    }

    // MARK: - Fetch Running Activities

    /// Fetch running workouts with all associated metrics grouped by workout
    func fetchRunningActivities(from startDate: Date = getLastWeekStartDate(),
                               to endDate: Date = Date(),
                               completion: @escaping ([RunningActivity]) -> Void) {

        // Step 1: Query running workouts
        fetchRunningWorkouts(from: startDate, to: endDate) { [weak self] workouts in
            guard !workouts.isEmpty else {
                completion([])
                return
            }

            // Step 2: For each workout, fetch associated metrics
            self?.fetchMetricsForWorkouts(workouts, completion: completion)
        }
    }

    // MARK: - Private Methods

    private func fetchRunningWorkouts(from startDate: Date, to endDate: Date, completion: @escaping ([HKWorkout]) -> Void) {
        let workoutType = HKWorkoutType.workoutType()
        let predicate = HKQuery.predicateForWorkouts(with: .running)
        let datePredicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate)
        let compoundPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [predicate, datePredicate])

        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        let query = HKSampleQuery(sampleType: workoutType,
                                 predicate: compoundPredicate,
                                 limit: HKObjectQueryNoLimit,
                                 sortDescriptors: [sortDescriptor]) { query, samples, error in

            guard let workouts = samples as? [HKWorkout], error == nil else {
                print("Error fetching workouts: \(error?.localizedDescription ?? "Unknown error")")
                completion([])
                return
            }

            completion(workouts)
        }

        healthStore.execute(query)
    }

    private func fetchMetricsForWorkouts(_ workouts: [HKWorkout], completion: @escaping ([RunningActivity]) -> Void) {
        let group = DispatchGroup()
        var runningActivities: [RunningActivity] = []
        let activitiesMutationQueue = DispatchQueue(label: "RunningDataManager.activitiesMutation")

        for workout in workouts {
            group.enter()

            fetchMetricsForSingleWorkout(workout) { activity in
                if let activity = activity {
                    activitiesMutationQueue.sync {
                        runningActivities.append(activity)
                    }
                }
                group.leave()
            }
        }

        group.notify(queue: .main) {
            // Sort by start date (most recent first)
            let sortedActivities = activitiesMutationQueue.sync {
                runningActivities.sorted { $0.startDate > $1.startDate }
            }
            completion(sortedActivities)
        }
    }

    private func fetchMetricsForSingleWorkout(_ workout: HKWorkout, completion: @escaping (RunningActivity?) -> Void) {
        let activityMutationQueue = DispatchQueue(label: "RunningDataManager.activityMutation.\(workout.uuid)")
        let isCompletedWorkout = workout.endDate < Date()

        let workoutPredicate = HKQuery.predicateForSamples(
            withStart: workout.startDate,
            end: workout.endDate,
            options: .strictStartDate
        )

        var activity = RunningActivity(
            workoutIdentifier: workout.uuid,
            startDate: workout.startDate,
            endDate: workout.endDate,
            duration: workout.duration,
            distance: workout.totalDistance?.doubleValue(for: .meter())
        )

        let group = DispatchGroup()

        // Track step count for an estimated cadence calculation.
        var totalSteps: Double?

        // Define all metric types to query
        let metricsToQuery: [(HKQuantityTypeIdentifier, HKUnit)] = [
            (.stepCount, HKUnit.count())
        ]

        // Add iOS 16+ metrics if available
        var advancedMetrics: [(HKQuantityTypeIdentifier, HKUnit)] = []
        if #available(iOS 16.0, *) {
            advancedMetrics = [
                (.runningSpeed, HKUnit.meter().unitDivided(by: .second())),
                (.runningPower, HKUnit.watt()),
                (.runningGroundContactTime, HKUnit.secondUnit(with: .milli)),
                (.runningStrideLength, HKUnit.meter()),
                (.runningVerticalOscillation, HKUnit.meter())
            ]
        }

        let allMetrics = metricsToQuery + advancedMetrics

        group.enter()
        fetchHeartRateSamples(for: workout, isCompletedWorkout: isCompletedWorkout) { result in
            defer { group.leave() }

            activityMutationQueue.sync {
                Self.applyHeartRateResult(result, to: &activity, workoutID: workout.uuid)
            }
        }

        // Fetch each metric type
        for (identifier, unit) in allMetrics {
            guard let quantityType = HKQuantityType.quantityType(forIdentifier: identifier) else { continue }

            group.enter()

            let query = HKSampleQuery(
                sampleType: quantityType,
                predicate: workoutPredicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { query, samples, error in
                defer { group.leave() }

                guard let quantitySamples = samples as? [HKQuantitySample],
                      error == nil,
                      !quantitySamples.isEmpty else {
                    return
                }

                activityMutationQueue.sync {
                    // Process the samples
                    self.processMetricSamples(
                        quantitySamples,
                        for: identifier,
                        unit: unit,
                        into: &activity,
                        totalSteps: &totalSteps
                    )
                }
            }

            healthStore.execute(query)
        }

        group.notify(queue: .main) {
            activityMutationQueue.sync {
                if let steps = totalSteps, steps > 0, activity.duration > 0 {
                    activity.estimatedCadence = (steps / activity.duration) * 60.0
                    activity.cadenceNote = "Estimated from step count and duration."
                } else {
                    activity.cadenceNote = "Not enough step-count data to calculate cadence."
                }
            }

            completion(activity)
        }
    }

    private func fetchHeartRateSamples(for workout: HKWorkout,
                                       isCompletedWorkout: Bool,
                                       completion: @escaping (Result<[HeartRateSample], HeartRateDataError>) -> Void) {
        if isCompletedWorkout, let cachedEntry = cachedHeartRateEntry(for: workout.uuid) {
            switch cachedEntry {
            case .samples(let samples):
                completion(.success(samples))
            case .unavailable:
                completion(.success([]))
            }
            return
        }

        heartRateDataProvider.fetchHeartRateSamples(for: workout) { result in
            if isCompletedWorkout {
                switch result {
                case .success(let samples):
                    self.setCachedHeartRateEntry(samples.isEmpty ? .unavailable : .samples(samples), for: workout.uuid)
                case .failure:
                    break
                }
            }
            completion(result)
        }
    }

    private func cachedHeartRateEntry(for workoutID: UUID) -> HeartRateCacheEntry? {
        heartRateCacheQueue.sync {
            heartRateCache[workoutID]
        }
    }

    private func setCachedHeartRateEntry(_ entry: HeartRateCacheEntry, for workoutID: UUID) {
        heartRateCacheQueue.sync {
            heartRateCache[workoutID] = entry
        }
    }

    static func applyHeartRateResult(_ result: Result<[HeartRateSample], HeartRateDataError>,
                                     to activity: inout RunningActivity,
                                     workoutID: UUID) {
        switch result {
        case .success(let samples):
            activity.heartRateSamples = samples.isEmpty ? nil : samples
            activity.avgHeartRate = HealthData.averageHeartRate(from: samples)
            activity.maxHeartRate = samples.map(\.bpm).max()
        case .failure(let error):
            if case .queryFailed(let underlyingError) = error {
                print("Unable to load heart rate samples for workout \(workoutID): \(underlyingError.localizedDescription)")
            }
            activity.heartRateSamples = nil
            activity.avgHeartRate = nil
            activity.maxHeartRate = nil
        }
    }

    @available(iOS 16.0, *)
    private func processMetricSamples(
        _ samples: [HKQuantitySample],
        for identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        into activity: inout RunningActivity,
        totalSteps: inout Double?
    ) {
        let values = samples.map { $0.quantity.doubleValue(for: unit) }
        guard !values.isEmpty else { return }

        let average = values.reduce(0, +) / Double(values.count)

        switch identifier {
        case .stepCount:
            // Sum steps for cadence calculation
            totalSteps = values.reduce(0, +)

        case .runningSpeed:
            activity.averageSpeed = average

        case .runningPower:
            activity.averagePower = average

        case .runningGroundContactTime:
            activity.groundContactTime = average

        case .runningStrideLength:
            activity.strideLength = average

        case .runningVerticalOscillation:
            activity.verticalOscillation = average

        default:
            break
        }
    }
}

// MARK: - Helper Function

/// Returns the start date of last week (7 days ago at midnight)
private func getLastWeekStartDate() -> Date {
    let calendar = Calendar.current
    let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
    return calendar.startOfDay(for: sevenDaysAgo)
}
