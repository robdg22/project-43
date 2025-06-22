import SwiftUI
import Charts

struct WalkHistoryView: View {
    @StateObject private var healthKitManager = HealthKitManager()
    @State private var selectedTimePeriod: TimePeriod = .day
    @State private var walkHistory: [HealthMetrics] = []
    @State private var gaitAnalysis: GaitAnalysis?
    
    enum TimePeriod: String, CaseIterable {
        case day = "24 Hours"
        case week = "Week"
        case month = "Month"
        
        var days: Int {
            switch self {
            case .day: return 1
            case .week: return 7
            case .month: return 30
            }
        }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    timePeriodPicker
                    currentMetricsSection
                    chartSection
                    gaitAnalysisSection
                    weeklyGoalsSection
                }
                .padding()
            }
            .navigationTitle("Walk Analytics")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                loadHealthData()
            }
            .refreshable {
                await loadHealthDataAsync()
            }
        }
    }
    
    private var timePeriodPicker: some View {
        Picker("Time Period", selection: $selectedTimePeriod) {
            ForEach(TimePeriod.allCases, id: \.self) { period in
                Text(period.rawValue).tag(period)
            }
        }
        .pickerStyle(.segmented)
        .onChange(of: selectedTimePeriod) { _ in
            loadHealthData()
        }
    }
    
    private var currentMetricsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Today's Activity")
                .font(.headline)
            
            HStack(spacing: 20) {
                MetricCardView(
                    title: "Steps",
                    value: "\(healthKitManager.stepCount)",
                    icon: "figure.walk",
                    color: .blue,
                    trend: .up,
                    trendValue: "+12%"
                )
                
                MetricCardView(
                    title: "Distance",
                    value: String(format: "%.1f km", healthKitManager.distance / 1000),
                    icon: "location",
                    color: .green,
                    trend: .up,
                    trendValue: "+8%"
                )
            }
            
            HStack(spacing: 20) {
                MetricCardView(
                    title: "Avg Speed",
                    value: String(format: "%.1f km/h", healthKitManager.walkingSpeed * 3.6),
                    icon: "speedometer",
                    color: .orange,
                    trend: .stable,
                    trendValue: "±0%"
                )
                
                MetricCardView(
                    title: "Active Time",
                    value: "42 min",
                    icon: "clock",
                    color: .purple,
                    trend: .up,
                    trendValue: "+15%"
                )
            }
        }
    }
    
    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("\(selectedTimePeriod.rawValue) Overview")
                .font(.headline)
            
            TabView {
                stepsChartView
                    .tabItem {
                        Image(systemName: "figure.walk")
                        Text("Steps")
                    }
                
                distanceChartView
                    .tabItem {
                        Image(systemName: "location")
                        Text("Distance")
                    }
                
                speedChartView
                    .tabItem {
                        Image(systemName: "speedometer")
                        Text("Speed")
                    }
            }
            .frame(height: 300)
            .tabViewStyle(.page(indexDisplayMode: .always))
        }
    }
    
    private var stepsChartView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Daily Steps")
                .font(.subheadline)
                .fontWeight(.medium)
            
            Chart(walkHistory, id: \.date) { metrics in
                BarMark(
                    x: .value("Date", metrics.date, unit: .day),
                    y: .value("Steps", metrics.steps)
                )
                .foregroundStyle(.blue.gradient)
            }
            .frame(height: 200)
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { _ in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                }
            }
            .chartYAxis {
                AxisMarks { _ in
                    AxisGridLine()
                    AxisValueLabel()
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var distanceChartView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Daily Distance")
                .font(.subheadline)
                .fontWeight(.medium)
            
            Chart(walkHistory, id: \.date) { metrics in
                LineMark(
                    x: .value("Date", metrics.date, unit: .day),
                    y: .value("Distance", metrics.distance / 1000)
                )
                .foregroundStyle(.green)
                .symbol(.circle)
            }
            .frame(height: 200)
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { _ in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                }
            }
            .chartYAxis {
                AxisMarks { _ in
                    AxisGridLine()
                    AxisValueLabel()
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var speedChartView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Average Walking Speed")
                .font(.subheadline)
                .fontWeight(.medium)
            
            Chart(walkHistory, id: \.date) { metrics in
                AreaMark(
                    x: .value("Date", metrics.date, unit: .day),
                    y: .value("Speed", metrics.averageSpeed * 3.6)
                )
                .foregroundStyle(.orange.gradient)
            }
            .frame(height: 200)
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { _ in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                }
            }
            .chartYAxis {
                AxisMarks { _ in
                    AxisGridLine()
                    AxisValueLabel()
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var gaitAnalysisSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Gait Analysis")
                .font(.headline)
            
            if let gait = gaitAnalysis {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                    GaitMetricCard(
                        title: "Step Length",
                        value: gait.stepLengthText,
                        icon: "ruler",
                        description: "Average distance per step"
                    )
                    
                    GaitMetricCard(
                        title: "Cadence",
                        value: gait.cadenceText,
                        icon: "metronome",
                        description: "Steps per minute"
                    )
                    
                    GaitMetricCard(
                        title: "Consistency",
                        value: gait.consistencyText,
                        icon: "chart.line.uptrend.xyaxis",
                        description: "Step timing regularity"
                    )
                    
                    GaitMetricCard(
                        title: "Symmetry",
                        value: gait.symmetryText,
                        icon: "arrow.left.and.right",
                        description: "Left vs right balance"
                    )
                }
            } else {
                Text("Gait analysis requires more walking data")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
            }
        }
    }
    
    private var weeklyGoalsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Weekly Goals")
                .font(.headline)
            
            VStack(spacing: 12) {
                GoalProgressView(
                    title: "Step Goal",
                    current: 52000,
                    target: 70000,
                    unit: "steps",
                    color: .blue
                )
                
                GoalProgressView(
                    title: "Distance Goal",
                    current: 28.5,
                    target: 35.0,
                    unit: "km",
                    color: .green
                )
                
                GoalProgressView(
                    title: "Active Days",
                    current: 5,
                    target: 7,
                    unit: "days",
                    color: .purple
                )
            }
        }
    }
    
    private func loadHealthData() {
        Task {
            await healthKitManager.requestAuthorization()
            if healthKitManager.isAuthorized {
                await healthKitManager.fetchHealthData()
                generateMockData()
            }
        }
    }
    
    private func loadHealthDataAsync() async {
        await healthKitManager.fetchHealthData()
        generateMockData()
    }
    
    private func generateMockData() {
        walkHistory = []
        let calendar = Calendar.current
        let endDate = Date()
        
        for i in 0..<selectedTimePeriod.days {
            if let date = calendar.date(byAdding: .day, value: -i, to: endDate) {
                let metrics = HealthMetrics(
                    steps: Int.random(in: 3000...12000),
                    distance: Double.random(in: 2000...8000),
                    averageSpeed: Double.random(in: 1.0...2.0),
                    date: date
                )
                walkHistory.append(metrics)
            }
        }
        
        walkHistory.sort { $0.date < $1.date }
        
        gaitAnalysis = GaitAnalysis(
            averageStepLength: 0.75,
            cadence: 110,
            consistency: 0.85,
            symmetry: 0.92
        )
    }
}

