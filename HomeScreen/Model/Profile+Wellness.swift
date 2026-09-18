//
//  Profile+Wellness.swift
//  HomeScreen
//
//  Created by Himadri on 2/02/26.
//
//This file calculates wellness score.
//Firstly the user along with his data is fetched and then passed to the caulcate function for calculating wellness score.

import Foundation
import UIKit
// Age Group enum to categorize users based on age
enum AgeGroup {
    case child
    case adolescent
    case adult
    case senior
}

struct WellnessScoreCalculator {
    // clamps any value between 0 and 1 to avoid overflow/underflow
    static func clamp(_ value: Double) -> Double {
        return max(0.0, min(value, 1.0))
    }

    /// The outcome of a wellness evaluation.
    ///
    /// `score` is renormalized over ONLY the metrics that actually had data, so a user
    /// without an Apple Watch (no HR/HRV/sleep) is no longer forced toward 0 just because
    /// those inputs are missing (#1). `completeness` reports how much of the total scoring
    /// weight had real data, which the UI uses to show an "insufficient data" state (#2).
    struct Result {
        let score: Double         // 0.0–1.0 across available metrics
        let completeness: Double  // 0.0–1.0 fraction of total weight that had data
        let availableWeight: Double
        let totalWeight: Double

        /// True when we have enough data to trust the score.
        var hasSufficientData: Bool {
            completeness >= StandardInsightConfig.minimumDataCompleteness
        }
        /// True when at least one metric had data.
        var hasAnyData: Bool { availableWeight > 0 }

        static let empty = Result(score: 0, completeness: 0, availableWeight: 0, totalWeight: 100)
    }

    // Component weights (sum = 100). HR and HRV rebalanced to 15/15 so HRV — the least
    // reliably available metric — no longer dominates the score (#3).
    private static let wSteps     = 30.0
    private static let wCalories  = 5.0
    private static let wSleep     = 35.0
    private static let wHeartRate = 15.0
    private static let wHRV       = 15.0
    static let totalWeight = wSteps + wCalories + wSleep + wHeartRate + wHRV

    /// All inputs are OPTIONAL. A `nil` value means "no data for this metric today" and is
    /// excluded from the score entirely (rather than counted as a zero).
    ///
    /// NOTE (#14): walking/running distance is intentionally NOT part of the wellness score.
    /// It is highly correlated with step count, so scoring both would double-count the same
    /// activity. Distance remains available as a viewable insight metric in the charts.
    struct Input {
        let ageGroup: AgeGroup
        let steps: Int?
        let caloriesBurned: Double?
        let calorieTarget: Double
        let totalSleepHours: Double?
        let sleepGoalHours: Double
        let deepSleepPercent: Double?
        let remSleepPercent: Double?
        let lightSleepPercent: Double?
        let hasSleepStages: Bool
        let restingHeartRate: Double?
        let hrv: Double?
    }

    static func evaluate(_ input: Input) -> Result {
        var weighted = 0.0
        var available = 0.0

        // Steps (30%)
        if let steps = input.steps {
            let range = stepRange(for: input.ageGroup)
            let s = clamp((Double(steps) - range.min) / (range.max - range.min))
            weighted += s * wSteps
            available += wSteps
        }

        // Calories (5%)
        if let cal = input.caloriesBurned, input.calorieTarget > 0 {
            weighted += clamp(cal / input.calorieTarget) * wCalories
            available += wCalories
        }

        // Sleep (35%) — duration is the primary driver so that adequate sleep without a
        // stage breakdown (iPhone-only / third-party trackers) is no longer scored poorly.
        // When Apple stage data exists we blend in a quality component (#13).
        if let hours = input.totalSleepHours, hours > 0 {
            let durationScore = clamp(input.sleepGoalHours > 0 ? hours / input.sleepGoalHours : 0)
            let sleepScore: Double
            if input.hasSleepStages {
                let deep  = clamp(((input.deepSleepPercent  ?? 0) - 10) / 10) // ideal deep >10%
                let rem   = clamp(((input.remSleepPercent   ?? 0) - 15) / 10) // ideal REM  >15%
                let light = clamp(1 - abs((input.lightSleepPercent ?? 0) - 55) / 25) // ~55% core/light
                let qualityScore = (deep + rem + light) / 3.0
                sleepScore = 0.6 * durationScore + 0.4 * qualityScore
            } else {
                sleepScore = durationScore
            }
            weighted += clamp(sleepScore) * wSleep
            available += wSleep
        }

        // Resting heart rate (15%)
        if let rhr = input.restingHeartRate, rhr > 0 {
            let s: Double
            if rhr <= 70 { s = 1 }                 // best condition
            else if rhr >= 90 { s = 0 }            // poor condition
            else { s = (90 - rhr) / 20 }           // scaled between 70–90
            weighted += clamp(s) * wHeartRate
            available += wHeartRate
        }

        // HRV (15%), reference depends on age
        if let hrv = input.hrv, hrv > 0 {
            weighted += clamp(hrv / hrvReference(for: input.ageGroup)) * wHRV
            available += wHRV
        }

        let score = available > 0 ? weighted / available : 0
        return Result(
            score: score,
            completeness: available / totalWeight,
            availableWeight: available,
            totalWeight: totalWeight
        )
    }

