import SwiftUI

struct ContentView: View {
    @StateObject private var healthKitManager = HealthKitManager()
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            RouteGoalView()
                .tabItem {
                    Image(systemName: "figure.walk.circle")
                    Text("New Walk")
                }
                .tag(0)
            
            WalkHistoryView()
                .tabItem {
                    Image(systemName: "chart.xyaxis.line")
                    Text("Analytics")
                }
                .tag(1)
            
            SettingsView()
                .tabItem {
                    Image(systemName: "gear")
                    Text("Settings")
                }
                .tag(2)
        }
        .onAppear {
            requestHealthKitPermissions()
        }
    }
    
    private func requestHealthKitPermissions() {
        Task {
            await healthKitManager.requestAuthorization()
        }
    }
}

struct SettingsView: View {
    @StateObject private var healthKitManager = HealthKitManager()
    
    var body: some View {
        NavigationView {
            List {
                Section("Health & Fitness") {
                    HStack {
                        Image(systemName: "heart.fill")
                            .foregroundColor(.red)
                        Text("HealthKit Integration")
                        Spacer()
                        Text(healthKitManager.isAuthorized ? "Connected" : "Not Connected")
                            .font(.caption)
                            .foregroundColor(healthKitManager.isAuthorized ? .green : .red)
                    }
                    
                    if !healthKitManager.isAuthorized {
                        Button("Enable HealthKit Access") {
                            Task {
                                await healthKitManager.requestAuthorization()
                            }
                        }
                        .foregroundColor(.blue)
                    }
                }
                
                Section("Walking Preferences") {
                    HStack {
                        Image(systemName: "speedometer")
                            .foregroundColor(.orange)
                        Text("Preferred Walking Speed")
                        Spacer()
                        Text("5.0 km/h")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Image(systemName: "location")
                            .foregroundColor(.blue)
                        Text("Default Route Distance")
                        Spacer()
                        Text("3.0 km")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("Privacy & Data") {
                    HStack {
                        Image(systemName: "location.fill")
                            .foregroundColor(.blue)
                        Text("Location Services")
                        Spacer()
                        Text("Enabled")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                    
                    HStack {
                        Image(systemName: "icloud.fill")
                            .foregroundColor(.blue)
                        Text("Sync with iCloud")
                        Spacer()
                        Toggle("", isOn: .constant(true))
                    }
                }
                
                Section("About") {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(.gray)
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                        Text("Rate App")
                    }
                    
                    HStack {
                        Image(systemName: "envelope.fill")
                            .foregroundColor(.blue)
                        Text("Send Feedback")
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

#Preview {
    ContentView()
}