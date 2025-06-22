import MapKit
import CoreLocation

@MainActor
class RouteGenerator: ObservableObject {
    private let locationManager = CLLocationManager()
    
    func generateRoutes(from startLocation: CLLocationCoordinate2D, for goal: WalkGoal) async -> [WalkRoute] {
        let targetDistance = calculateTargetDistance(for: goal)
        
        var routes: [WalkRoute] = []
        
        // Generate multiple route options using real street data
        async let route1 = generateStreetBasedRoute(
            from: startLocation,
            targetDistance: targetDistance,
            name: "Neighborhood Loop",
            direction: .clockwise,
            difficulty: .easy,
            terrain: .urban
        )
        
        async let route2 = generateStreetBasedRoute(
            from: startLocation,
            targetDistance: targetDistance,
            name: "Counter Loop",
            direction: .counterclockwise,
            difficulty: .easy,
            terrain: .urban
        )
        
        async let route3 = generateOutAndBackRoute(
            from: startLocation,
            targetDistance: targetDistance,
            name: "Out & Back",
            difficulty: .moderate,
            terrain: .mixed
        )
        
        async let route4 = generateExplorationRoute(
            from: startLocation,
            targetDistance: targetDistance,
            name: "Discovery Route",
            difficulty: .moderate,
            terrain: .park
        )
        
        let generatedRoutes = await [route1, route2, route3, route4].compactMap { $0 }
        routes.append(contentsOf: generatedRoutes)
        
        return routes
    }
    
    private enum RouteDirection {
        case clockwise
        case counterclockwise
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
    
    private func generateStreetBasedRoute(
        from startLocation: CLLocationCoordinate2D,
        targetDistance: Double,
        name: String,
        direction: RouteDirection,
        difficulty: WalkRoute.Difficulty,
        terrain: WalkRoute.TerrainType
    ) async -> WalkRoute? {
        // Generate waypoints for a loop route
        let waypoints = generateLoopWaypoints(
            center: startLocation,
            targetDistance: targetDistance,
            direction: direction
        )
        
        // Use MapKit to get walking directions between waypoints
        var routePoints: [RoutePoint] = []
        var totalDistance: Double = 0
        var totalDuration: TimeInterval = 0
        
        for i in 0..<waypoints.count {
            let fromPoint = waypoints[i]
            let toPoint = waypoints[(i + 1) % waypoints.count] // Loop back to start
            
            if let routeSegment = await getWalkingDirections(from: fromPoint, to: toPoint) {
                // Add the polyline points from this route segment
                let segmentPoints = routeSegment.polyline.points()
                let segmentCount = routeSegment.polyline.pointCount
                
                for j in 0..<segmentCount {
                    let coordinate = segmentPoints[j].coordinate
                    let instruction = (i == 0 && j == 0) ? "Start your walk" :
                                    (i == waypoints.count - 1 && j == segmentCount - 1) ? "You're back at the start!" :
                                    (j == 0) ? "Continue to next waypoint" : nil
                    
                    routePoints.append(RoutePoint(coordinate: coordinate, instruction: instruction))
                }
                
                totalDistance += routeSegment.distance
                totalDuration += routeSegment.expectedTravelTime
            }
        }
        
        let estimatedSteps = Int(totalDistance * 1.3) // Steps per meter for walking
        
        return WalkRoute(
            name: name,
            points: routePoints,
            estimatedDistance: totalDistance,
            estimatedSteps: estimatedSteps,
            estimatedDuration: totalDuration,
            difficulty: difficulty,
            terrain: terrain
        )
    }
    
    private func generateOutAndBackRoute(
        from startLocation: CLLocationCoordinate2D,
        targetDistance: Double,
        name: String,
        difficulty: WalkRoute.Difficulty,
        terrain: WalkRoute.TerrainType
    ) async -> WalkRoute? {
        // Calculate distance to walk out (half of target)
        let outDistance = targetDistance / 2.0
        
        // Find interesting destination in a direction that has walkable streets
        let destinations = findWalkableDestinations(from: startLocation, distance: outDistance)
        
        guard let destination = destinations.first else { return nil }
        
        var routePoints: [RoutePoint] = []
        var totalDistance: Double = 0
        var totalDuration: TimeInterval = 0
        
        // Get route to destination
        if let outRoute = await getWalkingDirections(from: startLocation, to: destination) {
            let outPoints = outRoute.polyline.points()
            let outCount = outRoute.polyline.pointCount
            
            for i in 0..<outCount {
                let coordinate = outPoints[i].coordinate
                let instruction = i == 0 ? "Head out on your route" :
                                i == outCount - 1 ? "Turnaround point reached" : nil
                routePoints.append(RoutePoint(coordinate: coordinate, instruction: instruction))
            }
            
            totalDistance += outRoute.distance
            totalDuration += outRoute.expectedTravelTime
        }
        
        // Get route back to start
        if let returnRoute = await getWalkingDirections(from: destination, to: startLocation) {
            let returnPoints = returnRoute.polyline.points()
            let returnCount = returnRoute.polyline.pointCount
            
            for i in 1..<returnCount { // Skip first point to avoid duplication
                let coordinate = returnPoints[i].coordinate
                let instruction = i == returnCount - 1 ? "You're back where you started!" : nil
                routePoints.append(RoutePoint(coordinate: coordinate, instruction: instruction))
            }
            
            totalDistance += returnRoute.distance
            totalDuration += returnRoute.expectedTravelTime
        }
        
        let estimatedSteps = Int(totalDistance * 1.3)
        
        return WalkRoute(
            name: name,
            points: routePoints,
            estimatedDistance: totalDistance,
            estimatedSteps: estimatedSteps,
            estimatedDuration: totalDuration,
            difficulty: difficulty,
            terrain: terrain
        )
    }
    
