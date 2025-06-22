import SwiftUI

struct RouteGoalView: View {
    @State private var selectedGoalType: WalkGoal.GoalType = .steps
    @State private var goalValue: Double = 5000
    @State private var showingMap = false
    
    private let stepOptions = Array(stride(from: 1000, through: 20000, by: 1000))
    private let distanceOptions = Array(stride(from: 0.5, through: 10.0, by: 0.5))
    private let timeOptions = Array(stride(from: 15, through: 120, by: 15))
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                headerSection
                goalTypeSection
                goalValueSection
                startButtonSection
                Spacer()
            }
            .padding(.horizontal, 20)
            .navigationTitle("Set Walking Goal")
            .navigationBarTitleDisplayMode(.large)
        }
        .sheet(isPresented: $showingMap) {
            MapRouteView(goal: currentGoal)
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "figure.walk")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            Text("Plan Your Walk")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Set your goal and we'll find the perfect circular route")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    private var goalTypeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Goal Type")
                .font(.headline)
            
            Picker("Goal Type", selection: $selectedGoalType) {
                ForEach(WalkGoal.GoalType.allCases, id: \.self) { type in
                    HStack {
                        Image(systemName: iconForGoalType(type))
                        Text(type.displayName)
                    }
                    .tag(type)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: selectedGoalType) { _ in
                updateDefaultValue()
            }
        }
    }
    
    private var goalValueSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Target")
                    .font(.headline)
                Spacer()
                Text(currentGoal.displayText)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)
            }
            
            VStack(spacing: 8) {
                Slider(value: $goalValue, 
                       in: sliderRange.lowerBound...sliderRange.upperBound,
                       step: sliderStep) {
                    Text("Goal Value")
                }
                
                HStack {
                    Text(minValueText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(maxValueText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 4)
        }
    }
    
    private var startButtonSection: some View {
        VStack(spacing: 16) {
            Button(action: {
                showingMap = true
            }) {
                HStack {
                    Image(systemName: "map")
                        .font(.title3)
                    Text("Find Routes")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            
            estimatedInfoSection
        }
    }
    
    private var estimatedInfoSection: some View {
        VStack(spacing: 8) {
            Text("Estimated")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            HStack(spacing: 24) {
                estimatedMetric(
                    icon: "clock",
                    value: estimatedTime,
                    label: "Duration"
                )
                
                estimatedMetric(
                    icon: "location",
                    value: estimatedDistance,
                    label: "Distance"
                )
                
                estimatedMetric(
                    icon: "figure.walk",
                    value: estimatedSteps,
                    label: "Steps"
                )
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 20)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func estimatedMetric(icon: String, value: String, label: String) -> some View {
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
    }
    
    private var currentGoal: WalkGoal {
        WalkGoal(type: selectedGoalType, value: goalValue)
    }
    
    private var sliderRange: ClosedRange<Double> {
        switch selectedGoalType {
        case .steps:
            return 1000...20000
        case .distance:
            return 0.5...10.0
        case .time:
            return 15...120
        }
    }
    
    private var sliderStep: Double {
        switch selectedGoalType {
        case .steps:
            return 500
        case .distance:
            return 0.5
        case .time:
            return 15
        }
    }
    
    private var minValueText: String {
        switch selectedGoalType {
        case .steps:
            return "1K steps"
        case .distance:
            return "0.5 km"
        case .time:
            return "15 min"
        }
    }
    
    private var maxValueText: String {
        switch selectedGoalType {
        case .steps:
            return "20K steps"
        case .distance:
            return "10 km"
        case .time:
            return "2 hours"
        }
    }
    
    private var estimatedTime: String {
        let minutes: Int
        switch selectedGoalType {
        case .steps:
            minutes = Int(goalValue / 100)
        case .distance:
            minutes = Int(goalValue * 12)
        case .time:
            minutes = Int(goalValue)
        }
        return "\(minutes) min"
    }
    
    private var estimatedDistance: String {
        let km: Double
        switch selectedGoalType {
        case .steps:
            km = goalValue * 0.0008
        case .distance:
            km = goalValue
        case .time:
            km = goalValue * 0.08
        }
        return String(format: "%.1f km", km)
    }
    
    private var estimatedSteps: String {
        let steps: Int
        switch selectedGoalType {
        case .steps:
            steps = Int(goalValue)
        case .distance:
            steps = Int(goalValue * 1250)
        case .time:
            steps = Int(goalValue * 100)
        }
        return "\(steps)"
    }
    
    private func iconForGoalType(_ type: WalkGoal.GoalType) -> String {
        switch type {
        case .steps:
            return "figure.walk"
        case .distance:
            return "location"
        case .time:
            return "clock"
        }
    }
    
    private func updateDefaultValue() {
        switch selectedGoalType {
        case .steps:
            goalValue = 5000
        case .distance:
            goalValue = 3.0
        case .time:
            goalValue = 30
        }
    }
}