    private static func stepRange(for ageGroup: AgeGroup) -> (min: Double, max: Double) {
        switch ageGroup {
        case .child:      return (8000, 12000)
        case .adolescent: return (7000, 11000)
        case .adult:      return (5000, 10000)
        case .senior:     return (4000, 8000)
        }
    }

    private static func hrvReference(for ageGroup: AgeGroup) -> Double {
        switch ageGroup {
        case .child:      return 65 // higher HRV expected
        case .adolescent: return 55
        case .adult:      return 40
        case .senior:     return 25 // lower HRV expected
        }
    }
}

// extension on Profile to calculate daily wellness score
extension Profile {

    /// Full wellness evaluation for a day: score PLUS how complete the underlying data is.
    /// Results are memoized per (profile, day) and invalidated whenever health data changes,
    /// so charts/insights that ask for many days don't re-hit SQLite repeatedly (#8).
    func wellnessResult(for date: Date) -> WellnessScoreCalculator.Result {
        return WellnessCache.shared.result(for: profileId, on: date) {
            computeWellnessResult(for: date)
        }
    }

    /// Uncached computation. Reads the day's stored health rows and maps ABSENT metrics to
    /// `nil` (not 0), so missing data no longer drags the score down (#1, #2).
    private func computeWellnessResult(for date: Date) -> WellnessScoreCalculator.Result {
        let calendar = Calendar.current
        let targetDay = calendar.startOfDay(for: date) // normalize date
        let sqlite = SQLiteHelper.shared

        // calculate age from date of birth
        let age = calendar.dateComponents([.year], from: dob, to: date).year ?? 30

        // determine age group based on age
        let ageGroup: AgeGroup = {
            switch age {
            case 5...12:  return .child
            case 13...17: return .adolescent
            case 18...64: return .adult
            default:      return .senior
            }
        }()

        // Steps / calories — a positive value means real data; absence (or 0) means "no data".
        let activityRows = sqlite.fetchActivityDaily(for: profileId, on: targetDay)
        let stepsRaw = activityRows.first(where: { $0.activityType == .stepCount })?.value
        let caloriesRaw = activityRows.first(where: { $0.activityType == .caloriesBurned })?.value
        let steps: Int? = (stepsRaw ?? 0) > 0 ? Int(stepsRaw!) : nil
        let calories: Double? = (caloriesRaw ?? 0) > 0 ? caloriesRaw : nil

        // Sleep — only counts if there is a positive total. Stage percentages are supplied only
        // when Apple actually staged the sleep (deep/REM present); otherwise duration drives it.
        let sleepData = sqlite.fetchSleepDaily(for: profileId, on: targetDay)
        var totalSleepHours: Double? = nil
        var deepPct: Double? = nil
        var remPct: Double? = nil
        var lightPct: Double? = nil
        var hasStages = false
        if let sleepData, sleepData.totalSleep > 0 {
            totalSleepHours = sleepData.totalSleep
            let totalMin = Double(max(sleepData.totalSleepMinutes, 1))
            deepPct  = Double(sleepData.deepSleepMinutes)  / totalMin * 100
            remPct   = Double(sleepData.remSleepMinutes)   / totalMin * 100
            lightPct = Double(sleepData.lightSleepMinutes) / totalMin * 100
            hasStages = sleepData.deepSleepMinutes > 0 || sleepData.remSleepMinutes > 0
        }

        // Resting heart rate for the day. Prefer the true HealthKit resting HR sample;
        // if unavailable, fall back to the day's minimum HR (a reasonable resting proxy),
        // and only then to the average. A non-positive result is treated as "no data".
        let vitalRows = sqlite.fetchVitalsDaily(for: profileId, on: targetDay)
        let restingRow = vitalRows.first(where: { $0.vitalType == .restingHeartRate })
        let heartRateRow = vitalRows.first(where: { $0.vitalType == .heartRate })
        let restingHR: Double? = restingRow?.avgValue
            ?? heartRateRow?.minValue
            ?? heartRateRow?.avgValue

        // HRV value for the day.
        let hrv: Double? = vitalRows.first(where: { $0.vitalType == .hrv })?.avgValue

        let input = WellnessScoreCalculator.Input(
            ageGroup: ageGroup,
            steps: steps,
            caloriesBurned: calories,
            calorieTarget: Double(max(caloriesGoal, 1)),
            totalSleepHours: totalSleepHours,
            sleepGoalHours: sleepGoal > 0 ? sleepGoal : 8.0,
            deepSleepPercent: deepPct,
            remSleepPercent: remPct,
            lightSleepPercent: lightPct,
            hasSleepStages: hasStages,
            restingHeartRate: restingHR,
            hrv: hrv
        )

        return WellnessScoreCalculator.evaluate(input)
    }