struct MetricCardView: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    let trend: TrendDirection
    let trendValue: String
    
    enum TrendDirection {
        case up, down, stable
        
        var icon: String {
            switch self {
            case .up: return "arrow.up.right"
            case .down: return "arrow.down.right"
            case .stable: return "minus"
            }
        }
        
        var color: Color {
            switch self {
            case .up: return .green
            case .down: return .red
            case .stable: return .gray
            }
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Spacer()
                HStack(spacing: 2) {
                    Image(systemName: trend.icon)
                        .font(.caption)
                    Text(trendValue)
                        .font(.caption)
                }
                .foregroundColor(trend.color)
            }
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}

struct GaitMetricCard: View {
    let title: String
    let value: String
    let icon: String
    let description: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.blue)
                Spacer()
            }
            
            Text(value)
                .font(.title3)
                .fontWeight(.semibold)
            
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
            
            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}

struct GoalProgressView: View {
    let title: String
    let current: Double
    let target: Double
    let unit: String
    let color: Color
    
    private var progress: Double {
        min(current / target, 1.0)
    }
    
    private var isGoalAchieved: Bool {
        current >= target
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                if isGoalAchieved {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
                
                Text("\(formatValue(current)) / \(formatValue(target)) \(unit)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            ProgressView(value: progress)
                .progressViewStyle(LinearProgressViewStyle(tint: color))
                .scaleEffect(x: 1, y: 1.5)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    private func formatValue(_ value: Double) -> String {
        if value >= 1000 {
            return String(format: "%.0f", value)
        } else {
            return String(format: "%.1f", value)
        }
    }
}