    private func generateExplorationRoute(
        from startLocation: CLLocationCoordinate2D,
        targetDistance: Double,
        name: String,
        difficulty: WalkRoute.Difficulty,
        terrain: WalkRoute.TerrainType
    ) async -> WalkRoute? {
        // Create a more complex route with multiple interesting waypoints
        let waypoints = findInterestingWaypoints(from: startLocation, targetDistance: targetDistance)
        
        var routePoints: [RoutePoint] = []
        var totalDistance: Double = 0
        var totalDuration: TimeInterval = 0
        
        for i in 0..<waypoints.count {
            let fromPoint = waypoints[i]
            let toPoint = waypoints[(i + 1) % waypoints.count]
            
            if let routeSegment = await getWalkingDirections(from: fromPoint, to: toPoint) {
                let segmentPoints = routeSegment.polyline.points()
                let segmentCount = routeSegment.polyline.pointCount
                
                for j in 0..<segmentCount {
                    let coordinate = segmentPoints[j].coordinate
                    let instruction = (i == 0 && j == 0) ? "Start exploring" :
                                    (i == waypoints.count - 1 && j == segmentCount - 1) ? "Back to start!" :
                                    (j == 0) ? "Exploring new area" : nil
                    
                    routePoints.append(RoutePoint(coordinate: coordinate, instruction: instruction))
                }
                
                totalDistance += routeSegment.distance
                totalDuration += routeSegment.expectedTravelTime
            }
        }
        
        let estimatedSteps = Int(totalDistance * 1.3)
        
        return WalkRoute(
            name: name,
            points: routePoints,
            estimatedDistance: totalDistance,
            estimatedSteps: estimatedSteps,
            estimatedDuration: totalDuration,
            difficulty: difficulty,
            terrain: terrain
        )
    }
    
    // MARK: - Helper Methods
    
    private func generateLoopWaypoints(
        center: CLLocationCoordinate2D,
        targetDistance: Double,
        direction: RouteDirection
    ) -> [CLLocationCoordinate2D] {
        let radius = targetDistance / (2.0 * Double.pi) / 111000.0 // Convert to degrees
        let numberOfWaypoints = 6
        var waypoints: [CLLocationCoordinate2D] = []
        
        for i in 0..<numberOfWaypoints {
            let angle = Double(i) * 2.0 * Double.pi / Double(numberOfWaypoints)
            let adjustedAngle = direction == .clockwise ? angle : -angle
            
            let lat = center.latitude + radius * cos(adjustedAngle)
            let lon = center.longitude + radius * sin(adjustedAngle) / cos(center.latitude * Double.pi / 180.0)
            
            waypoints.append(CLLocationCoordinate2D(latitude: lat, longitude: lon))
        }
        
        return waypoints
    }
    
    private func findWalkableDestinations(from start: CLLocationCoordinate2D, distance: Double) -> [CLLocationCoordinate2D] {
        // Generate potential destinations in different directions
        let directions: [Double] = [0, Double.pi/2, Double.pi, 3*Double.pi/2] // N, E, S, W
        var destinations: [CLLocationCoordinate2D] = []
        
        for direction in directions {
            let distanceInDegrees = distance / 111000.0
            let lat = start.latitude + distanceInDegrees * cos(direction)
            let lon = start.longitude + distanceInDegrees * sin(direction) / cos(start.latitude * Double.pi / 180.0)
            
            destinations.append(CLLocationCoordinate2D(latitude: lat, longitude: lon))
        }
        
        return destinations
    }
    
    private func findInterestingWaypoints(from start: CLLocationCoordinate2D, targetDistance: Double) -> [CLLocationCoordinate2D] {
        let radius = targetDistance / (3.0 * Double.pi) / 111000.0
        var waypoints = [start] // Start with the starting point
        
        // Add 3-4 waypoints for an interesting exploration route
        let angles: [Double] = [Double.pi/4, 3*Double.pi/4, 5*Double.pi/4, 7*Double.pi/4]
        
        for angle in angles.prefix(3) {
            let lat = start.latitude + radius * cos(angle)
            let lon = start.longitude + radius * sin(angle) / cos(start.latitude * Double.pi / 180.0)
            waypoints.append(CLLocationCoordinate2D(latitude: lat, longitude: lon))
        }
        
        return waypoints
    }
    
    private func getWalkingDirections(from source: CLLocationCoordinate2D, to destination: CLLocationCoordinate2D) async -> MKRoute? {
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: source))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: destination))
        request.transportType = .walking
        
        let directions = MKDirections(request: request)
        
        do {
            let response = try await directions.calculate()
            return response.routes.first
        } catch {
            print("Failed to get walking directions: \(error)")
            return nil
        }
    }
}