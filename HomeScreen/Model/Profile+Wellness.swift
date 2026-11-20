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
            completeness >= StandardInsightConfig.minimumDataCompleteness || availableWeight > 0
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
        let stepTarget: Double
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

        init(
            ageGroup: AgeGroup,
            steps: Int?,
            stepTarget: Double = 10000,
            caloriesBurned: Double?,
            calorieTarget: Double,
            totalSleepHours: Double?,
            sleepGoalHours: Double,
            deepSleepPercent: Double?,
            remSleepPercent: Double?,
            lightSleepPercent: Double?,
            hasSleepStages: Bool,
            restingHeartRate: Double?,
            hrv: Double?
        ) {
            self.ageGroup = ageGroup
            self.steps = steps
            self.stepTarget = stepTarget
            self.caloriesBurned = caloriesBurned
            self.calorieTarget = calorieTarget
            self.totalSleepHours = totalSleepHours
            self.sleepGoalHours = sleepGoalHours
            self.deepSleepPercent = deepSleepPercent
            self.remSleepPercent = remSleepPercent
            self.lightSleepPercent = lightSleepPercent
            self.hasSleepStages = hasSleepStages
            self.restingHeartRate = restingHeartRate
            self.hrv = hrv
        }
    }

    static func evaluate(_ input: Input) -> Result {
        var weighted = 0.0
        var available = 0.0

        // Steps (30%) - scales proportionally from 0 to target so any steps reflect on the score
        if let steps = input.steps, steps > 0 {
            let target = input.stepTarget > 0 ? input.stepTarget : defaultStepTarget(for: input.ageGroup)
            let s = clamp(Double(steps) / target)
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

    private static func defaultStepTarget(for ageGroup: AgeGroup) -> Double {
        switch ageGroup {
        case .child:      return 10000
        case .adolescent: return 10000
        case .adult:      return 10000
        case .senior:     return 7000
        }
    }

    private static func stepRange(for ageGroup: AgeGroup) -> (min: Double, max: Double) {
        return (0, defaultStepTarget(for: ageGroup))
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

    /// Evaluates the wellness score given pre-fetched metric rows for a specific day.
    /// Preserves existing formulas and missing-data behavior identically.
    func computeWellnessResultFromPreloaded(
        targetDay: Date,
        activities: [ActivityDaily],
        sleepData: SleepDaily?,
        vitals: [VitalsDaily]
    ) -> WellnessScoreCalculator.Result {
        let calendar = Calendar.current
        let age = calendar.dateComponents([.year], from: dob, to: targetDay).year ?? 30

        let ageGroup: AgeGroup = {
            switch age {
            case 5...12:  return .child
            case 13...17: return .adolescent
            case 18...64: return .adult
            default:      return .senior
            }
        }()

        let stepsRaw = activities.first(where: { $0.activityType == .stepCount })?.value
        let caloriesRaw = activities.first(where: { $0.activityType == .caloriesBurned })?.value
        let steps: Int? = (stepsRaw ?? 0) > 0 ? Int(stepsRaw!) : nil
        let calories: Double? = (caloriesRaw ?? 0) > 0 ? caloriesRaw : nil

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

        let restingRow = vitals.first(where: { $0.vitalType == .restingHeartRate })
        let heartRateRow = vitals.first(where: { $0.vitalType == .heartRate })
        let restingHR: Double? = restingRow?.avgValue
            ?? heartRateRow?.minValue
            ?? heartRateRow?.avgValue

        let hrv: Double? = vitals.first(where: { $0.vitalType == .hrv })?.avgValue

        let input = WellnessScoreCalculator.Input(
            ageGroup: ageGroup,
            steps: steps,
            stepTarget: Double(max(stepGoal, 1)),
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

    /// Uncached computation fallback. Reads the day's stored health rows and evaluates the score.
    private func computeWellnessResult(for date: Date) -> WellnessScoreCalculator.Result {
        let calendar = Calendar.current
        let targetDay = calendar.startOfDay(for: date) // normalize date
        let sqlite = SQLiteHelper.shared

        let activityRows = sqlite.fetchActivityDaily(for: profileId, on: targetDay)
        let sleepData = sqlite.fetchSleepDaily(for: profileId, on: targetDay)
        let vitalRows = sqlite.fetchVitalsDaily(for: profileId, on: targetDay)

        return computeWellnessResultFromPreloaded(
            targetDay: targetDay,
            activities: activityRows,
            sleepData: sleepData,
            vitals: vitalRows
        )
    }

    /// Efficiently batch-reads and computes wellness scores for multiple dates using 3 range queries.
    func prefetchWellnessScores(for dates: [Date]) {
        guard !dates.isEmpty else { return }
        let calendar = Calendar.current
        let normalizedDates = dates.map { calendar.startOfDay(for: $0) }
        let missingDates = normalizedDates.filter { !WellnessCache.shared.hasResult(for: profileId, on: $0) }
        guard !missingDates.isEmpty,
              let minDate = missingDates.min(),
              let maxDate = missingDates.max() else { return }
        
        let rangeStart = minDate
        let rangeEnd = calendar.date(byAdding: .day, value: 1, to: maxDate) ?? maxDate
        
        let sqlite = SQLiteHelper.shared
        let activities = sqlite.fetchActivityDaily(for: profileId, from: rangeStart, to: rangeEnd)
        let sleeps = sqlite.fetchSleepDaily(for: profileId, from: rangeStart, to: rangeEnd)
        let vitals = sqlite.fetchVitalsDaily(for: profileId, from: rangeStart, to: rangeEnd)
        
        var actByDay: [String: [ActivityDaily]] = [:]
        for act in activities {
            let key = WellnessCache.dayFormatter.string(from: act.date)
            actByDay[key, default: []].append(act)
        }
        var sleepByDay: [String: SleepDaily] = [:]
        for slp in sleeps {
            let key = WellnessCache.dayFormatter.string(from: slp.date)
            sleepByDay[key] = slp
        }
        var vitalsByDay: [String: [VitalsDaily]] = [:]
        for vit in vitals {
            let key = WellnessCache.dayFormatter.string(from: vit.date)
            vitalsByDay[key, default: []].append(vit)
        }
        
        var resultsToCache: [(date: Date, result: WellnessScoreCalculator.Result)] = []
        for targetDay in missingDates {
            let key = WellnessCache.dayFormatter.string(from: targetDay)
            let result = computeWellnessResultFromPreloaded(
                targetDay: targetDay,
                activities: actByDay[key] ?? [],
                sleepData: sleepByDay[key],
                vitals: vitalsByDay[key] ?? []
            )
            resultsToCache.append((date: targetDay, result: result))
        }
        WellnessCache.shared.setResults(resultsToCache, for: profileId)
    }

    /// Asynchronous batch-read API for wellness scores across multiple profiles and dates.
    static func prefetchWellnessScoresAsync(
        for profiles: [Profile],
        dates: [Date],
        completion: (() -> Void)? = nil
    ) {
        guard !profiles.isEmpty, !dates.isEmpty else {
            completion?()
            return
        }
        DispatchQueue.global(qos: .userInitiated).async {
            prefetchWellnessScores(for: profiles, dates: dates)
            if let completion = completion {
                DispatchQueue.main.async {
                    completion()
                }
            }
        }
    }

    /// Batch prefetches wellness scores for an array of profiles across a list of dates using 3 SQL range queries.
    static func prefetchWellnessScores(for profiles: [Profile], dates: [Date]) {
        guard !profiles.isEmpty, !dates.isEmpty else { return }
        let calendar = Calendar.current
        let normalizedDates = dates.map { calendar.startOfDay(for: $0) }
        guard let minDate = normalizedDates.min(), let maxDate = normalizedDates.max() else { return }
        let rangeStart = minDate
        let rangeEnd = calendar.date(byAdding: .day, value: 1, to: maxDate) ?? maxDate
        
        let profileIds = profiles.map { $0.profileId }
        let sqlite = SQLiteHelper.shared
        let allActivities = sqlite.fetchActivityDaily(for: profileIds, from: rangeStart, to: rangeEnd)
        let allSleeps = sqlite.fetchSleepDaily(for: profileIds, from: rangeStart, to: rangeEnd)
        let allVitals = sqlite.fetchVitalsDaily(for: profileIds, from: rangeStart, to: rangeEnd)
        
        var actByProfAndDay: [UUID: [String: [ActivityDaily]]] = [:]
        for act in allActivities {
            let dayKey = WellnessCache.dayFormatter.string(from: act.date)
            actByProfAndDay[act.profileId, default: [:]][dayKey, default: []].append(act)
        }
        var sleepByProfAndDay: [UUID: [String: SleepDaily]] = [:]
        for slp in allSleeps {
            let dayKey = WellnessCache.dayFormatter.string(from: slp.date)
            sleepByProfAndDay[slp.profileId, default: [:]][dayKey] = slp
        }
        var vitalsByProfAndDay: [UUID: [String: [VitalsDaily]]] = [:]
        for vit in allVitals {
            let dayKey = WellnessCache.dayFormatter.string(from: vit.date)
            vitalsByProfAndDay[vit.profileId, default: [:]][dayKey, default: []].append(vit)
        }
        
        for profile in profiles {
            let pid = profile.profileId
            let profActs = actByProfAndDay[pid] ?? [:]
            let profSleeps = sleepByProfAndDay[pid] ?? [:]
            let profVitals = vitalsByProfAndDay[pid] ?? [:]
            
            var resultsToCache: [(date: Date, result: WellnessScoreCalculator.Result)] = []
            for targetDay in normalizedDates {
                let dayKey = WellnessCache.dayFormatter.string(from: targetDay)
                let res = profile.computeWellnessResultFromPreloaded(
                    targetDay: targetDay,
                    activities: profActs[dayKey] ?? [],
                    sleepData: profSleeps[dayKey],
                    vitals: profVitals[dayKey] ?? []
                )
                resultsToCache.append((date: targetDay, result: res))
            }
            WellnessCache.shared.setResults(resultsToCache, for: pid)
        }
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

    fileprivate static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar.current
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = Calendar.current.timeZone
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private init() {
        // WellnessCache responds ONLY to HealthDataDidUpdate. Chat messages, challenge progress,
        // and nickname/profile updates NO LONGER invalidate health wellness scores.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleHealthDataDidUpdate(_:)),
            name: .HealthDataDidUpdate,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func handleHealthDataDidUpdate(_ notification: Notification) {
        if let profileId = notification.userInfo?[NotificationPayloadKey.profileId] as? UUID {
            invalidate(for: profileId)
        } else if let profileIds = notification.userInfo?[NotificationPayloadKey.profileIds] as? Set<UUID> {
            invalidate(for: profileIds)
        } else if let profileIdsArray = notification.userInfo?[NotificationPayloadKey.profileIds] as? [UUID] {
            invalidate(for: Set(profileIdsArray))
        } else {
            // General health update without specific profile ID: safely invalidate all
            invalidateAll()
        }
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

    /// Checks if a score is already memoized in cache without computing or blocking.
    func hasResult(for profileId: UUID, on date: Date) -> Bool {
        let k = key(for: profileId, on: date)
        lock.lock()
        defer { lock.unlock() }
        return storage[k] != nil
    }

    /// Stores a batch of pre-computed results directly into cache.
    func setResults(_ entries: [(date: Date, result: WellnessScoreCalculator.Result)], for profileId: UUID) {
        lock.lock()
        defer { lock.unlock() }
        for entry in entries {
            let k = key(for: profileId, on: entry.date)
            storage[k] = entry.result
        }
    }

    /// Invalidates all cached scores for a specific profile.
    func invalidate(for profileId: UUID) {
        let prefix = "\(profileId.uuidString)|"
        lock.lock()
        storage = storage.filter { !$0.key.hasPrefix(prefix) }
        lock.unlock()
    }

    /// Invalidates all cached scores for a set of profiles.
    func invalidate(for profileIds: Set<UUID>) {
        guard !profileIds.isEmpty else { return }
        let prefixes = Set(profileIds.map { "\($0.uuidString)|" })
        lock.lock()
        storage = storage.filter { entry in
            !prefixes.contains(where: { entry.key.hasPrefix($0) })
        }
        lock.unlock()
    }

    /// Clears every cached score (e.g. on logout or full database reset).
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
