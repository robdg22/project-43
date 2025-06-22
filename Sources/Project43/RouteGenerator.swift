import MapKit
import CoreLocation

@MainActor
class RouteGenerator: ObservableObject {
    private let locationManager = CLLocationManager()
    
    func generateRoutes(from startLocation: CLLocationCoordinate2D, for goal: WalkGoal) async -> [WalkRoute] {
        let targetDistance = calculateTargetDistance(for: goal)
        
        var routes: [WalkRoute] = []
        
        routes.append(generateCircularRoute(
            center: startLocation,
            radius: targetDistance / (2 * .pi),
            name: "Perfect Circle",
            difficulty: .easy,
            terrain: .urban
        ))
        
        routes.append(generateSquareRoute(
            center: startLocation,
            sideLength: targetDistance / 4,
            name: "City Block Loop",
            difficulty: .easy,
            terrain: .urban
        ))
        
        routes.append(generateFigureEightRoute(
            center: startLocation,
            radius: targetDistance / (4 * .pi),
            name: "Figure Eight",
            difficulty: .moderate,
            terrain: .mixed
        ))
        
        routes.append(generateMeanderingRoute(
            center: startLocation,
            targetDistance: targetDistance,
            name: "Scenic Meander",
            difficulty: .moderate,
            terrain: .park
        ))
        
        return routes
    }
    
    private func calculateTargetDistance(for goal: WalkGoal) -> Double {
        switch goal.type {
        case .steps:
            return goal.value * 0.8
        case .distance:
            return goal.value * 1000
        case .time:
            let walkingSpeed = 1.4
            return goal.value * 60 * walkingSpeed
        }
    }
    
    private func generateCircularRoute(
        center: CLLocationCoordinate2D,
        radius: Double,
        name: String,
        difficulty: WalkRoute.Difficulty,
        terrain: WalkRoute.TerrainType
    ) -> WalkRoute {
        var points: [RoutePoint] = []
        let numberOfPoints = 20
        
        for i in 0..<numberOfPoints {
            let angle = Double(i) * 2.0 * .pi / Double(numberOfPoints)
            let lat = center.latitude + (radius / 111000.0) * cos(angle)
            let lon = center.longitude + (radius / (111000.0 * cos(center.latitude * .pi / 180.0))) * sin(angle)
            
            let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
            let instruction = i == 0 ? "Start walking clockwise" : 
                            i == numberOfPoints / 4 ? "Continue straight" :
                            i == numberOfPoints / 2 ? "You're halfway!" :
                            i == 3 * numberOfPoints / 4 ? "Almost back to start" : nil
            
            points.append(RoutePoint(coordinate: coordinate, instruction: instruction))
        }
        
        points.append(points[0])
        
        let distance = 2 * .pi * radius
        let estimatedSteps = Int(distance * 1.25)
        let estimatedDuration = distance / 1.4
        
        return WalkRoute(
            name: name,
            points: points,
            estimatedDistance: distance,
            estimatedSteps: estimatedSteps,
            estimatedDuration: estimatedDuration,
            difficulty: difficulty,
            terrain: terrain
        )
    }
    
    private func generateSquareRoute(
        center: CLLocationCoordinate2D,
        sideLength: Double,
        name: String,
        difficulty: WalkRoute.Difficulty,
        terrain: WalkRoute.TerrainType
    ) -> WalkRoute {
        let halfSide = sideLength / 2
        let latOffset = halfSide / 111000.0
        let lonOffset = halfSide / (111000.0 * cos(center.latitude * .pi / 180.0))
        
        let corners = [
            CLLocationCoordinate2D(latitude: center.latitude + latOffset, longitude: center.longitude - lonOffset),
            CLLocationCoordinate2D(latitude: center.latitude + latOffset, longitude: center.longitude + lonOffset),
            CLLocationCoordinate2D(latitude: center.latitude - latOffset, longitude: center.longitude + lonOffset),
            CLLocationCoordinate2D(latitude: center.latitude - latOffset, longitude: center.longitude - lonOffset)
        ]
        
        var points: [RoutePoint] = []
        let directions = ["Head north", "Turn right", "Turn right again", "Final turn"]
        
        for (index, corner) in corners.enumerated() {
            points.append(RoutePoint(coordinate: corner, instruction: directions[index]))
            
            if index < corners.count - 1 {
                let nextCorner = corners[index + 1]
                let midPoint = CLLocationCoordinate2D(
                    latitude: (corner.latitude + nextCorner.latitude) / 2,
                    longitude: (corner.longitude + nextCorner.longitude) / 2
                )
                points.append(RoutePoint(coordinate: midPoint))
            }
        }
        
        points.append(points[0])
        
        let distance = sideLength * 4
        let estimatedSteps = Int(distance * 1.25)
        let estimatedDuration = distance / 1.4
        
        return WalkRoute(
            name: name,
            points: points,
            estimatedDistance: distance,
            estimatedSteps: estimatedSteps,
            estimatedDuration: estimatedDuration,
            difficulty: difficulty,
            terrain: terrain
        )
    }
    
