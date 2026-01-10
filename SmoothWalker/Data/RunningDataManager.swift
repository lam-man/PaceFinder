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
//            activity.averageHeartRate = heartRates.reduce(0, +) / Double(heartRates.count)
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
    
    private let healthStore = HealthData.healthStore
    
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
        
        for workout in workouts {
            group.enter()
            
            fetchMetricsForSingleWorkout(workout) { activity in
                if let activity = activity {
                    runningActivities.append(activity)
                }
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            // Sort by start date (most recent first)
            let sortedActivities = runningActivities.sorted { $0.startDate > $1.startDate }
            completion(sortedActivities)
        }
    }
    
    private func fetchMetricsForSingleWorkout(_ workout: HKWorkout, completion: @escaping (RunningActivity?) -> Void) {
        // FIXED: Use predicate for samples during workout time range
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
        
        // Track step count for cadence calculation
        var totalSteps: Double?
        
        // Define all metric types to query
        let metricsToQuery: [(HKQuantityTypeIdentifier, HKUnit)] = [
            (.heartRate, HKUnit.count().unitDivided(by: .minute())),
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
                
                // Process the samples
                self.processMetricSamples(
                    quantitySamples,
                    for: identifier,
                    unit: unit,
                    into: &activity,
                    totalSteps: &totalSteps
                )
            }
            
            healthStore.execute(query)
        }
        
        group.notify(queue: .main) {
            // Calculate cadence if we have steps and duration
            if let steps = totalSteps, activity.duration > 0 {
                // Cadence = steps per minute
                activity.cadence = (steps / activity.duration) * 60.0
            }
            
            // Fetch splits data
            self.fetchSplitsForWorkout(workout, into: &activity) { activityWithSplits in
                completion(activityWithSplits)
            }
        }
    }
    
    // MARK: - Splits Fetching
    
    private func fetchSplitsForWorkout(_ workout: HKWorkout, into activity: inout RunningActivity, completion: @escaping (RunningActivity) -> Void) {
        var activityCopy = activity
        
        // Try to get segment events from the workout
        if let events = workout.workoutEvents {
            let segmentEvents = events.filter { $0.type == .segment }
            
            if !segmentEvents.isEmpty {
                // We have segment markers - use them
                fetchMetricsForSegments(segmentEvents, workout: workout) { splits in
                    activityCopy.splits = splits
                    completion(activityCopy)
                }
                return
            }
        }
        
        // No segment events - calculate splits based on distance
        // Use total distance to determine number of splits
        guard let totalDistance = workout.totalDistance?.doubleValue(for: .meter()),
              totalDistance >= 1000 else {
            completion(activityCopy)
            return
        }
        
        calculateSplitsFromSamples(for: workout, totalDistance: totalDistance) { splits in
            activityCopy.splits = splits
            completion(activityCopy)
        }
    }
    
    private func fetchMetricsForSegments(_ segments: [HKWorkoutEvent], workout: HKWorkout, completion: @escaping ([RunningSplit]) -> Void) {
        var splits: [RunningSplit] = []
        let group = DispatchGroup()
        
        for (index, event) in segments.enumerated() {
            group.enter()
            
            let startDate = event.dateInterval.start
            let endDate = event.dateInterval.end
            
            var split = RunningSplit(
                splitNumber: index + 1,
                distance: 1000.0, // Assume 1km per segment
                startDate: startDate,
                endDate: endDate
            )
            
            // Fetch metrics for this segment's time range
            fetchMetricsForTimeRange(start: startDate, end: endDate) { heartRate, power, cadence, speed in
                split.averageHeartRate = heartRate
                split.averagePower = power
                split.averageCadence = cadence
                split.averageSpeed = speed
                splits.append(split)
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            completion(splits.sorted { $0.splitNumber < $1.splitNumber })
        }
    }
    
    private func calculateSplitsFromSamples(for workout: HKWorkout, totalDistance: Double, completion: @escaping ([RunningSplit]) -> Void) {
        let numberOfSplits = Int(totalDistance / 1000.0)
        guard numberOfSplits > 0 else {
            completion([])
            return
        }
        
        // Calculate time intervals for each split (assuming even pace)
        let totalDuration = workout.duration
        let durationPerSplit = totalDuration / Double(numberOfSplits)
        
        var splits: [RunningSplit] = []
        let group = DispatchGroup()
        
        for i in 0..<numberOfSplits {
            group.enter()
            
            let splitStart = workout.startDate.addingTimeInterval(durationPerSplit * Double(i))
            let splitEnd = workout.startDate.addingTimeInterval(durationPerSplit * Double(i + 1))
            
            var split = RunningSplit(
                splitNumber: i + 1,
                distance: 1000.0,
                startDate: splitStart,
                endDate: splitEnd
            )
            
            fetchMetricsForTimeRange(start: splitStart, end: splitEnd) { heartRate, power, cadence, speed in
                split.averageHeartRate = heartRate
                split.averagePower = power
                split.averageCadence = cadence
                split.averageSpeed = speed
                splits.append(split)
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            completion(splits.sorted { $0.splitNumber < $1.splitNumber })
        }
    }
    
    private func fetchMetricsForTimeRange(start: Date, end: Date, completion: @escaping (Double?, Double?, Double?, Double?) -> Void) {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        
        var heartRate: Double?
        var power: Double?
        var cadence: Double?
        var speed: Double?
        
        let group = DispatchGroup()
        
        // Heart Rate
        if let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate) {
            group.enter()
            let hrUnit = HKUnit.count().unitDivided(by: .minute())
            fetchAverageForType(hrType, predicate: predicate, unit: hrUnit) { value in
                heartRate = value
                group.leave()
            }
        }
        
        // Running Power (iOS 16+)
        if let powerType = HKQuantityType.quantityType(forIdentifier: .runningPower) {
            group.enter()
            fetchAverageForType(powerType, predicate: predicate, unit: .watt()) { value in
                power = value
                group.leave()
            }
        }
        
        // Step Count for Cadence
        if let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) {
            group.enter()
            let stepUnit = HKUnit.count()
            fetchSumForType(stepType, predicate: predicate, unit: stepUnit) { totalSteps in
                if let steps = totalSteps {
                    let duration = end.timeIntervalSince(start)
                    if duration > 0 {
                        cadence = (steps / duration) * 60.0
                    }
                }
                group.leave()
            }
        }
        
        // Running Speed (iOS 16+)
        if let speedType = HKQuantityType.quantityType(forIdentifier: .runningSpeed) {
            group.enter()
            let speedUnit = HKUnit.meter().unitDivided(by: .second())
            fetchAverageForType(speedType, predicate: predicate, unit: speedUnit) { value in
                speed = value
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            completion(heartRate, power, cadence, speed)
        }
    }
    
    private func fetchAverageForType(_ type: HKQuantityType, predicate: NSPredicate, unit: HKUnit, completion: @escaping (Double?) -> Void) {
        let query = HKSampleQuery(
            sampleType: type,
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: nil
        ) { _, samples, error in
            guard let quantitySamples = samples as? [HKQuantitySample],
                  !quantitySamples.isEmpty,
                  error == nil else {
                completion(nil)
                return
            }
            
            let values = quantitySamples.map { $0.quantity.doubleValue(for: unit) }
            let average = values.reduce(0, +) / Double(values.count)
            completion(average)
        }
        
        healthStore.execute(query)
    }
    
    private func fetchSumForType(_ type: HKQuantityType, predicate: NSPredicate, unit: HKUnit, completion: @escaping (Double?) -> Void) {
        let query = HKSampleQuery(
            sampleType: type,
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: nil
        ) { _, samples, error in
            guard let quantitySamples = samples as? [HKQuantitySample],
                  !quantitySamples.isEmpty,
                  error == nil else {
                completion(nil)
                return
            }
            
            let sum = quantitySamples.reduce(0.0) { $0 + $1.quantity.doubleValue(for: unit) }
            completion(sum)
        }
        
        healthStore.execute(query)
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
        case .heartRate:
            activity.averageHeartRate = average
            activity.maxHeartRate = values.max()
            
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
