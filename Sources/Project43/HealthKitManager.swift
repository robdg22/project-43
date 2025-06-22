import HealthKit
import Foundation

@MainActor
class HealthKitManager: ObservableObject {
    private let healthStore = HKHealthStore()
    @Published var isAuthorized = false
    @Published var stepCount: Int = 0
    @Published var distance: Double = 0.0
    @Published var walkingSpeed: Double = 0.0
    
    private let stepCountType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
    private let distanceType = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)!
    private let walkingSpeedType = HKQuantityType.quantityType(forIdentifier: .walkingSpeed)!
    
    init() {
        checkAuthorizationStatus()
    }
    
    func requestAuthorization() async {
        guard HKHealthStore.isHealthDataAvailable() else {
            print("HealthKit is not available on this device")
            return
        }
        
        let typesToRead: Set<HKObjectType> = [
            stepCountType,
            distanceType,
            walkingSpeedType
        ]
        
        do {
            try await healthStore.requestAuthorization(toShare: [], read: typesToRead)
            await checkAuthorizationStatus()
        } catch {
            print("HealthKit authorization failed: \(error)")
        }
    }
    
    private func checkAuthorizationStatus() {
        let stepStatus = healthStore.authorizationStatus(for: stepCountType)
        let distanceStatus = healthStore.authorizationStatus(for: distanceType)
        let speedStatus = healthStore.authorizationStatus(for: walkingSpeedType)
        
        isAuthorized = stepStatus == .sharingAuthorized && 
                      distanceStatus == .sharingAuthorized && 
                      speedStatus == .sharingAuthorized
    }
    
    func fetchTodaySteps() async {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: Date(), options: .strictStartDate)
        
        let query = HKStatisticsQuery(quantityType: stepCountType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in
            guard let result = result, let sum = result.sumQuantity() else {
                print("Failed to fetch step count: \(error?.localizedDescription ?? "Unknown error")")
                return
            }
            
            DispatchQueue.main.async {
                self.stepCount = Int(sum.doubleValue(for: HKUnit.count()))
            }
        }
        
        healthStore.execute(query)
    }
    
    func fetchTodayDistance() async {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: Date(), options: .strictStartDate)
        
        let query = HKStatisticsQuery(quantityType: distanceType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in
            guard let result = result, let sum = result.sumQuantity() else {
                print("Failed to fetch distance: \(error?.localizedDescription ?? "Unknown error")")
                return
            }
            
            DispatchQueue.main.async {
                self.distance = sum.doubleValue(for: HKUnit.meter())
            }
        }
        
        healthStore.execute(query)
    }
    
    func fetchAverageWalkingSpeed() async {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: Date(), options: .strictStartDate)
        
        let query = HKStatisticsQuery(quantityType: walkingSpeedType, quantitySamplePredicate: predicate, options: .discreteAverage) { _, result, error in
            guard let result = result, let average = result.averageQuantity() else {
                print("Failed to fetch walking speed: \(error?.localizedDescription ?? "Unknown error")")
                return
            }
            
            DispatchQueue.main.async {
                self.walkingSpeed = average.doubleValue(for: HKUnit.meter().unitDivided(by: .second()))
            }
        }
        
        healthStore.execute(query)
    }
    
    func fetchHealthData() async {
        guard isAuthorized else { return }
        
        await fetchTodaySteps()
        await fetchTodayDistance()
        await fetchAverageWalkingSpeed()
    }
    
    func startLiveStepTracking() {
        let query = HKObserverQuery(sampleType: stepCountType, predicate: nil) { _, _, error in
            if let error = error {
                print("Observer query failed: \(error)")
                return
            }
            
            Task {
                await self.fetchTodaySteps()
            }
        }
        
        healthStore.execute(query)
    }
}