    private func generateFigureEightRoute(
        center: CLLocationCoordinate2D,
        radius: Double,
        name: String,
        difficulty: WalkRoute.Difficulty,
        terrain: WalkRoute.TerrainType
    ) -> WalkRoute {
        var points: [RoutePoint] = []
        let numberOfPoints = 16
        
        let leftCenter = CLLocationCoordinate2D(
            latitude: center.latitude,
            longitude: center.longitude - radius / (111000.0 * cos(center.latitude * .pi / 180.0))
        )
        let rightCenter = CLLocationCoordinate2D(
            latitude: center.latitude,
            longitude: center.longitude + radius / (111000.0 * cos(center.latitude * .pi / 180.0))
        )
        
        for i in 0..<numberOfPoints {
            let angle = Double(i) * 2.0 * .pi / Double(numberOfPoints)
            let currentCenter = i < numberOfPoints / 2 ? leftCenter : rightCenter
            
            let lat = currentCenter.latitude + (radius / 111000.0) * cos(angle)
            let lon = currentCenter.longitude + (radius / (111000.0 * cos(currentCenter.latitude * .pi / 180.0))) * sin(angle)
            
            let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
            let instruction = i == 0 ? "Start first loop" :
                            i == numberOfPoints / 2 ? "Cross to second loop" : nil
            
            points.append(RoutePoint(coordinate: coordinate, instruction: instruction))
        }
        
        points.append(points[0])
        
        let distance = 4 * .pi * radius
        let estimatedSteps = Int(distance * 1.25)
        let estimatedDuration = distance / 1.4
        
        return WalkRoute(
            name: name,
            points: points,
            estimatedDistance: distance,
            estimatedSteps: estimatedSteps,
            estimatedDuration: estimatedDuration,
            difficulty: difficulty,
            terrain: terrain
        )
    }
    
    private func generateMeanderingRoute(
        center: CLLocationCoordinate2D,
        targetDistance: Double,
        name: String,
        difficulty: WalkRoute.Difficulty,
        terrain: WalkRoute.TerrainType
    ) -> WalkRoute {
        var points: [RoutePoint] = []
        let numberOfSegments = 12
        let baseRadius = targetDistance / (numberOfSegments * .pi)
        
        var currentLocation = center
        var currentAngle: Double = 0
        
        points.append(RoutePoint(coordinate: currentLocation, instruction: "Begin scenic walk"))
        
        for i in 1..<numberOfSegments {
            currentAngle += (.pi / 3) + Double.random(in: -.pi/6...(.pi/6))
            let segmentLength = baseRadius * (0.8 + Double.random(in: 0...0.4))
            
            let latOffset = (segmentLength / 111000.0) * cos(currentAngle)
            let lonOffset = (segmentLength / (111000.0 * cos(currentLocation.latitude * .pi / 180.0))) * sin(currentAngle)
            
            currentLocation = CLLocationCoordinate2D(
                latitude: currentLocation.latitude + latOffset,
                longitude: currentLocation.longitude + lonOffset
            )
            
            let instruction = i == numberOfSegments / 3 ? "Enjoy the scenery" :
                            i == 2 * numberOfSegments / 3 ? "Heading back" : nil
            
            points.append(RoutePoint(coordinate: currentLocation, instruction: instruction))
        }
        
        points.append(RoutePoint(coordinate: center, instruction: "You're back!"))
        
        let estimatedSteps = Int(targetDistance * 1.25)
        let estimatedDuration = targetDistance / 1.4
        
        return WalkRoute(
            name: name,
            points: points,
            estimatedDistance: targetDistance,
            estimatedSteps: estimatedSteps,
            estimatedDuration: estimatedDuration,
            difficulty: difficulty,
            terrain: terrain
        )
    }
}