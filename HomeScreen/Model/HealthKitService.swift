//
//  HealthKitService.swift
//  HomeScreen
//
//  Created by Mohd Kushaad on 12/03/26.
//

import Foundation
import HealthKit
import UIKit
import CryptoKit

final class HealthKitService {
    static let shared = HealthKitService()

    private let healthStore = HKHealthStore()
    private let calendar = Calendar.current
    private let daysBack = 30

    // Coalesces overlapping HKObserverQuery callbacks so repeated/duplicate
    // HealthKit notifications don't kick off concurrent fetch+sync passes.
    private var backgroundDeliveryInFlight = false
    private var backgroundDeliveryPending = false

    private init() {}

    enum HealthKitSyncError: LocalizedError {
        case healthDataUnavailable
        case authorizationDenied

        var errorDescription: String? {
            switch self {
            case .healthDataUnavailable:
                return "Health data is not available on this device."
            case .authorizationDenied:
                return "HealthKit permission was not granted."
            }
        }
    }

    struct HealthKitSyncPayload {
        let activityDaily: [ActivityDaily]
        let activityHourly: [ActivityHourly]
        let vitalsDaily: [VitalsDaily]
        let vitalsHourly: [VitalsHourly]
        let sleepDaily: [SleepDaily]
    }

    private var readTypes: Set<HKObjectType> {
        [
            HKQuantityType.quantityType(forIdentifier: .stepCount)!,
            HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)!,
            HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKCategoryType.categoryType(forIdentifier: .sleepAnalysis)!,
            HKQuantityType.quantityType(forIdentifier: .heartRate)!,
            HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!
        ]
    }

    /// Best-effort read-access state.
    ///
    /// IMPORTANT: For privacy, iOS deliberately does NOT tell apps whether the user
    /// GRANTED or DENIED read access to a given type — `authorizationStatus(for:)`
    /// only reflects SHARE (write) permission, which this app never requests. The only
    /// honest signal available for read-only access is `getRequestStatusForAuthorization`,
    /// which tells us whether the permission sheet still needs to be shown.
    enum ReadAccessState {
        case unavailable      // HealthKit not available on this device
        case notRequested     // We have never asked; the system sheet should be shown
        case requested        // We have asked; grant/deny per type is intentionally hidden by iOS
    }

    /// Asynchronously reports whether HealthKit read access still needs to be requested.
    func readAccessState(completion: @escaping (ReadAccessState) -> Void) {
        guard HKHealthStore.isHealthDataAvailable() else {
            completion(.unavailable)
            return
        }
        healthStore.getRequestStatusForAuthorization(toShare: [], read: readTypes) { status, _ in
            switch status {
            case .shouldRequest:
                completion(.notRequested)
            case .unnecessary:
                completion(.requested)
            case .unknown:
                completion(.requested)
            @unknown default:
                completion(.requested)
            }
        }
    }

    /// Deprecated: read-access denial cannot be reliably detected on iOS (see
    /// `readAccessState`). Retained only for source compatibility; always `false`
    /// because this app requests read-only access and never share/write access.
    @available(*, deprecated, message: "Read denial is not detectable on iOS; use readAccessState(_:) instead.")
    func isAuthorizationDenied() -> Bool {
        return false
    }

    func authorizeHealthKit(completion: @escaping (Result<Void, Error>) -> Void) {
        guard HKHealthStore.isHealthDataAvailable() else {
            completion(.failure(HealthKitSyncError.healthDataUnavailable))
            return
        }

        healthStore.requestAuthorization(toShare: [], read: readTypes) { success, error in
            if let error {
                completion(.failure(error))
                return
            }

            success ? completion(.success(())) : completion(.failure(HealthKitSyncError.authorizationDenied))
        }
    }
    
    func setupBackgroundDelivery() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        
        for type in readTypes {
            guard let sampleType = type as? HKSampleType else { continue }
            
            // Request immediate updates so HealthKit notifies as soon as data is written.
            // Fall back to hourly if immediate delivery is not supported for a specific type.
            healthStore.enableBackgroundDelivery(for: sampleType, frequency: .immediate) { [weak self] success, error in
                if !success {
                    self?.healthStore.enableBackgroundDelivery(for: sampleType, frequency: .hourly) { _, _ in }
                }
                #if DEBUG
                if let error = error {
                    print("Background delivery status for \(sampleType.identifier): success=\(success), error=\(error.localizedDescription)")
                }
                #endif
            }
            
            let query = HKObserverQuery(sampleType: sampleType, predicate: nil) { _, completionHandler, error in
                guard error == nil else {
                    // Never leave HealthKit waiting; the next callback will retry.
                    completionHandler()
                    return
                }
                // Fetch changed data → persist to SQLite → push to Widget → best-effort Supabase push,
                // then ALWAYS release HealthKit's completion handler.
                Task { @MainActor in
                    await HealthKitService.shared.handleBackgroundDelivery()
                    completionHandler()
                }
            }
            healthStore.execute(query)
        }
    }

    /// Background-delivery pipeline invoked from the HKObserverQuery handler:
    /// fetch changed/latest HealthKit data → persist to SQLite (rows stay unsynced)
    /// → update widget immediately → best-effort push to Supabase. Resilient to no network, Supabase being
    /// unavailable, the background window ending, and repeated/duplicate callbacks.
    /// The caller must invoke the HealthKit completion handler after this returns.
    @MainActor
    func handleBackgroundDelivery() async {
        guard HKHealthStore.isHealthDataAvailable() else { return }

        // Coalesce concurrent observer callbacks (one per sample type can fire at once).
        if backgroundDeliveryInFlight {
            backgroundDeliveryPending = true
            return
        }

        // Ensure DataManager has loaded the user from SQLite if not already loaded (e.g. background launch)
        if DataManager.shared.currentUser == nil {
            _ = DataManager.shared.loadFromSQLite()
        }

        // Only sync for the profile that owns this device's HealthKit data.
        guard let currentUser = DataManager.shared.currentUser else { return }
        _ = DataManager.shared.resolveOrCreateHealthKitLink(for: currentUser)
        guard DataManager.shared.isCurrentUserHealthKitLinked() else { return }
        let profileId = currentUser.profileId

        backgroundDeliveryInFlight = true
        defer {
            backgroundDeliveryInFlight = false
            if backgroundDeliveryPending {
                backgroundDeliveryPending = false
                Task { @MainActor in
                    await self.handleBackgroundDelivery()
                }
            }
        }

        // Request a short, supported background execution window. iOS decides how much
        // time we actually get and may end it early; we always release it below.
        let app = UIApplication.shared
        var bgTaskId: UIBackgroundTaskIdentifier = .invalid
        bgTaskId = app.beginBackgroundTask(withName: "HealthKitBackgroundSync") {
            if bgTaskId != .invalid {
                app.endBackgroundTask(bgTaskId)
                bgTaskId = .invalid
            }
        }
        defer {
            if bgTaskId != .invalid {
                app.endBackgroundTask(bgTaskId)
                bgTaskId = .invalid
            }
        }

        // 1. Fetch the latest data from HealthKit.
        let payload: HealthKitSyncPayload
        do {
            payload = try await fetchWellnessPayloadAsync(for: profileId)
        } catch {
            #if DEBUG
            print("HealthKit background fetch failed: \(error.localizedDescription). Keeping cached data; SyncManager will retry later.")
            #endif
            return
        }

        // 2. Persist to SQLite FIRST (rows marked unsynced) — before any network work.
        SQLiteHelper.shared.replaceHealthData(
            for: profileId,
            activityDaily: payload.activityDaily,
            activityHourly: payload.activityHourly,
            vitalsDaily: payload.vitalsDaily,
            vitalsHourly: payload.vitalsHourly,
            sleepDaily: payload.sleepDaily
        )
        
        // Synchronously update DataManager buffers and notify observers
        DataManager.shared.reloadHealthData(for: profileId)
        
        // Push directly to the shared widget container so the widget updates in the background
        WidgetDataProvider.shared.pushToWidget()

        // 3. Best-effort upload. If the network is down or the window ends, the rows
        //    remain unsynced and the existing SyncManager uploads them on the next
        //    execution opportunity / foreground session. Deterministic stable IDs +
        //    upsert prevent duplicate Supabase rows across repeated deliveries.
        await SyncManager.shared.pushCurrentUserHealthDataNow()
    }

    /// async/await wrapper around the completion-based fetch, used by the
    /// background-delivery pipeline.
    private func fetchWellnessPayloadAsync(for profileId: UUID) async throws -> HealthKitSyncPayload {
        try await withCheckedThrowingContinuation { continuation in
            self.fetchWellnessPayload(for: profileId) { result in
                continuation.resume(with: result)
            }
        }
    }

    func fetchWellnessPayload(for profileId: UUID, completion: @escaping (Result<HealthKitSyncPayload, Error>) -> Void) {
        authorizeHealthKit { [weak self] result in
            guard let self else { return }

            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success:
                self.loadWellnessPayload(profileId: profileId, completion: completion)
            }
        }
    }

    private func loadWellnessPayload(profileId: UUID, completion: @escaping (Result<HealthKitSyncPayload, Error>) -> Void) {
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)
        let startOfRange = calendar.date(byAdding: .day, value: -(daysBack - 1), to: startOfToday) ?? startOfToday

        let group = DispatchGroup()

        var activityDaily: [ActivityDaily] = []
        var activityHourly: [ActivityHourly] = []
        var vitalsDaily: [VitalsDaily] = []
        var vitalsHourly: [VitalsHourly] = []
        var sleepDaily: [SleepDaily] = []

        func logError(_ error: Error?) {
            #if DEBUG
            if let error { print("HealthKit fetch error:", error.localizedDescription) }
            #endif
        }

        group.enter()
        fetchActivityDaily(type: .stepCount, activityType: .steps, unit: .count(), profileId: profileId, startDate: startOfRange, endDate: now) { result, error in
            activityDaily.append(contentsOf: result)
            logError(error)
            group.leave()
        }

        group.enter()
        fetchActivityDaily(type: .activeEnergyBurned, activityType: .calories, unit: .kilocalorie(), profileId: profileId, startDate: startOfRange, endDate: now) { result, error in
            activityDaily.append(contentsOf: result)
            logError(error)
            group.leave()
        }

        group.enter()
        fetchActivityDaily(type: .distanceWalkingRunning, activityType: .distance, unit: .meter(), profileId: profileId, startDate: startOfRange, endDate: now) { result, error in
            activityDaily.append(contentsOf: result)
            logError(error)
            group.leave()
        }

        group.enter()
        fetchActivityHourly(type: .stepCount, activityType: .steps, unit: .count(), profileId: profileId, startDate: startOfToday, endDate: now) { result, error in
            activityHourly.append(contentsOf: result)
            logError(error)
            group.leave()
        }

        group.enter()
        fetchActivityHourly(type: .activeEnergyBurned, activityType: .calories, unit: .kilocalorie(), profileId: profileId, startDate: startOfToday, endDate: now) { result, error in
            activityHourly.append(contentsOf: result)
            logError(error)
            group.leave()
        }

        group.enter()
        fetchActivityHourly(type: .distanceWalkingRunning, activityType: .distance, unit: .meter(), profileId: profileId, startDate: startOfToday, endDate: now) { result, error in
            activityHourly.append(contentsOf: result)
            logError(error)
            group.leave()
        }

        group.enter()
        fetchVitalsDaily(type: .heartRate, vitalType: .heartRate, unit: HKUnit(from: "count/min"), profileId: profileId, startDate: startOfRange, endDate: now) { result, error in
            vitalsDaily.append(contentsOf: result)
            logError(error)
            group.leave()
        }

        group.enter()
        fetchVitalsDaily(type: .heartRateVariabilitySDNN, vitalType: .hrv, unit: HKUnit.secondUnit(with: .milli), profileId: profileId, startDate: startOfRange, endDate: now) { result, error in
            vitalsDaily.append(contentsOf: result)
            logError(error)
            group.leave()
        }


        group.enter()
        fetchVitalsHourly(type: .heartRate, vitalType: .heartRate, unit: HKUnit(from: "count/min"), profileId: profileId, startDate: startOfToday, endDate: now) { result, error in
            vitalsHourly.append(contentsOf: result)
            logError(error)
            group.leave()
        }

        group.enter()
        fetchVitalsHourly(type: .heartRateVariabilitySDNN, vitalType: .hrv, unit: HKUnit.secondUnit(with: .milli), profileId: profileId, startDate: startOfToday, endDate: now) { result, error in
            vitalsHourly.append(contentsOf: result)
            logError(error)
            group.leave()
        }

        group.enter()
        fetchSleepDaily(profileId: profileId, startDate: startOfRange, endDate: now) { result, error in
            sleepDaily = result
            logError(error)
            group.leave()
        }

        group.notify(queue: .main) {

            completion(.success(HealthKitSyncPayload(
                activityDaily: activityDaily.sorted { $0.date > $1.date },
                activityHourly: activityHourly.sorted { $0.hourStart > $1.hourStart },
                vitalsDaily: vitalsDaily.sorted { $0.date > $1.date },
                vitalsHourly: vitalsHourly.sorted { $0.hourStart > $1.hourStart },
                sleepDaily: sleepDaily.sorted { $0.date > $1.date }
            )))
        }
    }

    private func fetchActivityDaily(
        type: HKQuantityTypeIdentifier,
        activityType: ActivityType,
        unit: HKUnit,
        profileId: UUID,
        startDate: Date,
        endDate: Date,
        completion: @escaping ([ActivityDaily], Error?) -> Void
    ) {
        let quantityType = HKQuantityType.quantityType(forIdentifier: type)!
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        var interval = DateComponents()
        interval.day = 1

        let query = HKStatisticsCollectionQuery(
            quantityType: quantityType,
            quantitySamplePredicate: predicate,
            options: [.cumulativeSum, .separateBySource],
            anchorDate: calendar.startOfDay(for: startDate),
            intervalComponents: interval
        )

        query.initialResultsHandler = { [weak self] _, results, error in
            guard let self else { return }
            guard let results else {
                completion([], error)
                return
            }

            var rows: [ActivityDaily] = []
            results.enumerateStatistics(from: startDate, to: endDate) { stats, _ in
                let value = self.dedupedCumulativeValue(stats, unit: unit)
                let day = self.calendar.startOfDay(for: stats.startDate)
                let stableId = self.generateStableId(profileId: profileId, type: activityType.rawValue, date: day)
                rows.append(ActivityDaily(
                    id: stableId,
                    profileId: profileId,
                    type: activityType,
                    value: value,
                    date: day,
                    createdAt: day,
                    lastUpdatedAt: endDate,
                    isSynced: false
                ))
            }

            completion(rows, error)
        }

        healthStore.execute(query)
    }

    private func fetchActivityHourly(
        type: HKQuantityTypeIdentifier,
        activityType: ActivityType,
        unit: HKUnit,
        profileId: UUID,
        startDate: Date,
        endDate: Date,
        completion: @escaping ([ActivityHourly], Error?) -> Void
    ) {
        let quantityType = HKQuantityType.quantityType(forIdentifier: type)!
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        var interval = DateComponents()
        interval.hour = 1

        let query = HKStatisticsCollectionQuery(
            quantityType: quantityType,
            quantitySamplePredicate: predicate,
            options: [.cumulativeSum, .separateBySource],
            anchorDate: startDate,
            intervalComponents: interval
        )

        query.initialResultsHandler = { _, results, error in
            guard let results else {
                completion([], error)
                return
            }

            var rows: [ActivityHourly] = []
            results.enumerateStatistics(from: startDate, to: endDate) { stats, _ in
                let value = self.dedupedCumulativeValue(stats, unit: unit)
                let stableId = self.generateStableId(profileId: profileId, type: activityType.rawValue, date: stats.startDate)
                rows.append(ActivityHourly(
                    id: stableId,
                    profileId: profileId,
                    type: activityType,
                    value: value,
                    hourStart: stats.startDate,
                    sampleCount: value > 0 ? 1 : 0,
                    createdAt: stats.startDate,
                    lastUpdatedAt: endDate,
                    isSynced: false
                ))
            }

            completion(rows, error)
        }

        healthStore.execute(query)
    }

    private func fetchVitalsDaily(
        type: HKQuantityTypeIdentifier,
        vitalType: VitalType,
        unit: HKUnit,
        profileId: UUID,
        startDate: Date,
        endDate: Date,
        completion: @escaping ([VitalsDaily], Error?) -> Void
    ) {
        let quantityType = HKQuantityType.quantityType(forIdentifier: type)!
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        var interval = DateComponents()
        interval.day = 1

        let query = HKStatisticsCollectionQuery(
            quantityType: quantityType,
            quantitySamplePredicate: predicate,
            options: [.discreteAverage, .discreteMin, .discreteMax],
            anchorDate: calendar.startOfDay(for: startDate),
            intervalComponents: interval
        )

        query.initialResultsHandler = { [weak self] _, results, error in
            guard let self else { return }
            guard let results else {
                completion([], error)
                return
            }

            var rows: [VitalsDaily] = []
            results.enumerateStatistics(from: startDate, to: endDate) { stats, _ in
                let min = stats.minimumQuantity()?.doubleValue(for: unit)
                let avg = stats.averageQuantity()?.doubleValue(for: unit)
                let max = stats.maximumQuantity()?.doubleValue(for: unit)
                let day = self.calendar.startOfDay(for: stats.startDate)
                let stableId = self.generateStableId(profileId: profileId, type: vitalType.rawValue, date: day)

                rows.append(VitalsDaily(
                    id: stableId,
                    profileId: profileId,
                    type: vitalType,
                    date: day,
                    minValue: min,
                    avgValue: avg,
                    maxValue: max,
                    createdAt: day,
                    lastUpdatedAt: endDate,
                    isSynced: false
                ))
            }

            completion(rows, error)
        }

        healthStore.execute(query)
    }

    private func fetchVitalsHourly(
        type: HKQuantityTypeIdentifier,
        vitalType: VitalType,
        unit: HKUnit,
        profileId: UUID,
        startDate: Date,
        endDate: Date,
        completion: @escaping ([VitalsHourly], Error?) -> Void
    ) {
        let quantityType = HKQuantityType.quantityType(forIdentifier: type)!
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        var interval = DateComponents()
        interval.hour = 1

        let query = HKStatisticsCollectionQuery(
            quantityType: quantityType,
            quantitySamplePredicate: predicate,
            options: [.discreteAverage, .discreteMin, .discreteMax],
            anchorDate: startDate,
            intervalComponents: interval
        )

        query.initialResultsHandler = { _, results, error in
            guard let results else {
                completion([], error)
                return
            }

            var rows: [VitalsHourly] = []
            results.enumerateStatistics(from: startDate, to: endDate) { stats, _ in
                let min = stats.minimumQuantity()?.doubleValue(for: unit)
                let avg = stats.averageQuantity()?.doubleValue(for: unit)
                let max = stats.maximumQuantity()?.doubleValue(for: unit)
                let stableId = self.generateStableId(profileId: profileId, type: vitalType.rawValue, date: stats.startDate)

                rows.append(VitalsHourly(
                    id: stableId,
                    profileId: profileId,
                    type: vitalType,
                    hourStart: stats.startDate,
                    minValue: min,
                    avgValue: avg,
                    maxValue: max,
                    sampleCount: avg == nil ? 0 : 1,
                    createdAt: stats.startDate,
                    lastUpdatedAt: endDate,
                    isSynced: false
                ))
            }

            completion(rows, error)
        }

        healthStore.execute(query)
    }

    private func fetchSleepDaily(
        profileId: UUID,
        startDate: Date,
        endDate: Date,
        completion: @escaping ([SleepDaily], Error?) -> Void
    ) {
        let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis)!

        // Divide the query into bounded calendar windows (7 days each) so we do not
        // load an unbounded array of 30 days of raw category samples simultaneously.
        var windowRanges: [(start: Date, end: Date)] = []
        var currentWindowStart = startDate
        let windowDays = 7

        while currentWindowStart < endDate {
            let nextStart = calendar.date(byAdding: .day, value: windowDays, to: currentWindowStart) ?? endDate
            let windowEnd = min(nextStart, endDate)
            windowRanges.append((start: currentWindowStart, end: windowEnd))
            currentWindowStart = windowEnd
        }

        guard !windowRanges.isEmpty else {
            completion([], nil)
            return
        }

        struct StageIntervals {
            var deep: [(start: Date, end: Date)] = []
            var rem: [(start: Date, end: Date)] = []
            var light: [(start: Date, end: Date)] = []
            var all: [(start: Date, end: Date)] = []
        }

        var groupedIntervals: [Date: StageIntervals] = [:]
        let lock = NSLock()
        let group = DispatchGroup()
        var fetchError: Error?

        for window in windowRanges {
            group.enter()

            // Sleep sessions often cross midnight into window.start.
            // Querying starting from the previous day's evening ensures no valid session is omitted.
            let queryStart = calendar.date(byAdding: .day, value: -1, to: window.start) ?? window.start
            let predicate = HKQuery.predicateForSamples(withStart: queryStart, end: window.end, options: [])
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

            let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sort]) { [weak self] _, samples, error in
                defer { group.leave() }
                guard let self else { return }
                if let error {
                    lock.lock()
                    fetchError = error
                    lock.unlock()
                    return
                }
                guard let categorySamples = samples as? [HKCategorySample] else { return }

                var localGrouped: [Date: StageIntervals] = [:]

                for sample in categorySamples {
                    guard let stage = self.sleepStage(for: sample.value) else { continue }
                    guard sample.endDate > sample.startDate else { continue }

                    // Sleep session belongs to the day it ends on (standard sleep tracking convention)
                    let sleepDate = self.calendar.startOfDay(for: sample.endDate)

                    // Attribute sample to this window only if its sleepDate falls within this window's bounds.
                    // This strictly prevents duplicate accumulation across adjacent chunk queries.
                    let inBounds: Bool
                    if window.end == endDate {
                        inBounds = sleepDate >= window.start && sleepDate <= self.calendar.startOfDay(for: endDate)
                    } else {
                        inBounds = sleepDate >= window.start && sleepDate < window.end
                    }
                    guard inBounds else { continue }

                    let interval = (start: sample.startDate, end: sample.endDate)
                    var current = localGrouped[sleepDate] ?? StageIntervals()
                    switch stage {
                    case .deep:
                        current.deep.append(interval)
                    case .rem:
                        current.rem.append(interval)
                    case .light:
                        current.light.append(interval)
                    }
                    current.all.append(interval)
                    localGrouped[sleepDate] = current
                }

                lock.lock()
                for (date, intervals) in localGrouped {
                    var existing = groupedIntervals[date] ?? StageIntervals()
                    existing.deep.append(contentsOf: intervals.deep)
                    existing.rem.append(contentsOf: intervals.rem)
                    existing.light.append(contentsOf: intervals.light)
                    existing.all.append(contentsOf: intervals.all)
                    groupedIntervals[date] = existing
                }
                lock.unlock()
            }
            healthStore.execute(query)
        }

        group.notify(queue: .global(qos: .userInitiated)) { [weak self] in
            guard let self else { return }

            var rows: [SleepDaily] = []
            for (date, intervals) in groupedIntervals {
                let mergedDeep = self.mergeOverlappingIntervals(intervals.deep)
                let mergedRem = self.mergeOverlappingIntervals(intervals.rem)
                let mergedLight = self.mergeOverlappingIntervals(intervals.light)
                let mergedAll = self.mergeOverlappingIntervals(intervals.all)

                let totalHours = mergedAll.reduce(0.0) { $0 + $1.end.timeIntervalSince($1.start) } / 3600.0
                let deepHours = min(totalHours, mergedDeep.reduce(0.0) { $0 + $1.end.timeIntervalSince($1.start) } / 3600.0)
                let remHours = min(totalHours - deepHours, mergedRem.reduce(0.0) { $0 + $1.end.timeIntervalSince($1.start) } / 3600.0)
                // To prevent broad unstaged sleep samples (e.g. from an iPhone) from inflating individual stage
                // durations when more specific Apple Watch stages (Deep/REM) overlap, light sleep is computed
                // as the non-deep, non-rem remainder of the unified sleep duration.
                let lightHours = max(0.0, totalHours - deepHours - remHours)

                let earliestStart = mergedAll.first?.start ?? date
                let latestEnd = mergedAll.last?.end ?? date

                let stableId = self.generateStableId(profileId: profileId, type: "sleep", date: date)
                rows.append(SleepDaily(
                    id: stableId,
                    profileId: profileId,
                    date: date,
                    totalSleep: totalHours,
                    deepSleep: deepHours,
                    remSleep: remHours,
                    lightSleep: lightHours,
                    sleepStart: earliestStart,
                    sleepEnd: latestEnd,
                    createdAt: date,
                    lastUpdatedAt: endDate,
                    isSynced: false
                ))
            }

            completion(rows, fetchError)
        }
    }

    /// Merges overlapping and contiguous time intervals to prevent double counting
    /// when multiple devices (e.g. iPhone + Apple Watch) or overlapping samples record the same time period.
    private func mergeOverlappingIntervals(_ intervals: [(start: Date, end: Date)]) -> [(start: Date, end: Date)] {
        guard intervals.count > 1 else { return intervals }
        let sorted = intervals.sorted { $0.start < $1.start }
        var merged: [(start: Date, end: Date)] = [sorted[0]]

        for current in sorted.dropFirst() {
            var last = merged[merged.count - 1]
            if current.start <= last.end {
                last.end = max(last.end, current.end)
                merged[merged.count - 1] = last
            } else {
                merged.append(current)
            }
        }
        return merged
    }

    private enum SleepStage {
        case deep
        case rem
        case light
    }

    /// Maps a HealthKit sleep-analysis category value to our 3-stage model (deep / REM / light).
    ///
    /// Apple's iOS 16+ staging uses Deep, REM, and "Core". In Apple's model **Core IS the
    /// light/base sleep stage** — it is not a separate fourth stage — so `.asleepCore` is
    /// correctly counted as light sleep (#13). `.asleepUnspecified` and the legacy `.asleep`
    /// value are unstaged sleep (e.g. iPhone-only or third-party trackers); we also treat those
    /// as light so the time still counts toward total sleep. Awake / inBed are ignored (`nil`)
    /// so they never inflate total sleep.
    private func sleepStage(for rawValue: Int) -> SleepStage? {
        if #available(iOS 16.0, *) {
            switch HKCategoryValueSleepAnalysis(rawValue: rawValue) {
            case .asleepDeep:
                return .deep
            case .asleepREM:
                return .rem
            case .asleepCore:
                return .light   // Apple "Core" == light sleep
            case .asleepUnspecified, .asleep:
                return .light   // unstaged sleep — counts as light so it isn't lost
            default:
                return nil      // .awake / .inBed / unknown are not sleep
            }
        } else {
            switch HKCategoryValueSleepAnalysis(rawValue: rawValue) {
            case .asleep:
                return .light
            default:
                return nil
            }
        }
    }

    /// Returns a cumulative total for a statistics bucket that guards against
    /// double counting when multiple devices (typically iPhone + Apple Watch) record
    /// overlapping samples for the same period. Requires the owning query to use
    /// `.separateBySource`. With a single source we return the plain total; with
    /// several we take the largest single-source total, which is the conventional
    /// conservative way to avoid inflated step/distance/energy figures.
    private func dedupedCumulativeValue(_ stats: HKStatistics, unit: HKUnit) -> Double {
        let total = stats.sumQuantity()?.doubleValue(for: unit) ?? 0
        guard let sources = stats.sources, sources.count > 1 else { return total }
        let perSource = sources.compactMap { stats.sumQuantity(for: $0)?.doubleValue(for: unit) }
        return perSource.max() ?? total
    }

    // Fixed namespace for deriving FamCare health-row identifiers. Do NOT change:
    // it guarantees the same (profile, type, day) always maps to the same UUID
    // across app launches, reinstalls and devices, which is what keeps Supabase
    // upserts idempotent and prevents duplicate rows.
    private static let healthIdNamespace = UUID(uuidString: "1B4E28BA-2FA1-11D2-883F-0016D3CCA427")!

    /// Deterministic RFC 4122 UUIDv5 (namespace + name, SHA-1) for a health row.
    /// Unlike Swift's `Hasher` (which is seeded randomly per process), this yields
    /// the SAME UUID every time for the same inputs, so re-fetches and multi-device
    /// syncs update one row instead of creating duplicates.
    private func generateStableId(profileId: UUID, type: String, date: Date) -> UUID {
        let dayStart = calendar.startOfDay(for: date)
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate] // YYYY-MM-DD only
        formatter.timeZone = calendar.timeZone
        let dateStr = formatter.string(from: dayStart)
        let name = "\(profileId.uuidString)-\(type)-\(dateStr)"
        return HealthKitService.uuidV5(namespace: HealthKitService.healthIdNamespace, name: name)
    }

    /// Computes a version-5 UUID as defined by RFC 4122 §4.3.
    private static func uuidV5(namespace: UUID, name: String) -> UUID {
        var bytes = [UInt8]()
        bytes.reserveCapacity(16 + name.utf8.count)
        withUnsafeBytes(of: namespace.uuid) { bytes.append(contentsOf: $0) }
        bytes.append(contentsOf: Array(name.utf8))

        var digest = Array(Insecure.SHA1.hash(data: Data(bytes)))
        // Take the first 16 bytes and stamp version (5) and RFC 4122 variant bits.
        digest[6] = (digest[6] & 0x0F) | 0x50
        digest[8] = (digest[8] & 0x3F) | 0x80

        let u = (digest[0], digest[1], digest[2], digest[3],
                 digest[4], digest[5], digest[6], digest[7],
                 digest[8], digest[9], digest[10], digest[11],
                 digest[12], digest[13], digest[14], digest[15])
        return UUID(uuid: u)
    }
    func fetchCumulativeSum(for type: HKQuantityType, from start: Date, to end: Date, completion: @escaping (Double) -> Void) {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        
        let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: [.cumulativeSum, .separateBySource]) { [weak self] _, result, error in
            guard let self, let result = result, result.sumQuantity() != nil else {
                DispatchQueue.main.async { completion(0.0) }
                return
            }
            
            var unit: HKUnit
            if type.identifier == HKQuantityTypeIdentifier.stepCount.rawValue {
                unit = .count()
            } else if type.identifier == HKQuantityTypeIdentifier.activeEnergyBurned.rawValue {
                unit = .kilocalorie()
            } else if type.identifier == HKQuantityTypeIdentifier.distanceWalkingRunning.rawValue {
                unit = .meterUnit(with: .kilo)
            } else {
                unit = .count()
            }
            
            // Same multi-source de-duplication used by the daily/hourly collectors so
            // challenge progress isn't inflated by iPhone + Apple Watch double counting.
            let value = self.dedupedCumulativeValue(result, unit: unit)
            DispatchQueue.main.async {
                completion(value)
            }
        }
        
        healthStore.execute(query)
    }
}
