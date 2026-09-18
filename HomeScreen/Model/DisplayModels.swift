import UIKit

enum WellnessCardType {
    case steps, distance, sleep, calories, heartRate, hrv
}

struct WellnessCard {
    let type: WellnessCardType
    let title: String
    let primaryValue: String
    let secondaryValue: String?
    let icon: String
    let iconColor: UIColor
    let chartData: [ChartDataPoint]?
    let sleepBreakdown: SleepBreakdown?  // ← only set for sleep card

    struct ChartDataPoint {
        let label: String
        let value: Double
        let rawValue: Int
    }

    struct SleepBreakdown {
        let deepMinutes: Int
        let remMinutes: Int
        let lightMinutes: Int
    }

    // convenience init without sleepBreakdown
    init(type: WellnessCardType, title: String, primaryValue: String,
         secondaryValue: String?, icon: String, iconColor: UIColor,
         chartData: [ChartDataPoint]?, sleepBreakdown: SleepBreakdown? = nil) {
        self.type = type
        self.title = title
        self.primaryValue = primaryValue
        self.secondaryValue = secondaryValue
        self.icon = icon
        self.iconColor = iconColor
        self.chartData = chartData
        self.sleepBreakdown = sleepBreakdown
    }
}

struct WellnessDataProvider {

    static func getWellnessCards(for profile: Profile, date: Date = Date()) -> [WellnessCard] {
        let all = getAllPossibleCards(for: profile, date: date)
        
        // If no selection is made, show all cards
        guard let visibleIds = profile.visibleMetricIds, !visibleIds.isEmpty else {
            return all
        }
        
        // Filter based on stored selection
        return all.filter { card in
            let id: String
            switch card.type {
            case .steps: id = "steps"
            case .sleep: id = "sleep"
            case .calories: id = "calories"
            case .distance: id = "distance"
            case .heartRate: id = "heartRate"
            case .hrv: id = "hrv"
            }
            return visibleIds.contains(id)
        }
    }

    static func getAllPossibleCards(for profile: Profile, date: Date = Date()) -> [WellnessCard] {
        [
            createStepsCard(profile, date: date),
            createDistanceCard(profile, date: date),
            createSleepCard(profile, date: date),
            createHeartRateCard(profile, date: date),
            createCaloriesCard(profile, date: date),
            createHRVCard(profile, date: date)
        ]
    }

    private static func createStepsCard(_ profile: Profile, date: Date) -> WellnessCard {
        let today = profile.dailyValue(for: .stepCount, date: date)
        let goal  = max(profile.stepGoal, 1)
        let hourly = profile.hourlyValues(for: .stepCount, date: date)
        
        if let todayValue = today {
            return WellnessCard(
                type: .steps,
                title: "Steps",
                primaryValue: "\(todayValue)",
                secondaryValue: "of \(goal) steps",
                icon: "shoeprints.fill",
                iconColor: .systemGreen,
                chartData: makeChartData(from: hourly, goal: goal)
            )
        } else {
            return WellnessCard(
                type: .steps,
                title: "Steps",
                primaryValue: "No data",
                secondaryValue: "of \(goal) steps",
                icon: "shoeprints.fill",
                iconColor: .systemGreen,
                chartData: nil
            )
        }
    }

    private static func createDistanceCard(_ profile: Profile, date: Date) -> WellnessCard {
        let today = profile.dailyValue(for: .distanceCovered, date: date)
        let goal  = max(profile.distanceGoal, 1)
        let hourly = profile.hourlyValues(for: .distanceCovered, date: date)
        let goalKm  = String(format: "%.1f", Double(goal) / 1000.0)
        
        if let todayValue = today {
            let todayKm = String(format: "%.3f", Double(todayValue) / 1000.0)
            return WellnessCard(
                type: .distance,
                title: "Distance",
                primaryValue: "\(todayKm) km",
                secondaryValue: "of \(goalKm) km",
                icon: "figure.walk",
                iconColor: .systemTeal,
                chartData: makeChartData(from: hourly, goal: goal)
            )
        } else {
            return WellnessCard(
                type: .distance,
                title: "Distance",
                primaryValue: "No data",
                secondaryValue: "of \(goalKm) km",
                icon: "figure.walk",
                iconColor: .systemTeal,
                chartData: nil
            )
        }
    }

    private static func createCaloriesCard(_ profile: Profile, date: Date) -> WellnessCard {
        let burned = profile.dailyValue(for: .caloriesBurned, date: date)
        let goal   = max(profile.caloriesGoal, 1)
        let hourly = profile.hourlyValues(for: .caloriesBurned, date: date)
        
        if let burnedValue = burned {
            return WellnessCard(
                type: .calories,
                title: "Calories",
                primaryValue: "\(burnedValue) kcal",
                secondaryValue: "of \(goal) kcal burn",
                icon: "flame.fill",
                iconColor: .systemOrange,
                chartData: makeChartData(from: hourly, goal: goal)
            )
        } else {
            return WellnessCard(
                type: .calories,
                title: "Calories",
                primaryValue: "No data",
                secondaryValue: "of \(goal) kcal burn",
                icon: "flame.fill",
                iconColor: .systemOrange,
                chartData: nil
            )
        }
    }

