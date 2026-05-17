/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
A collection of HealthKit properties, functions, and utilities.
*/

import Foundation
import HealthKit

class HealthData {
    
    static let healthStore: HKHealthStore = HKHealthStore()
    
    // MARK: - Data Types
    
    static var readDataTypes: [HKSampleType] {
        return allHealthDataTypes
    }
    
    static var shareDataTypes: [HKSampleType] {
        return allHealthDataTypes
    }
    
//    private static var allHealthDataTypes: [HKSampleType] {
//        let typeIdentifiers: [String] = [
//            HKQuantityTypeIdentifier.stepCount.rawValue,
//            HKQuantityTypeIdentifier.distanceWalkingRunning.rawValue,
//            HKQuantityTypeIdentifier.sixMinuteWalkTestDistance.rawValue
//        ]
//        
//        return typeIdentifiers.compactMap { getSampleType(for: $0) }
//    }
    
    // Add this section after the existing allHealthDataTypes property

    // MARK: - Running Data Types

    static var runningDataTypes: [HKSampleType] {
        var runningTypeIdentifiers: [String] = [
            // Always available
            HKQuantityTypeIdentifier.distanceWalkingRunning.rawValue,
            HKQuantityTypeIdentifier.heartRate.rawValue,
            HKQuantityTypeIdentifier.stepCount.rawValue
        ]
        
        // iOS 16.0+ running metrics
        if #available(iOS 16.0, *) {
            runningTypeIdentifiers.append(contentsOf: [
                HKQuantityTypeIdentifier.runningSpeed.rawValue,
                HKQuantityTypeIdentifier.runningPower.rawValue,
                HKQuantityTypeIdentifier.runningGroundContactTime.rawValue,
                HKQuantityTypeIdentifier.runningStrideLength.rawValue,
                HKQuantityTypeIdentifier.runningVerticalOscillation.rawValue
            ])
        }
        
