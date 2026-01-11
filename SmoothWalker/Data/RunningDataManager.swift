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
import CoreLocation

@available(iOS 16.0, *)
class RunningDataManager {
    
    private let healthStore = HealthData.healthStore
    
    // MARK: - Fetch Running Activities
    
    /// Fetch only the latest running workout with associated metrics and splits
    func fetchRunningActivities(completion: @escaping ([RunningActivity]) -> Void) {
        fetchLatestRunningWorkout { [weak self] workout in
            guard let self = self, let workout = workout else {
                completion([])
                return
            }

            self.fetchMetricsForSingleWorkout(workout) { activity in
                completion(activity.map { [$0] } ?? [])
            }
        }
    }

    /// Fetch only the latest running workout with metrics and splits
    func fetchLatestRunningActivity(completion: @escaping (RunningActivity?) -> Void) {
        fetchLatestRunningWorkout { [weak self] workout in
            guard let self = self, let workout = workout else {
                completion(nil)
                return
            }
            self.fetchMetricsForSingleWorkout(workout, completion: completion)
        }
    }

    /// Fetch only the latest running workout as a story (activity + route)
    func fetchLatestRunningStory(completion: @escaping (RunningStory?) -> Void) {
        fetchLatestRunningWorkout { [weak self] workout in
            guard let self = self, let workout = workout else {
                completion(nil)
                return
            }
            self.fetchRunningStory(for: workout, completion: completion)
        }
    }

