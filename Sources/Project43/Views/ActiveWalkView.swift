import SwiftUI
import MapKit
import CoreLocation

struct ActiveWalkView: View {
    let route: WalkRoute
    let goal: WalkGoal
    
    @StateObject private var healthKitManager = HealthKitManager()
    @StateObject private var walkSession = WalkSessionManager()
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingEndWalkAlert = false
    @State private var mapRegion: MKCoordinateRegion
    
    init(route: WalkRoute, goal: WalkGoal) {
        self.route = route
        self.goal = goal
        
        let center = route.points.first?.coordinate ?? CLLocationCoordinate2D(latitude: 0, longitude: 0)
        self._mapRegion = State(initialValue: MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
        ))
    }
    
    var body: some View {
        ZStack {
            mapView
            
            VStack {
                topControlsOverlay
                Spacer()
                bottomMetricsOverlay
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            startWalk()
        }
        .alert("End Walk?", isPresented: $showingEndWalkAlert) {
            Button("Continue") { }
            Button("End Walk", role: .destructive) {
                endWalk()
            }
        } message: {
            Text("Are you sure you want to end your walk? Your progress will be saved.")
        }
    }
    
    private var mapView: some View {
        Map(coordinateRegion: $mapRegion, showsUserLocation: true, annotationItems: routeAnnotations) { annotation in
            MapPin(coordinate: annotation.coordinate, tint: .blue)
        }
        .overlay(
            // Route path overlay
            RouteOverlay(route: route)
        )
    }
    
    private var topControlsOverlay: some View {
        HStack {
            Button(action: {
                showingEndWalkAlert = true
            }) {
                Image(systemName: "xmark")
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.black.opacity(0.6))
                    .clipShape(Circle())
            }
            
            Spacer()
            
            VStack(spacing: 4) {
                Text(walkSession.elapsedTimeString)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text("Elapsed Time")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.black.opacity(0.6))
            .cornerRadius(20)
            
            Spacer()
            
            Button(action: {
                // Toggle pause/resume
                walkSession.togglePause()
            }) {
                Image(systemName: walkSession.isPaused ? "play.fill" : "pause.fill")
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.black.opacity(0.6))
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 60)
    }
    
    private var bottomMetricsOverlay: some View {
        VStack(spacing: 16) {
            progressIndicator
            
            HStack(spacing: 20) {
                WalkMetricCard(
                    title: "Steps",
                    value: "\(healthKitManager.stepCount)",
                    target: goal.type == .steps ? "\(Int(goal.value))" : nil,
                    icon: "figure.walk",
                    color: .blue
                )
                
                WalkMetricCard(
                    title: "Distance",
                    value: String(format: "%.2f km", healthKitManager.distance / 1000),
                    target: goal.type == .distance ? String(format: "%.1f km", goal.value) : nil,
                    icon: "location",
                    color: .green
                )
                
                WalkMetricCard(
                    title: "Speed",
                    value: String(format: "%.1f km/h", healthKitManager.walkingSpeed * 3.6),
                    target: nil,
                    icon: "speedometer",
                    color: .orange
                )
            }
            
            if let nextInstruction = walkSession.nextInstruction {
                instructionCard(nextInstruction)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 40)
    }
    
    private var progressIndicator: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Progress")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Text("\(Int(walkSession.progressPercentage))%")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            
            ProgressView(value: walkSession.progressPercentage / 100)
                .progressViewStyle(LinearProgressViewStyle(tint: .white))
                .scaleEffect(x: 1, y: 2, anchor: .center)
        }
        .padding()
        .background(Color.black.opacity(0.6))
        .cornerRadius(12)
    }
    
    private func instructionCard(_ instruction: String) -> some View {
        HStack {
            Image(systemName: "arrow.turn.up.right")
                .font(.title2)
                .foregroundColor(.blue)
            
            Text(instruction)
                .font(.subheadline)
                .fontWeight(.medium)
            
            Spacer()
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 4)
    }
    
    private var routeAnnotations: [RouteAnnotation] {
        return route.points.enumerated().compactMap { index, point in
            if point.instruction != nil {
                return RouteAnnotation(
                    id: "instruction-\(index)",
                    coordinate: point.coordinate,
                    title: point.instruction ?? ""
                )
            }
            return nil
        }
    }
    
    private func startWalk() {
        Task {
            await healthKitManager.requestAuthorization()
            if healthKitManager.isAuthorized {
                healthKitManager.startLiveStepTracking()
                walkSession.startWalk(route: route, goal: goal)
            }
        }
    }
    
    private func endWalk() {
        walkSession.endWalk()
        dismiss()
    }
}

struct WalkMetricCard: View {
    let title: String
    let value: String
    let target: String?
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            if let target = target {
                Text("/ \(target)")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
            }
            
            Text(title)
                .font(.caption)
                .foregroundColor(.white.opacity(0.8))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.black.opacity(0.6))
        .cornerRadius(12)
    }
}

struct RouteAnnotation: Identifiable {
    let id: String
    let coordinate: CLLocationCoordinate2D
    let title: String
}

struct RouteOverlay: View {
    let route: WalkRoute
    
    var body: some View {
        // This would typically use MapKit's overlay system
        // For now, we'll use a simple path representation
        EmptyView()
    }
}

@MainActor
class WalkSessionManager: ObservableObject {
    @Published var isActive = false
    @Published var isPaused = false
    @Published var elapsedTime: TimeInterval = 0
    @Published var progressPercentage: Double = 0
    @Published var nextInstruction: String?
    
    private var startTime: Date?
    private var pausedTime: TimeInterval = 0
    private var timer: Timer?
    private var currentRoute: WalkRoute?
    private var currentGoal: WalkGoal?
    
    var elapsedTimeString: String {
        let minutes = Int(elapsedTime) / 60
        let seconds = Int(elapsedTime) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    func startWalk(route: WalkRoute, goal: WalkGoal) {
        currentRoute = route
        currentGoal = goal
        isActive = true
        startTime = Date()
        nextInstruction = route.points.first?.instruction
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            self.updateElapsedTime()
        }
    }
    
    func togglePause() {
        isPaused.toggle()
        
        if isPaused {
            timer?.invalidate()
        } else {
            timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                self.updateElapsedTime()
            }
        }
    }
    
    func endWalk() {
        isActive = false
        timer?.invalidate()
    }
    
    private func updateElapsedTime() {
        guard let startTime = startTime, !isPaused else { return }
        elapsedTime = Date().timeIntervalSince(startTime) - pausedTime
        updateProgress()
    }
    
    private func updateProgress() {
        guard let goal = currentGoal else { return }
        
        switch goal.type {
        case .steps:
            // This would be updated from HealthKit data
            progressPercentage = min((elapsedTime / 60) * 2, 100) // Placeholder
        case .distance:
            // This would be updated from location tracking
            progressPercentage = min((elapsedTime / 60) * 1.5, 100) // Placeholder
        case .time:
            progressPercentage = min((elapsedTime / (goal.value * 60)) * 100, 100)
        }
    }
}