        return runningTypeIdentifiers.compactMap { getSampleType(for: $0) }
    }

    static var workoutDataTypes: [HKSampleType] {
        return [HKWorkoutType.workoutType()]
    }

    // Update the existing allHealthDataTypes to include running data
    private static var allHealthDataTypes: [HKSampleType] {
        let mobilityTypeIdentifiers: [String] = [
            HKQuantityTypeIdentifier.stepCount.rawValue,
            HKQuantityTypeIdentifier.distanceWalkingRunning.rawValue,
            HKQuantityTypeIdentifier.sixMinuteWalkTestDistance.rawValue
        ]
        
        let mobilityTypes = mobilityTypeIdentifiers.compactMap { getSampleType(for: $0) }
        
        return mobilityTypes + runningDataTypes + workoutDataTypes
    }

    // MARK: - Running-Specific Authorization

    /// Request authorization specifically for running data types
    class func requestRunningDataAccess(completion: @escaping (_ success: Bool) -> Void) {
        let readTypes = Set(runningDataTypes + workoutDataTypes)
        let shareTypes = Set(runningDataTypes + workoutDataTypes)
        
        requestHealthDataAccessIfNeeded(toShare: shareTypes, read: readTypes, completion: completion)
    }

    // MARK: - iOS Version Compatibility Helpers

    /// Check if advanced running metrics are available on this iOS version
    class func isAdvancedRunningMetricsAvailable() -> Bool {
        if #available(iOS 16.0, *) {
            return true
        }
        return false
    }

    /// Get available running data type identifiers for current iOS version
    class func getAvailableRunningDataTypes() -> [String] {
        var types = [
            HKQuantityTypeIdentifier.distanceWalkingRunning.rawValue,
            HKQuantityTypeIdentifier.heartRate.rawValue,
            HKQuantityTypeIdentifier.stepCount.rawValue
        ]
        
        if #available(iOS 16.0, *) {
            types.append(contentsOf: [
                HKQuantityTypeIdentifier.runningSpeed.rawValue,
                HKQuantityTypeIdentifier.runningPower.rawValue,
                HKQuantityTypeIdentifier.runningGroundContactTime.rawValue,
                HKQuantityTypeIdentifier.runningStrideLength.rawValue,
                HKQuantityTypeIdentifier.runningVerticalOscillation.rawValue
            ])
        }
        
        return types
    }
    
    // MARK: - Authorization
    
    /// Request health data from HealthKit if needed, using the data types within `HealthData.allHealthDataTypes`
    class func requestHealthDataAccessIfNeeded(dataTypes: [String]? = nil, completion: @escaping (_ success: Bool) -> Void) {
        var readDataTypes = Set(allHealthDataTypes)
        var shareDataTypes = Set(allHealthDataTypes)
        
        if let dataTypeIdentifiers = dataTypes {
            readDataTypes = Set(dataTypeIdentifiers.compactMap { getSampleType(for: $0) })
            shareDataTypes = readDataTypes
        }
        
        requestHealthDataAccessIfNeeded(toShare: shareDataTypes, read: readDataTypes, completion: completion)
    }
    
    /// Request health data from HealthKit if needed.
    class func requestHealthDataAccessIfNeeded(toShare shareTypes: Set<HKSampleType>?,
                                               read readTypes: Set<HKObjectType>?,
                                               completion: @escaping (_ success: Bool) -> Void) {
        if !HKHealthStore.isHealthDataAvailable() {
            fatalError("Health data is not available!")
        }
        
        print("Requesting HealthKit authorization...")
        healthStore.requestAuthorization(toShare: shareTypes, read: readTypes) { (success, error) in
            if let error = error {
                print("requestAuthorization error:", error.localizedDescription)
            }
            
            if success {
                print("HealthKit authorization request was successful!")
            } else {
                print("HealthKit authorization was not successful.")
            }
            
            completion(success)
        }
    }
    
    // MARK: - HKHealthStore
    
    class func saveHealthData(_ data: [HKObject], completion: @escaping (_ success: Bool, _ error: Error?) -> Void) {
        healthStore.save(data, withCompletion: completion)
    }
    
    // MARK: - HKStatisticsCollectionQuery
    
    class func fetchStatistics(with identifier: HKQuantityTypeIdentifier,
                               predicate: NSPredicate? = nil,
                               options: HKStatisticsOptions,
                               startDate: Date,
                               endDate: Date = Date(),
                               interval: DateComponents,
                               completion: @escaping (HKStatisticsCollection) -> Void) {
        guard let quantityType = HKObjectType.quantityType(forIdentifier: identifier) else {
            fatalError("*** Unable to create a step count type ***")
        }
        
        let anchorDate = createAnchorDate()
        
        // Create the query
        let query = HKStatisticsCollectionQuery(quantityType: quantityType,
                                                quantitySamplePredicate: predicate,
                                                options: options,
                                                anchorDate: anchorDate,
                                                intervalComponents: interval)
        
        // Set the results handler
        query.initialResultsHandler = { query, results, error in
            if let statsCollection = results {
                completion(statsCollection)
            }
        }
         
        healthStore.execute(query)
    }
    
    // MARK: - Helper Functions
    
    class func updateAnchor(_ newAnchor: HKQueryAnchor?, from query: HKAnchoredObjectQuery) {
        if let sampleType = query.objectType as? HKSampleType {
            setAnchor(newAnchor, for: sampleType)
        } else {
            if let identifier = query.objectType?.identifier {
                print("anchoredObjectQueryDidUpdate error: Did not save anchor for \(identifier) – Not an HKSampleType.")
            } else {
                print("anchoredObjectQueryDidUpdate error: query doesn't not have non-nil objectType.")
            }
        }
    }
    
    private static let userDefaults = UserDefaults.standard
    
    private static let anchorKeyPrefix = "Anchor_"
    
    private class func anchorKey(for type: HKSampleType) -> String {
        return anchorKeyPrefix + type.identifier
    }
    
    /// Returns the saved anchor used in a long-running anchored object query for a particular sample type.
    /// Returns nil if a query has never been run.
    class func getAnchor(for type: HKSampleType) -> HKQueryAnchor? {
        if let anchorData = userDefaults.object(forKey: anchorKey(for: type)) as? Data {
            return try? NSKeyedUnarchiver.unarchivedObject(ofClass: HKQueryAnchor.self, from: anchorData)
        }
        
        return nil
    }
    
    /// Update the saved anchor used in a long-running anchored object query for a particular sample type.
    private class func setAnchor(_ queryAnchor: HKQueryAnchor?, for type: HKSampleType) {
        if let queryAnchor = queryAnchor,
            let data = try? NSKeyedArchiver.archivedData(withRootObject: queryAnchor, requiringSecureCoding: true) {
            userDefaults.set(data, forKey: anchorKey(for: type))
        }
    }
}