    /// Fetch only the latest running story (activity + route)
    func fetchRunningStories(completion: @escaping ([RunningStory]) -> Void) {
        fetchLatestRunningStory { story in
            completion(story.map { [$0] } ?? [])
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

    private func fetchLatestRunningWorkout(completion: @escaping (HKWorkout?) -> Void) {
        let workoutType = HKWorkoutType.workoutType()
        let predicate = HKQuery.predicateForWorkouts(with: .running)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        let query = HKSampleQuery(sampleType: workoutType,
                                  predicate: predicate,
                                  limit: 1,
                                  sortDescriptors: [sortDescriptor]) { _, samples, error in
            guard let workouts = samples as? [HKWorkout], error == nil else {
                completion(nil)
                return
            }
            completion(workouts.first)
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
        
        let totalDistanceMeters = workout.totalDistance?.doubleValue(for: .meter())
        let initialAverageSpeed = (totalDistanceMeters != nil && workout.duration > 0)
            ? (totalDistanceMeters! / workout.duration)
            : nil
        
        var activity = RunningActivity(
            workoutIdentifier: workout.uuid,
            startDate: workout.startDate,
            endDate: workout.endDate,
            duration: workout.duration,
            distance: totalDistanceMeters,
            averageSpeed: initialAverageSpeed
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

    /// Build a rich story payload (activity + route)
    func fetchRunningStory(for workout: HKWorkout, completion: @escaping (RunningStory?) -> Void) {
        fetchMetricsForSingleWorkout(workout) { [weak self] activity in
            guard let self = self, let activity = activity else {
                completion(nil)
                return
            }
            self.fetchRouteLocations(for: workout) { locations in
                let story = RunningStory(activity: activity, route: locations)
                completion(story)
            }
        }
    }
    
    // MARK: - Splits Fetching
    
    private func fetchSplitsForWorkout(_ workout: HKWorkout, into activity: inout RunningActivity, completion: @escaping (RunningActivity) -> Void) {
        var activityCopy = activity
        
        guard let totalDistance = workout.totalDistance?.doubleValue(for: .meter()) else {
            completion(activityCopy)
            return
        }
        
        // Determine split unit (KM or Mile) based on locale
        // TODO: Make this user-configurable instead of relying on locale
        let usesMiles = false // Locale.current.measurementSystem == .us
        let splitDistanceInMeters = usesMiles ? 1609.34 : 1000.0 // 1 mile or 1 km
        
        // Always calculate splits from distance samples (matches Fitness app behavior)
        self.calculateSplitsFromSamples(
            for: workout,
            totalDistance: totalDistance,
            splitDistanceInMeters: splitDistanceInMeters
        ) { [weak self] splits in
            guard let self = self else { return }
            
            if !splits.isEmpty {
                activityCopy.splits = splits
                completion(activityCopy)
                return
            }
            
            // Fallback to Route
            self.fetchRouteLocations(for: workout) { locations in
                if locations.count > 1 {
                    self.calculateSplitsFromRoute(
                        locations,
                        workout: workout,
                        splitDistanceInMeters: splitDistanceInMeters
                    ) { splits in
                        activityCopy.splits = splits
                        completion(activityCopy)
                    }
                    return
                }
                
                // Fallback to Even Pace
                let numberOfSplits = Int(totalDistance / splitDistanceInMeters)
                if numberOfSplits > 0 {
                    self.calculateSplitsWithEvenPace(
                        workout: workout,
                        numberOfSplits: numberOfSplits,
                        splitDistanceInMeters: splitDistanceInMeters
                    ) { splits in
                        activityCopy.splits = splits
                        completion(activityCopy)
                    }
                } else {
                    completion(activityCopy)
                }
            }
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
            fetchMetricsForTimeRange(start: startDate, end: endDate, workout: workout) { heartRate, power, cadence, speed in
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
    
    private func fetchRouteLocations(for workout: HKWorkout, completion: @escaping ([CLLocation]) -> Void) {
        // HKSeriesType.workoutRoute() is the canonical way to access workout routes
        let routeType = HKSeriesType.workoutRoute()
        
        let predicate = HKQuery.predicateForObjects(from: workout)
        
        let routeQuery = HKSampleQuery(
            sampleType: routeType,
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: nil
        ) { [weak self] _, samples, error in
            guard let self = self,
                  let routes = samples as? [HKWorkoutRoute],
                  !routes.isEmpty,
                  error == nil else {
                completion([])
                return
            }
            
            let group = DispatchGroup()
            var allLocations: [CLLocation] = []
            
            for route in routes {
                group.enter()
                let locationsQuery = HKWorkoutRouteQuery(route: route) { _, locationBatch, done, _ in
                    if let batch = locationBatch {
                        allLocations.append(contentsOf: batch)
                    }
                    if done {
                        group.leave()
                    }
                }
                self.healthStore.execute(locationsQuery)
            }
            
            group.notify(queue: .main) {
                // Ensure locations are time-ordered
                allLocations.sort { $0.timestamp < $1.timestamp }
                completion(allLocations)
            }
        }
        
        healthStore.execute(routeQuery)
    }
    
    private func calculateSplitsFromRoute(
        _ locations: [CLLocation],
        workout: HKWorkout,
        splitDistanceInMeters: Double,
        completion: @escaping ([RunningSplit]) -> Void
    ) {
        guard locations.count > 1 else {
            completion([])
            return
        }
        
        let pauseIntervals = extractPauseRanges(from: workout).map { DateInterval(start: $0.lowerBound, end: $0.upperBound) }
        var splits: [RunningSplit] = []
        var distanceInCurrentSplit: Double = 0
        let firstTimestamp = locations.first!.timestamp
        var splitStartDate = max(workout.startDate, firstTimestamp)

        var previous = locations.first!
        let maxGap: TimeInterval = 12 // seconds; treat larger gaps as GPS drop and ignore that segment

        for index in 1..<locations.count {
            let current = locations[index]
            let segmentDuration = current.timestamp.timeIntervalSince(previous.timestamp)
            if segmentDuration <= 0 {
                previous = current
                continue
            }
            
            if segmentDuration > maxGap {
                // GPS drop: skip this segment's distance/time to avoid smearing
                previous = current
                continue
            }
            
            let segmentDistance = current.distance(from: previous)
            if segmentDistance <= 0 {
                previous = current
                continue
            }
            
            let effectiveDuration = calculateActiveTime(from: previous.timestamp, to: current.timestamp, excluding: pauseIntervals)
            
            if effectiveDuration == 0 {
                previous = current
                continue
            }
            
            var remainingDistance = segmentDistance
            var segmentStartTime = previous.timestamp
            
            while distanceInCurrentSplit + remainingDistance >= splitDistanceInMeters {
                let distanceNeeded = splitDistanceInMeters - distanceInCurrentSplit
                let ratio = distanceNeeded / remainingDistance
                let timeToBoundary = effectiveDuration * ratio
                let boundaryDate = segmentStartTime.addingTimeInterval(timeToBoundary)
                
                let split = RunningSplit(
                    splitNumber: splits.count + 1,
                    distance: splitDistanceInMeters,
                    startDate: splitStartDate,
                    endDate: boundaryDate
                )
                splits.append(split)
                
                // Prepare for next split within this same segment
                splitStartDate = boundaryDate
                remainingDistance -= distanceNeeded
                segmentStartTime = boundaryDate
                distanceInCurrentSplit = 0
            }
            
            // Carry leftover distance to current split
            distanceInCurrentSplit += remainingDistance
            previous = current
        }

        // Capture a trailing partial split (e.g., last incomplete km)
        if distanceInCurrentSplit > 0 {
            let splitEndDate = min(workout.endDate, previous.timestamp)
            if splitEndDate > splitStartDate {
                let split = RunningSplit(
                    splitNumber: splits.count + 1,
                    distance: distanceInCurrentSplit,
                    startDate: splitStartDate,
                    endDate: splitEndDate
                )
                splits.append(split)
            }
        }
        
        let group = DispatchGroup()
        var splitsWithMetrics: [RunningSplit] = []
        
        for var split in splits {
            group.enter()
            fetchMetricsForTimeRange(start: split.startDate, end: split.endDate, workout: workout) { heartRate, power, cadence, speed in
                split.averageHeartRate = heartRate
                split.averagePower = power
                split.averageCadence = cadence
                split.averageSpeed = speed
                splitsWithMetrics.append(split)
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            completion(splitsWithMetrics.sorted { $0.splitNumber < $1.splitNumber })
        }
    }
    
    private func calculateSplitsFromSamples(
        for workout: HKWorkout,
        totalDistance: Double,
        splitDistanceInMeters: Double,
        completion: @escaping ([RunningSplit]) -> Void
    ) {
        // Determine appropriate distance type based on workout activity
        // Following healthkit-workout-splits best practices
        let distanceType: HKQuantityType
        switch workout.workoutActivityType {
        case .running, .walking, .hiking:
            distanceType = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)!
        case .cycling:
            distanceType = HKQuantityType.quantityType(forIdentifier: .distanceCycling)!
        case .swimming:
            distanceType = HKQuantityType.quantityType(forIdentifier: .distanceSwimming)!
        default:
            // Default to walking/running for other activities
            distanceType = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)!
        }
        
        // Filter to samples from workout's source device to avoid duplicates
        // (e.g., iPhone + Apple Watch recording simultaneously)
        let timePredicate = HKQuery.predicateForSamples(
            withStart: workout.startDate,
            end: workout.endDate,
            options: .strictStartDate
        )
        let sourcePredicate = HKQuery.predicateForObjects(
            from: workout.sourceRevision.source
        )
        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            timePredicate,
            sourcePredicate
        ])
        
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        
        let query = HKSampleQuery(
            sampleType: distanceType,
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: [sortDescriptor]
        ) { [weak self] _, samples, error in
            guard let self = self,
                  let distanceSamples = samples as? [HKQuantitySample],
                  !distanceSamples.isEmpty,
                  error == nil else {
                completion([])
                return
            }
            
            // Calculate split boundaries from distance samples
            self.calculateSplitsFromDistanceSamples(
                distanceSamples,
                workout: workout,
                splitDistanceInMeters: splitDistanceInMeters,
                completion: completion
            )
        }
        
        healthStore.execute(query)
    }
    
    private func calculateSplitsFromDistanceSamples(
        _ samples: [HKQuantitySample],
        workout: HKWorkout,
        splitDistanceInMeters: Double,
        completion: @escaping ([RunningSplit]) -> Void
    ) {
        // Leveraged from https://github.com/jagreenwood/healthkit-workout-splits
        
        guard !samples.isEmpty else {
            completion([])
            return
        }

        let meterUnit = HKUnit.meter()
        // Convert to DateIntervals for easier processing
        let pauseIntervals = extractPauseRanges(from: workout).map { DateInterval(start: $0.lowerBound, end: $0.upperBound) }
        
        // Get total workout distance as a safety limit
        let totalWorkoutDistance = workout.totalDistance?.doubleValue(for: .meter()) ?? Double.greatestFiniteMagnitude
        
        var splits: [RunningSplit] = []
        var cumulativeDistance: Double = 0
        var currentSplitStartDistance: Double = 0
        var currentSplitStartTime: Date = workout.startDate
        var splitNumber = 1
        
        // Filter and sort samples
        let validSamples = samples.sorted(by: { $0.startDate < $1.startDate })
        
        var shouldStopProcessing = false
        
        for sample in validSamples {
            if shouldStopProcessing { break }
            
            let sampleDistanceMeters = sample.quantity.doubleValue(for: meterUnit)
            let sampleStartTime = sample.startDate
            let sampleEndTime = sample.endDate
            let sampleDuration = sampleEndTime.timeIntervalSince(sampleStartTime)
            
            // Skip invalid samples
            if sampleDistanceMeters <= 0 { continue }
            if sampleDuration <= 0 { continue }

            var remainingDistance = sampleDistanceMeters
            var sampleTimeOffset: TimeInterval = 0

            // Process this sample, which may create one or more splits
            while remainingDistance > 0 {
                // Safety check: stop if we've exceeded the workout distance
                if cumulativeDistance >= totalWorkoutDistance {
                    shouldStopProcessing = true
                    break
                }
                
                let distanceToNextSplit = splitDistanceInMeters - (cumulativeDistance - currentSplitStartDistance)
                
                // Check if this sample completes or crosses a split boundary
                if remainingDistance >= distanceToNextSplit {
                    // Sample crosses (or completes) a split boundary

                    // Calculate time portion for this split
                    // Note: We use the ratio of the *distance needed* vs the *total sample distance*
                    // for linear interpolation of time.
                    let timeFraction = distanceToNextSplit / sampleDistanceMeters
                    let timeForSplit = sampleDuration * timeFraction

                    // Calculate end time for this split portion
                    let splitEndTime = sampleStartTime.addingTimeInterval(sampleTimeOffset + timeForSplit)

                    // Calculate active time (excluding pauses)
                    let activeTime = calculateActiveTime(
                        from: currentSplitStartTime,
                        to: splitEndTime,
                        excluding: pauseIntervals
                    )
                    
                    var split = RunningSplit(
                        splitNumber: splitNumber,
                        distance: splitDistanceInMeters,
                        startDate: currentSplitStartTime,
                        endDate: splitEndTime
                    )
                    split.activeDuration = activeTime
                    
                    splits.append(split)

                    // Update tracking variables
                    cumulativeDistance += distanceToNextSplit
                    currentSplitStartDistance = cumulativeDistance
                    currentSplitStartTime = splitEndTime
                    
                    remainingDistance -= distanceToNextSplit
                    sampleTimeOffset += timeForSplit
                    splitNumber += 1

                } else {
                    // Sample doesn't complete the current split
                    cumulativeDistance += remainingDistance
                    remainingDistance = 0
                }
            }
        }
        
        // Create partial split for remaining distance if meaningful (>0.1m threshold)
        if cumulativeDistance > currentSplitStartDistance && !shouldStopProcessing {
            let remainingSplitDistance = cumulativeDistance - currentSplitStartDistance
            
            // Only create partial split if it's meaningful distance
            if remainingSplitDistance > 0.1 {
                let lastSampleEndTime = validSamples.last?.endDate ?? workout.endDate
                
                let activeTime = calculateActiveTime(
                    from: currentSplitStartTime,
                    to: lastSampleEndTime,
                    excluding: pauseIntervals
                )
                
                var split = RunningSplit(
                    splitNumber: splitNumber,
                    distance: remainingSplitDistance,
                    startDate: currentSplitStartTime,
                    endDate: lastSampleEndTime
                )
                split.activeDuration = activeTime
                splits.append(split)
            }
        }
        
        // Fetch metrics for each split
        let group = DispatchGroup()
        var splitsWithMetrics: [RunningSplit] = []
        
        for var split in splits {
            group.enter()
            
            fetchMetricsForTimeRange(
                start: split.startDate,
                end: split.endDate,
                workout: workout
            ) { heartRate, power, cadence, speed in
                split.averageHeartRate = heartRate
                split.averagePower = power
                split.averageCadence = cadence
                split.averageSpeed = speed
                splitsWithMetrics.append(split)
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            completion(splitsWithMetrics.sorted { $0.splitNumber < $1.splitNumber })
        }
    }
    
    private func extractPauseRanges(from workout: HKWorkout) -> [ClosedRange<Date>] {
        guard let events = workout.workoutEvents else { return [] }
        
        var pauseRanges: [ClosedRange<Date>] = []
        var pauseStart: Date?
        
        for event in events {
            switch event.type {
            case .pause:
                pauseStart = event.dateInterval.start
            case .resume:
                if let start = pauseStart {
                    pauseRanges.append(start...event.dateInterval.start)
                    pauseStart = nil
                }
            default:
                break
            }
        }
        
        return pauseRanges
    }
    
    private func calculateActiveTime(
        from startTime: Date,
        to endTime: Date,
        excluding pauseIntervals: [DateInterval]
    ) -> TimeInterval {
        let totalTime = endTime.timeIntervalSince(startTime)
        guard !pauseIntervals.isEmpty else { return totalTime }

        let segmentInterval = DateInterval(start: startTime, end: endTime)
        var pausedTime: TimeInterval = 0

        for pauseInterval in pauseIntervals {
            if let overlap = segmentInterval.intersection(with: pauseInterval) {
                pausedTime += overlap.duration
            }
        }

        return max(0, totalTime - pausedTime)
    }
    
    private func calculateSplitsWithEvenPace(
        workout: HKWorkout,
        numberOfSplits: Int,
        splitDistanceInMeters: Double,
        completion: @escaping ([RunningSplit]) -> Void
    ) {
        // Fallback: Calculate time intervals for each split (assuming even pace)
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
                distance: splitDistanceInMeters,
                startDate: splitStart,
                endDate: splitEnd
            )
            
            fetchMetricsForTimeRange(start: splitStart, end: splitEnd, workout: workout) { heartRate, power, cadence, speed in
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
    
    private func fetchMetricsForTimeRange(start: Date, end: Date, workout: HKWorkout? = nil, completion: @escaping (Double?, Double?, Double?, Double?) -> Void) {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        
        var heartRate: Double?
        var power: Double?
        var cadence: Double?
        var speed: Double?
        var strideLength: Double?
        
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
        
        // Step Count for Cadence - filter by workout source to avoid double-counting
        if let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) {
            group.enter()
            let stepUnit = HKUnit.count()
            let sourceDevice = workout?.sourceRevision.source
            fetchSumForType(stepType, predicate: predicate, unit: stepUnit, sourceDevice: sourceDevice) { totalSteps in
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
        
        // Running Stride Length for alternative cadence calculation
        if #available(iOS 16.0, *) {
            if let strideLengthType = HKQuantityType.quantityType(forIdentifier: .runningStrideLength) {
                group.enter()
                fetchAverageForType(strideLengthType, predicate: predicate, unit: .meter()) { value in
                    strideLength = value
                    group.leave()
                }
            }
        }
        
        group.notify(queue: .main) {
            // If we didn't get cadence from steps, try calculating from speed and stride length
            if cadence == nil, let spd = speed, let stride = strideLength, stride > 0 {
                // Cadence (steps/min) = Speed (m/s) / Stride Length (m) * 60
                cadence = (spd / stride) * 60.0
            }
            
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
    
    private func fetchSumForType(_ type: HKQuantityType, predicate: NSPredicate, unit: HKUnit, sourceDevice: HKSource? = nil, completion: @escaping (Double?) -> Void) {
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
            
            // Filter by source device if provided to avoid double-counting from iPhone + Watch
            let filteredSamples: [HKQuantitySample]
            if let source = sourceDevice {
                filteredSamples = quantitySamples.filter { $0.sourceRevision.source == source }
            } else {
                filteredSamples = quantitySamples
            }
            
            let sum = filteredSamples.reduce(0.0) { $0 + $1.quantity.doubleValue(for: unit) }
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
            // Preserve distance/duration-derived speed if already set
            if activity.averageSpeed == nil {
                activity.averageSpeed = average
            }
            
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
