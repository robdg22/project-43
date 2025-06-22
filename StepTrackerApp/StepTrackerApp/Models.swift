import Foundation
import MapKit
import CoreLocation

struct WalkGoal {
    enum GoalType: CaseIterable {
        case steps
        case distance
        case time
        
        var displayName: String {
            switch self {
            case .steps: return "Steps"
            case .distance: return "Distance"
            case .time: return "Time"
            }
        }
        
        var unit: String {
            switch self {
            case .steps: return "steps"
            case .distance: return "km"
            case .time: return "minutes"
            }
        }
    }
    
    let type: GoalType
    let value: Double
    
    var displayText: String {
        switch type {
        case .steps:
            return "\(Int(value)) \(type.unit)"
        case .distance:
            return String(format: "%.1f %@", value, type.unit)
        case .time:
            return "\(Int(value)) \(type.unit)"
        }
    }
}

struct RoutePoint {
    let coordinate: CLLocationCoordinate2D
    let instruction: String?
    
    init(coordinate: CLLocationCoordinate2D, instruction: String? = nil) {
        self.coordinate = coordinate
        self.instruction = instruction
    }
}

struct WalkRoute: Identifiable {
    let id = UUID()
    let name: String
    let points: [RoutePoint]
    let estimatedDistance: Double
    let estimatedSteps: Int
    let estimatedDuration: TimeInterval
    let difficulty: Difficulty
    let terrain: TerrainType
    
    enum Difficulty: String, CaseIterable {
        case easy = "Easy"
        case moderate = "Moderate"
        case challenging = "Challenging"
        
        var color: String {
            switch self {
            case .easy: return "green"
            case .moderate: return "orange"
            case .challenging: return "red"
            }
        }
    }
    
    enum TerrainType: String, CaseIterable {
        case urban = "Urban"
        case park = "Park"
        case mixed = "Mixed"
        
        var icon: String {
            switch self {
            case .urban: return "building.2"
            case .park: return "tree"
            case .mixed: return "map"
            }
        }
    }
    
    var polyline: MKPolyline {
        let coordinates = points.map { $0.coordinate }
        return MKPolyline(coordinates: coordinates, count: coordinates.count)
    }
    
    var estimatedDistanceText: String {
        return String(format: "%.1f km", estimatedDistance / 1000)
    }
    
    var estimatedDurationText: String {
        let minutes = Int(estimatedDuration / 60)
        return "\(minutes) min"
    }
}

struct WalkSession: Identifiable {
    let id = UUID()
    let startTime: Date
    var endTime: Date?
    let route: WalkRoute
    let goal: WalkGoal
    
    var currentSteps: Int = 0
    var currentDistance: Double = 0.0
    var currentDuration: TimeInterval = 0.0
    var isActive: Bool = false
    var locations: [CLLocation] = []
    
    var progress: Double {
        switch goal.type {
        case .steps:
            return min(Double(currentSteps) / goal.value, 1.0)
        case .distance:
            return min(currentDistance / (goal.value * 1000), 1.0)
        case .time:
            return min(currentDuration / (goal.value * 60), 1.0)
        }
    }
    
    var isGoalAchieved: Bool {
        progress >= 1.0
    }
    
    var actualDuration: TimeInterval {
        if let endTime = endTime {
            return endTime.timeIntervalSince(startTime)
        }
        return Date().timeIntervalSince(startTime)
    }
    
    mutating func updateProgress(steps: Int, distance: Double) {
        self.currentSteps = steps
        self.currentDistance = distance
        self.currentDuration = actualDuration
    }
    
    mutating func addLocation(_ location: CLLocation) {
        locations.append(location)
    }
    
    mutating func complete() {
        isActive = false
        endTime = Date()
    }
}

struct HealthMetrics {
    let steps: Int
    let distance: Double
    let averageSpeed: Double
    let date: Date
    
    var distanceInKm: String {
        return String(format: "%.2f km", distance / 1000)
    }
    
    var speedInKmh: String {
        return String(format: "%.1f km/h", averageSpeed * 3.6)
    }
}

struct GaitAnalysis {
    let averageStepLength: Double
    let cadence: Double
    let consistency: Double
    let symmetry: Double
    
    var stepLengthText: String {
        return String(format: "%.0f cm", averageStepLength * 100)
    }
    
    var cadenceText: String {
        return String(format: "%.0f steps/min", cadence)
    }
    
    var consistencyText: String {
        return String(format: "%.0f%%", consistency * 100)
    }
    
    var symmetryText: String {
        return String(format: "%.0f%%", symmetry * 100)
    }
}