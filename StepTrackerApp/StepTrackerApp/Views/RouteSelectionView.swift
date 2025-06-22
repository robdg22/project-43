import SwiftUI
import MapKit

struct RouteSelectionView: View {
    let routes: [WalkRoute]
    @Binding var selectedRoute: WalkRoute?
    let goal: WalkGoal
    let onStartWalk: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var showingRouteDetails = false
    @State private var detailRoute: WalkRoute?
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 16) {
                    goalSummaryCard
                    
                    ForEach(routes) { route in
                        RouteCard(
                            route: route,
                            isSelected: selectedRoute?.id == route.id,
                            onSelect: {
                                selectedRoute = route
                            },
                            onShowDetails: {
                                detailRoute = route
                                showingRouteDetails = true
                            }
                        )
                    }
                }
                .padding()
            }
            .navigationTitle("Choose Your Route")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Back") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Start Walk") {
                        onStartWalk()
                    }
                    .disabled(selectedRoute == nil)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }
        }
        .sheet(item: $detailRoute) { route in
            RouteDetailView(route: route)
        }
    }
    
    private var goalSummaryCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "target")
                    .foregroundColor(.blue)
                Text("Your Goal")
                    .font(.headline)
                Spacer()
                Text(goal.displayText)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)
            }
            
            Text("Choose a route that matches your walking goal")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct RouteCard: View {
    let route: WalkRoute
    let isSelected: Bool
    let onSelect: () -> Void
    let onShowDetails: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(route.name)
                        .font(.headline)
                    
                    HStack(spacing: 4) {
                        Image(systemName: route.terrain.icon)
                        Text(route.terrain.rawValue)
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    DifficultyBadge(difficulty: route.difficulty)
                    
                    Button("Details") {
                        onShowDetails()
                    }
                    .font(.caption)
                    .controlSize(.mini)
                }
            }
            
            HStack(spacing: 24) {
                MetricView(
                    icon: "location",
                    value: route.estimatedDistanceText,
                    label: "Distance"
                )
                
                MetricView(
                    icon: "clock",
                    value: route.estimatedDurationText,
                    label: "Time"
                )
                
                MetricView(
                    icon: "figure.walk",
                    value: "\(route.estimatedSteps)",
                    label: "Steps"
                )
            }
            
            Button(action: onSelect) {
                HStack {
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.white)
                    }
                    Text(isSelected ? "Selected" : "Select Route")
                        .fontWeight(.medium)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(isSelected ? Color.blue : Color.clear)
                .foregroundColor(isSelected ? .white : .blue)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.blue, lineWidth: isSelected ? 0 : 1)
                )
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: isSelected ? .blue.opacity(0.3) : .black.opacity(0.1), radius: isSelected ? 8 : 4)
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.spring(response: 0.3), value: isSelected)
    }
}

struct MetricView: View {
    let icon: String
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.blue)
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct DifficultyBadge: View {
    let difficulty: WalkRoute.Difficulty
    
    var body: some View {
        Text(difficulty.rawValue)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(difficulty.color).opacity(0.2))
            .foregroundColor(Color(difficulty.color))
            .cornerRadius(8)
    }
}

struct RouteDetailView: View {
    let route: WalkRoute
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    routeOverview
                    metricsSection
                    instructionsSection
                }
                .padding()
            }
            .navigationTitle(route.name)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var routeOverview: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: route.terrain.icon)
                    .font(.title2)
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(route.terrain.rawValue)
                        .font(.headline)
                    
                    DifficultyBadge(difficulty: route.difficulty)
                }
                
                Spacer()
            }
            
            Text(routeDescription)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var metricsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Route Metrics")
                .font(.headline)
            
            HStack(spacing: 16) {
                MetricView(
                    icon: "location",
                    value: route.estimatedDistanceText,
                    label: "Distance"
                )
                
                MetricView(
                    icon: "clock",
                    value: route.estimatedDurationText,
                    label: "Duration"
                )
                
                MetricView(
                    icon: "figure.walk",
                    value: "\(route.estimatedSteps)",
                    label: "Steps"
                )
            }
        }
    }
    
    private var instructionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Route Instructions")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(route.points.enumerated()), id: \.offset) { index, point in
                    if let instruction = point.instruction {
                        HStack(alignment: .top, spacing: 12) {
                            Text("\(index + 1)")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                                .frame(width: 20, height: 20)
                                .background(Circle().fill(Color.blue))
                            
                            Text(instruction)
                                .font(.subheadline)
                            
                            Spacer()
                        }
                    }
                }
            }
        }
    }
    
    private var routeDescription: String {
        switch route.name {
        case "Perfect Circle":
            return "A simple circular route that brings you back to your starting point. Great for consistent pacing and easy navigation."
        case "City Block Loop":
            return "Follow city blocks in a square pattern. Perfect for urban walking with clear landmarks and turn points."
        case "Figure Eight":
            return "A more interesting route that crosses itself at the midpoint. Offers variety while maintaining the circular nature."
        case "Scenic Meander":
            return "A winding route that takes you through varied terrain. Perfect for those who enjoy exploring and changing scenery."
        default:
            return "A custom route designed to meet your walking goals while bringing you back to your starting location."
        }
    }
}