    private static func createSleepCard(_ profile: Profile, date: Date) -> WellnessCard {
        let today = Calendar.current.startOfDay(for: date)
        let sqlite = SQLiteHelper.shared
        let latest = sqlite.fetchSleepDaily(for: profile.profileId, on: today)

        guard let s = latest else {
            return WellnessCard(
                type: .sleep, title: "Sleep",
                primaryValue: "No data", secondaryValue: nil,
                icon: "moon.fill", iconColor: .systemBlue, chartData: nil
            )
        }

        let h = s.totalSleepMinutes / 60
        let m = s.totalSleepMinutes % 60
        let breakdown = WellnessCard.SleepBreakdown(
            deepMinutes:  s.deepSleepMinutes,
            remMinutes:   s.remSleepMinutes,
            lightMinutes: s.lightSleepMinutes
        )
        return WellnessCard(
            type: .sleep,
            title: "Sleep",
            primaryValue: "\(h)h \(m)m",
            secondaryValue: "of 8h sleep",
            icon: "moon.fill",
            iconColor: .systemBlue,
            chartData: nil,
            sleepBreakdown: breakdown
        )
    }

    private static func createHeartRateCard(_ profile: Profile, date: Date) -> WellnessCard {
        let today = Calendar.current.startOfDay(for: date)
        let sqlite = SQLiteHelper.shared
        let hr = sqlite.fetchVitalsDaily(for: profile.profileId, on: today)
            .first(where: { $0.vitalType == .heartRate })

        guard let hr else {
            return WellnessCard(
                type: .heartRate, title: "Heart Rate",
                primaryValue: "No data", secondaryValue: nil,
                icon: "heart.fill", iconColor: .systemPink, chartData: nil
            )
        }
        return WellnessCard(
            type: .heartRate,
            title: "Heart Rate",
            primaryValue: "\(Int(hr.avgValue ?? 0.0)) bpm",
            secondaryValue: "Avg: \(Int(hr.minValue ?? 0.0))-\(Int(hr.maxValue ?? 0.0)) bpm",
            icon: "heart.fill",
            iconColor: .systemPink,
            chartData: nil
        )
    }

    private static func createHRVCard(_ profile: Profile, date: Date) -> WellnessCard {
        let today = Calendar.current.startOfDay(for: date)
        let sqlite = SQLiteHelper.shared
        let hrv = sqlite.fetchVitalsDaily(for: profile.profileId, on: today)
            .first(where: { $0.vitalType == .hrv })

        guard let hrv else {
            return WellnessCard(
                type: .hrv, title: "HRV",
                primaryValue: "No data", secondaryValue: nil,
                icon: "waveform.path.ecg", iconColor: .systemPurple, chartData: nil
            )
        }
        return WellnessCard(
            type: .hrv,
            title: "HRV",
            primaryValue: "\(Int(hrv.avgValue ?? 0.0)) ms",
            secondaryValue: "Avg: \(Int(hrv.minValue ?? 0.0))-\(Int(hrv.maxValue ?? 0.0)) ms",
            icon: "waveform.path.ecg",
            iconColor: .systemPurple,
            chartData: nil
        )
    }

    // MARK: - Chart helpers

    private static func makeChartData(from values: [Int], goal: Int) -> [WellnessCard.ChartDataPoint] {
        values.enumerated().map { i, v in
            WellnessCard.ChartDataPoint(
                label: "\(i)h",
                value: min(Double(v) / Double(max(goal, 1)), 1.0),
                rawValue: v
            )
        }
    }
}

// MARK: - Profile helpers
private extension Profile {

    // Today's value from activityDaily
    func dailyValue(for type: ActivityType, date: Date) -> Int? {
        let today = Calendar.current.startOfDay(for: date)
        let sqlite = SQLiteHelper.shared
        let record = sqlite.fetchActivityDaily(for: profileId, on: today)
            .first(where: { $0.activityType == type })
        if let record = record {
            return Int(record.value)
        }
        return nil
    }

    // Today's 24 hourly values sorted by hourBucket 0→23
    func hourlyValues(for type: ActivityType, date: Date) -> [Int] {
        let today = Calendar.current.startOfDay(for: date)
        let todayRecords = SQLiteHelper.shared.fetchActivityHourly(for: profileId, on: today, type: type)
            .sorted { $0.hourBucket < $1.hourBucket }

        // Fill all 24 slots — 0 for missing hours
        var result = [Int](repeating: 0, count: 24)
        for record in todayRecords {
            if record.hourBucket >= 0 && record.hourBucket < 24 {
                result[record.hourBucket] = Int(record.value)
            }
        }
        return result
    }
}
