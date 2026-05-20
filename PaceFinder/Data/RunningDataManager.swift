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
        guard !workouts.isEmpty else { completion([]); return }

        // Batch strategy: fire one HKSampleQuery per metric type across the full date span,
        // then attribute each sample to the workout whose time range contains it.
        // This reduces O(workouts × metrics) HealthKit IPC calls to O(metrics).
        let overallStart = workouts.map(\.startDate).min()!
        let overallEnd   = workouts.map(\.endDate).max()!
        let datePredicate = HKQuery.predicateForSamples(
            withStart: overallStart,
            end: overallEnd,
            options: .strictStartDate
        )

        let allMetrics: [(HKQuantityTypeIdentifier, HKUnit)] = [
            (.heartRate,                  .count().unitDivided(by: .minute())),
            (.stepCount,                  .count()),
            (.runningSpeed,               .meter().unitDivided(by: .second())),
            (.runningPower,               .watt()),
            (.runningGroundContactTime,   .secondUnit(with: .milli)),
            (.runningStrideLength,        .meter()),
            (.runningVerticalOscillation, .meter())
        ]
        let unitByIdentifier = Dictionary(uniqueKeysWithValues: allMetrics)

        let group = DispatchGroup()
        let lock  = NSLock()
        var samplesByMetric: [HKQuantityTypeIdentifier: [HKQuantitySample]] = [:]

        for (identifier, _) in allMetrics {
            guard let qType = HKQuantityType.quantityType(forIdentifier: identifier) else { continue }
            group.enter()
            let query = HKSampleQuery(
                sampleType: qType,
                predicate: datePredicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, error in
                defer { group.leave() }
                guard let qs = samples as? [HKQuantitySample], error == nil else { return }
                lock.lock()
                samplesByMetric[identifier] = qs
                lock.unlock()
            }
            healthStore.execute(query)
        }

        // Sort workouts once for O(n) sample attribution
        let sortedWorkouts = workouts.sorted { $0.startDate < $1.startDate }

        group.notify(queue: .global(qos: .userInitiated)) {
            // Accumulate values per workout UUID
            var hrValues:     [UUID: [Double]] = [:]
            var speedValues:  [UUID: [Double]] = [:]
            var powerValues:  [UUID: [Double]] = [:]
            var gctValues:    [UUID: [Double]] = [:]
            var strideValues: [UUID: [Double]] = [:]
            var voValues:     [UUID: [Double]] = [:]
            var stepTotals:   [UUID: Double]   = [:]

            for (identifier, samples) in samplesByMetric {
                guard let unit = unitByIdentifier[identifier] else { continue }
                for sample in samples {
                    guard let workout = sortedWorkouts.first(where: {
                        sample.startDate >= $0.startDate && sample.startDate < $0.endDate
                    }) else { continue }
                    let uuid  = workout.uuid
                    let value = sample.quantity.doubleValue(for: unit)
                    switch identifier {
                    case .heartRate:                  hrValues[uuid, default: []].append(value)
                    case .stepCount:                  stepTotals[uuid, default: 0] += value
                    case .runningSpeed:               speedValues[uuid, default: []].append(value)
                    case .runningPower:               powerValues[uuid, default: []].append(value)
                    case .runningGroundContactTime:   gctValues[uuid, default: []].append(value)
                    case .runningStrideLength:        strideValues[uuid, default: []].append(value)
                    case .runningVerticalOscillation: voValues[uuid, default: []].append(value)
                    default: break
                    }
                }
            }

            let activities: [RunningActivity] = workouts.map { workout in
                let uuid = workout.uuid
                var a = RunningActivity(
                    workoutIdentifier: uuid,
                    startDate: workout.startDate,
                    endDate: workout.endDate,
                    duration: workout.duration,
                    distance: workout.totalDistance?.doubleValue(for: .meter())
                )
                if let hrs = hrValues[uuid], !hrs.isEmpty {
                    a.averageHeartRate = hrs.reduce(0, +) / Double(hrs.count)
                    a.maxHeartRate = hrs.max()
                }
                if let vs = speedValues[uuid], !vs.isEmpty {
                    a.averageSpeed = vs.reduce(0, +) / Double(vs.count)
                }
                if let ps = powerValues[uuid], !ps.isEmpty {
                    a.averagePower = ps.reduce(0, +) / Double(ps.count)
                }
                if let gs = gctValues[uuid], !gs.isEmpty {
                    a.groundContactTime = gs.reduce(0, +) / Double(gs.count)
                }
                if let ss = strideValues[uuid], !ss.isEmpty {
                    a.strideLength = ss.reduce(0, +) / Double(ss.count)
                }
                if let vs = voValues[uuid], !vs.isEmpty {
                    a.verticalOscillation = vs.reduce(0, +) / Double(vs.count)
                }
                let steps = stepTotals[uuid] ?? 0
                if steps > 0, a.duration > 0 {
                    a.estimatedCadence = (steps / a.duration) * 60.0
                    a.cadenceNote = "Estimated from step count and duration."
                } else {
                    a.cadenceNote = "Not enough step-count data to calculate cadence."
                }
                return a
            }

            DispatchQueue.main.async {
                completion(activities.sorted { $0.startDate > $1.startDate })
            }
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
