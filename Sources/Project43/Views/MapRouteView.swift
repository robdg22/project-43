import SwiftUI
import MapKit
import CoreLocation

struct MapRouteView: View {
    let goal: WalkGoal
    
    @StateObject private var locationManager = LocationManager()
    @StateObject private var routeGenerator = RouteGenerator()
    @State private var routes: [WalkRoute] = []
    @State private var selectedRoute: WalkRoute?
    @State private var showingRoutesList = false
    @State private var mapRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    )
    @State private var startLocation: CLLocationCoordinate2D?
    @State private var isGeneratingRoutes = false
    @State private var showingActiveWalk = false
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                mapView
                
                VStack {
                    Spacer()
                    controlsOverlay
                }
            }
            .navigationTitle("Choose Route")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Routes") {
                        showingRoutesList = true
                    }
                    .disabled(routes.isEmpty)
                }
            }
            .onAppear {
                setupLocationServices()
            }
            .sheet(isPresented: $showingRoutesList) {
                RouteSelectionView(
                    routes: routes,
                    selectedRoute: $selectedRoute,
                    goal: goal,
                    onStartWalk: {
                        showingActiveWalk = true
                        showingRoutesList = false
                    }
                )
            }
            .fullScreenCover(isPresented: $showingActiveWalk) {
                if let route = selectedRoute {
                    ActiveWalkView(route: route, goal: goal)
                }
            }
        }
    }
    
    private var mapView: some View {
        Map(coordinateRegion: $mapRegion, annotationItems: annotationItems) { item in
            MapAnnotation(coordinate: item.coordinate) {
                annotationView(for: item)
            }
        }
        .onTapGesture { location in
            handleMapTap(at: location)
        }
    }
    
    private var controlsOverlay: some View {
        VStack(spacing: 16) {
            if let startLocation = startLocation {
                startLocationCard(startLocation)
            }
            
            if !routes.isEmpty {
                selectedRouteCard
            }
            
            actionButtons
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
    }
    
    private func startLocationCard(_ location: CLLocationCoordinate2D) -> some View {
        HStack {
            Image(systemName: "mappin.and.ellipse")
                .foregroundColor(.blue)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Start Location")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text("\(location.latitude, specifier: "%.4f"), \(location.longitude, specifier: "%.4f")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if isGeneratingRoutes {
                ProgressView()
                    .scaleEffect(0.8)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 4)
    }
    
    private var selectedRouteCard: some View {
        Group {
            if let route = selectedRoute {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(route.name)
                            .font(.headline)
                        
                        HStack(spacing: 16) {
                            Label(route.estimatedDistanceText, systemImage: "location")
                            Label(route.estimatedDurationText, systemImage: "clock")
                            Label(route.difficulty.rawValue, systemImage: "speedometer")
                                .foregroundColor(Color(route.difficulty.color))
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Button("Start Walk") {
                        showingActiveWalk = true
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(radius: 4)
            }
        }
    }
    
    private var actionButtons: some View {
        HStack(spacing: 12) {
            if startLocation == nil {
                Button(action: {
                    useCurrentLocation()
                }) {
                    Label("Use Current Location", systemImage: "location")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(!locationManager.isLocationAuthorized)
            }
            
            if startLocation != nil && routes.isEmpty && !isGeneratingRoutes {
                Button(action: {
                    generateRoutes()
                }) {
                    Label("Generate Routes", systemImage: "map")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
    
    private var annotationItems: [MapAnnotationItem] {
        var items: [MapAnnotationItem] = []
        
        if let startLocation = startLocation {
            items.append(MapAnnotationItem(
                id: "start",
                coordinate: startLocation,
                type: .start
            ))
        }
        
        if let route = selectedRoute {
            for (index, point) in route.points.enumerated() {
                if index == 0 || index == route.points.count - 1 {
                    continue
                }
                items.append(MapAnnotationItem(
                    id: "route-\(index)",
                    coordinate: point.coordinate,
                    type: .routePoint
                ))
            }
        }
        
        return items
    }
    
    private func annotationView(for item: MapAnnotationItem) -> some View {
        Group {
            switch item.type {
            case .start:
                Image(systemName: "mappin.circle.fill")
                    .foregroundColor(.blue)
                    .font(.title2)
            case .routePoint:
                Circle()
                    .fill(Color.orange)
                    .frame(width: 8, height: 8)
            }
        }
    }
    
    private func setupLocationServices() {
        locationManager.requestLocationPermission()
    }
    
    private func useCurrentLocation() {
        if let location = locationManager.currentLocation {
            startLocation = location.coordinate
            mapRegion.center = location.coordinate
            generateRoutes()
        }
    }
    
    private func handleMapTap(at screenLocation: CGPoint) {
        let coordinate = mapRegion.center
        startLocation = coordinate
        generateRoutes()
    }
    
    private func generateRoutes() {
        guard let startLocation = startLocation else { return }
        
        isGeneratingRoutes = true
        
        Task {
            let generatedRoutes = await routeGenerator.generateRoutes(from: startLocation, for: goal)
            
            await MainActor.run {
                self.routes = generatedRoutes
                self.selectedRoute = generatedRoutes.first
                self.isGeneratingRoutes = false
            }
        }
    }
}

struct MapAnnotationItem: Identifiable {
    let id: String
    let coordinate: CLLocationCoordinate2D
    let type: AnnotationType
    
    enum AnnotationType {
        case start
        case routePoint
    }
}

@MainActor
class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    
    @Published var currentLocation: CLLocation?
    @Published var isLocationAuthorized = false
    
    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }
    
    func requestLocationPermission() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            isLocationAuthorized = true
            manager.startUpdatingLocation()
        default:
            isLocationAuthorized = false
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        currentLocation = locations.last
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            isLocationAuthorized = true
            manager.startUpdatingLocation()
        default:
            isLocationAuthorized = false
        }
    }
}