    /// Daily wellness score in 0.0–1.0. Kept for existing call sites (charts, rings, etc.).
    func calculateWellnessScore(for date: Date) -> CGFloat {
        return CGFloat(wellnessResult(for: date).score)
    }

    /// Whether there is enough health data on `date` to present the score with confidence (#2).
    func hasSufficientWellnessData(for date: Date) -> Bool {
        return wellnessResult(for: date).hasSufficientData
    }
}

// MARK: - WellnessCache
//
// Memoizes per-(profile, day) wellness evaluations so that the Insight charts and cards —
// which ask for the same day's score many times per refresh and across multiple members —
// don't repeatedly hit SQLite on the main thread (#8).
//
// The cache invalidates itself whenever health data changes (it observes the
// "DataManagerDidUpdate" notification) and can be cleared explicitly on logout /
// account deletion (#12). It is safe to call from any thread.
//
// NOTE: this type lives in Profile+Wellness.swift (rather than its own file) so it is part
// of the existing Xcode target without needing a project-file change.
final class WellnessCache {
    static let shared = WellnessCache()

    private var storage: [String: WellnessScoreCalculator.Result] = [:]
    private let lock = NSLock()

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar.current
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = Calendar.current.timeZone
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private init() {
        // Any health-data change (sync, HealthKit background delivery, profile switch)
        // posts this notification; drop the whole cache so scores recompute from fresh data.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(invalidateAllObjc),
            name: NSNotification.Name("DataManagerDidUpdate"),
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func key(for profileId: UUID, on date: Date) -> String {
        return "\(profileId.uuidString)|\(Self.dayFormatter.string(from: date))"
    }

    /// Returns the cached result for (profile, day) or computes, stores, and returns it.
    func result(
        for profileId: UUID,
        on date: Date,
        compute: () -> WellnessScoreCalculator.Result
    ) -> WellnessScoreCalculator.Result {
        let k = key(for: profileId, on: date)

        lock.lock()
        if let cached = storage[k] {
            lock.unlock()
            return cached
        }
        lock.unlock()

        // Compute OUTSIDE the lock so a slow SQLite read doesn't block other lookups.
        let value = compute()

        lock.lock()
        storage[k] = value
        lock.unlock()

        return value
    }

    /// Clears every cached score.
    func invalidateAll() {
        lock.lock()
        storage.removeAll()
        lock.unlock()
    }

    @objc private func invalidateAllObjc() {
        invalidateAll()
    }
}

// MARK: - Abnormal Vitals Logic
extension Profile {
    /// Evaluates if the profile has any abnormal vitals for a given day (Heart Rate or HRV)
    /// based on personalized clinical thresholds for age and gender.
    func getAbnormalVital(on date: Date) -> (type: String, value: Double)? {
        let sqlite = SQLiteHelper.shared
        let vitalRows = sqlite.fetchVitalsDaily(for: self.profileId, on: date)
        
        let hrValue = vitalRows.first(where: { $0.vitalType == .heartRate })?.avgValue
        let restingHRValue = vitalRows.first(where: { $0.vitalType == .restingHeartRate })?.avgValue
        let hrvValue = vitalRows.first(where: { $0.vitalType == .hrv })?.avgValue
        
        // Use restingHR if available, fallback to average HR
        let effectiveHR = restingHRValue ?? hrValue
        
        let ageComponents = Calendar.current.dateComponents([.year], from: self.dob, to: Date())
        let age = ageComponents.year ?? 25
        
        if age >= 18 {
            let isFemale = (self.gender == .female)
            
            // HR Thresholds
            let lowHR = isFemale ? 55.0 : 50.0
            let highHR = isFemale ? 115.0 : 110.0
            
            if let hr = effectiveHR {
                if hr < lowHR { return ("low_hr", hr) }
                if hr > highHR { return ("high_hr", hr) }
            }
            
            // HRV Thresholds
            let lowHRV = isFemale ? 35.0 : 30.0
            if let hrv = hrvValue {
                if hrv < lowHRV { return ("low_hrv", hrv) }
            }
        } else if age <= 2 {
            // Infant thresholds
            if let hr = effectiveHR {
                if hr < 80.0 { return ("low_hr", hr) }
                if hr > 180.0 { return ("high_hr", hr) }
            }
            // HRV typically not monitored for infant alerts in this app context.
        } else {
            // Older children / teens: basic fallback
            if let hr = effectiveHR {
                if hr < 60.0 { return ("low_hr", hr) }
                if hr > 130.0 { return ("high_hr", hr) }
            }
        }
        
        return nil
    }
}
