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
        center: CLLocationCoordinate2D(latitude: 51.6280, longitude: -0.1055),
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
                useDefaultLocation()
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
        RouteMapView(
            region: $mapRegion,
            selectedRoute: selectedRoute,
            startLocation: startLocation,
            onMapTap: { coordinate in
                startLocation = coordinate
                generateRoutes()
            }
        )
    }
    
    private var controlsOverlay: some View {
        VStack(spacing: 16) {
            if let startLocation = startLocation {
                startLocationCard(startLocation)
            }
            
            if !routes.isEmpty {
                routeSelectionCard
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
    
    private var routeSelectionCard: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Choose Route")
                    .font(.headline)
                Spacer()
                if let route = selectedRoute {
                    Button("Start Walk") {
                        showingActiveWalk = true
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(routes) { route in
                        RoutePreviewCard(
                            route: route,
                            isSelected: selectedRoute?.id == route.id,
                            onSelect: {
                                selectedRoute = route
                            }
                        )
                    }
                }
                .padding(.horizontal, 4)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 4)
    }
    
    private var actionButtons: some View {
        VStack(spacing: 12) {
            if startLocation == nil {
                HStack(spacing: 12) {
                    Button(action: {
                        useDefaultLocation()
                    }) {
                        Label("Use N14 6DS", systemImage: "house")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button(action: {
                        useCurrentLocation()
                    }) {
                        Label("Current Location", systemImage: "location")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(!locationManager.isLocationAuthorized)
                }
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
    
    private func useDefaultLocation() {
        let n14Location = CLLocationCoordinate2D(latitude: 51.6280, longitude: -0.1055)
        startLocation = n14Location
        mapRegion.center = n14Location
        generateRoutes()
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

struct RouteMapView: UIViewRepresentable {
    @Binding var region: MKCoordinateRegion
    let selectedRoute: WalkRoute?
    let startLocation: CLLocationCoordinate2D?
    let onMapTap: (CLLocationCoordinate2D) -> Void
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        mapView.userTrackingMode = .none
        
        // Add tap gesture recognizer
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.mapTapped(_:)))
        mapView.addGestureRecognizer(tapGesture)
        
        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        // Update map region
        if mapView.region.center.latitude != region.center.latitude ||
           mapView.region.center.longitude != region.center.longitude {
            mapView.setRegion(region, animated: true)
        }
        
        // Clear existing overlays and annotations
        mapView.removeOverlays(mapView.overlays)
        mapView.removeAnnotations(mapView.annotations.filter { !($0 is MKUserLocation) })
        
        // Add start location annotation
        if let startLocation = startLocation {
            let annotation = MKPointAnnotation()
            annotation.coordinate = startLocation
            annotation.title = "Start"
            mapView.addAnnotation(annotation)
        }
        
        // Add route overlay
        if let route = selectedRoute {
            mapView.addOverlay(route.polyline)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        let parent: RouteMapView
        
        init(_ parent: RouteMapView) {
            self.parent = parent
        }
        
        @objc func mapTapped(_ gesture: UITapGestureRecognizer) {
            let mapView = gesture.view as! MKMapView
            let point = gesture.location(in: mapView)
            let coordinate = mapView.convert(point, toCoordinateFrom: mapView)
            parent.onMapTap(coordinate)
        }
        
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = UIColor.systemBlue
                renderer.lineWidth = 4
                renderer.lineCap = .round
                renderer.lineJoin = .round
                return renderer
            }
            return MKOverlayRenderer()
        }
        
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard !(annotation is MKUserLocation) else { return nil }
            
            let identifier = "StartPin"
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
            
            if annotationView == nil {
                annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                annotationView?.canShowCallout = true
            }
            
            if let markerView = annotationView as? MKMarkerAnnotationView {
                markerView.markerTintColor = UIColor.systemGreen
                markerView.glyphImage = UIImage(systemName: "figure.walk")
            }
            
            return annotationView
        }
        
        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            DispatchQueue.main.async {
                self.parent.region = mapView.region
            }
        }
    }
}

struct RoutePreviewCard: View {
    let route: WalkRoute
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 6) {
                Text(route.name)
                    .font(.caption)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)
                
                Text(route.estimatedDistanceText)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 2) {
                    Image(systemName: "clock")
                    Text(route.estimatedDurationText)
                }
                .font(.caption2)
                .foregroundColor(.secondary)
                
                Text(route.difficulty.rawValue)
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(route.difficulty.color).opacity(0.2))
                    .foregroundColor(Color(route.difficulty.color))
                    .cornerRadius(4)
            }
            .frame(width: 80)
            .padding(8)
            .background(isSelected ? Color.blue.opacity(0.1) : Color(.systemGray6))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}