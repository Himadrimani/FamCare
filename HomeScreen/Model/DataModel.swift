import Foundation
import UIKit

struct Profile: Codable {
    let profileId: UUID
    var familyId: UUID

    var firstName: String
    var lastName: String
    var nickName: String?
    var email: String
    var gender: Gender
    var dob: Date
    var profilePic: String
    
    // Kept from previous model as they are physical profile attributes
    var heightCm: Double
    var weightKg: Double
    var timeZone: String
    
    var stepGoal: Int
    var caloriesGoal: Int
    var distanceGoal: Int
    var sleepGoal: Double
    
    var createdAt: Date
    var lastUpdatedAt: Date
    
    var apnsToken: String?
    
    // Customization: Which wellness metrics to show (Steps, Sleep, etc.)
    var visibleMetricIds: [String]?
    
    // Made optional, kept for local offline sync tracking 
    var isSynced: Bool? = nil
    
    // Convenience accessor for display in topic lists and chat
    var displayName: String {
        // A viewer-specific nickname (what the current user calls this person) wins.
        if let personalNick = DataManager.shared.personalNicknames[self.profileId], !personalNick.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return personalNick
        }
        // The profile's own nickname, unless it's the legacy default "Me" (treated as unset).
        if let nickName, !nickName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           nickName.lowercased() != "me" {
            return nickName
        }
        // Default to the first name entered at signup.
        let trimmedFirst = firstName.trimmingCharacters(in: .whitespaces)
        return trimmedFirst.isEmpty ? "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces) : trimmedFirst
    }
}

extension Profile {
    private enum CodingKeys: String, CodingKey {
        case profileId, familyId, firstName, lastName, email, gender, dob, profilePic
        case heightCm, weightKg, timeZone, stepGoal, caloriesGoal, distanceGoal, sleepGoal
        case createdAt, lastUpdatedAt, visibleMetricIds, isSynced, apnsToken
        case nickName = "nickName"
        case nickname = "nickname"
        case nickNameSnakeCase = "nick_name"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        profileId = try container.decode(UUID.self, forKey: .profileId)
        familyId = try container.decode(UUID.self, forKey: .familyId)
        firstName = try container.decode(String.self, forKey: .firstName)
        lastName = try container.decode(String.self, forKey: .lastName)
        nickName = try container.decodeIfPresent(String.self, forKey: .nickName)
            ?? container.decodeIfPresent(String.self, forKey: .nickname)
            ?? container.decodeIfPresent(String.self, forKey: .nickNameSnakeCase)
        email = try container.decode(String.self, forKey: .email)
        gender = try container.decode(Gender.self, forKey: .gender)
        dob = try container.decode(Date.self, forKey: .dob)
        profilePic = try container.decode(String.self, forKey: .profilePic)
        heightCm = try container.decode(Double.self, forKey: .heightCm)
        weightKg = try container.decode(Double.self, forKey: .weightKg)
        timeZone = try container.decode(String.self, forKey: .timeZone)
        stepGoal = try container.decode(Int.self, forKey: .stepGoal)
        caloriesGoal = try container.decode(Int.self, forKey: .caloriesGoal)
        distanceGoal = try container.decode(Int.self, forKey: .distanceGoal)
        sleepGoal = try container.decodeIfPresent(Double.self, forKey: .sleepGoal) ?? 8.0
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        lastUpdatedAt = try container.decode(Date.self, forKey: .lastUpdatedAt)
        visibleMetricIds = try container.decodeIfPresent([String].self, forKey: .visibleMetricIds)
        isSynced = try container.decodeIfPresent(Bool.self, forKey: .isSynced)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(profileId, forKey: .profileId)
        try container.encode(familyId, forKey: .familyId)
        try container.encode(firstName, forKey: .firstName)
        try container.encode(lastName, forKey: .lastName)
        try container.encodeIfPresent(nickName, forKey: .nickName)
        try container.encode(email, forKey: .email)
        try container.encode(gender, forKey: .gender)
        try container.encode(dob, forKey: .dob)
        try container.encode(profilePic, forKey: .profilePic)
        try container.encode(heightCm, forKey: .heightCm)
        try container.encode(weightKg, forKey: .weightKg)
        try container.encode(timeZone, forKey: .timeZone)
        try container.encode(stepGoal, forKey: .stepGoal)
        try container.encode(caloriesGoal, forKey: .caloriesGoal)
        try container.encode(distanceGoal, forKey: .distanceGoal)
        try container.encode(sleepGoal, forKey: .sleepGoal)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(lastUpdatedAt, forKey: .lastUpdatedAt)
        try container.encodeIfPresent(visibleMetricIds, forKey: .visibleMetricIds)
        try container.encodeIfPresent(isSynced, forKey: .isSynced)
    }
}

enum Gender: String, Codable {
    case male, female, others
}

struct Family: Codable {
    let familyId: UUID
    var familyName: String
    var sharableCode: String
    var createdBy: UUID?

    var createdAt: Date
    var lastUpdatedAt: Date

    var isSynced: Bool? = nil
    
    enum CodingKeys: String, CodingKey {
        case familyId, familyName, sharableCode, createdBy, createdAt, lastUpdatedAt, isSynced
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        familyId = try container.decode(UUID.self, forKey: .familyId)
        familyName = try container.decode(String.self, forKey: .familyName)
        sharableCode = try container.decode(String.self, forKey: .sharableCode)
        createdBy = try container.decodeIfPresent(UUID.self, forKey: .createdBy)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        lastUpdatedAt = try container.decode(Date.self, forKey: .lastUpdatedAt)
        isSynced = try container.decodeIfPresent(Bool.self, forKey: .isSynced)
    }

    init(familyId: UUID, familyName: String, sharableCode: String, createdBy: UUID?, createdAt: Date, lastUpdatedAt: Date, isSynced: Bool? = nil) {
        self.familyId = familyId
        self.familyName = familyName
        self.sharableCode = sharableCode
        self.createdBy = createdBy
        self.createdAt = createdAt
        self.lastUpdatedAt = lastUpdatedAt
        self.isSynced = isSynced
    }
}



struct ChallengeDetails: Codable {
    let challengeId: UUID
    let familyId: UUID
    let name: String
    let description: String
    let type: String
    let subType: String
    var status: String
    let bgImage: String
    let startDate: Date
    let endDate: Date
    var lastUpdatedAt: Date
    var isSynced: Bool? = nil
}

struct ChallengeProgress: Codable {
    let challengeId: UUID
    let memberId: UUID
    let goalValue: Double
    var currentValue: Double
    let lastUpdatedAt: Date
    var isSynced: Bool? = nil

    enum CodingKeys: String, CodingKey {
        case challengeId, memberId, goalValue, currentValue, lastUpdatedAt, isSynced
    }
}

struct Message: Codable {
    let messageId: UUID
    let senderId: UUID
    let receiverId: UUID
    let timestampUTC: Date
    let message: String

    var deliveredAt: Date?
    var readAt: Date?

    var lastUpdatedAt: Date
    
    var isSynced: Bool? = nil
}

// MARK: - Legacy Shims for UI Compatibility
// These computed properties allow existing UI components that rely on the old nested
// architecture (e.g. `profile.vitalDaily`) to fetch correctly from the flat buffers.

// Vital Types
enum VitalType: String, Codable {
    case heartRate
    case hrv
    case restingHeartRate
}

// HOURLY
struct VitalsHourly: Codable {
    var id: UUID
    let profileId: UUID
    
    let type: VitalType
    let hourStart: Date
    
    var minValue: Double?
    var avgValue: Double?
    var maxValue: Double?
    var sampleCount: Int
    
    var createdAt: Date
    var lastUpdatedAt: Date
    
    var isSynced: Bool? = nil
}

// DAILY
struct VitalsDaily: Codable {
    var id: UUID
    let profileId: UUID
    
    let type: VitalType
    let date: Date
    
    var minValue: Double?
    var avgValue: Double?
    var maxValue: Double?
    
    var createdAt: Date
    var lastUpdatedAt: Date
    
    var isSynced: Bool? = nil
}

// Activity Types
enum ActivityType: String, Codable {
    case steps
    case calories
    case distance
}

// REAL-TIME UPDATES
struct ActivityCurrent: Codable {
    var id: UUID
    let profileId: UUID

    let type: ActivityType
    var value: Double

    var lastUpdatedAt: Date
    
    var isSynced: Bool? = nil
}

// HOURLY
struct ActivityHourly: Codable {
    var id: UUID
    let profileId: UUID
    
    let type: ActivityType
    var value: Double
    
    let hourStart: Date
    var sampleCount: Int
    
    var createdAt: Date
    var lastUpdatedAt: Date
    
    var isSynced: Bool? = nil
}

// DAILY
struct ActivityDaily: Codable {
    var id: UUID
    let profileId: UUID
    
    let type: ActivityType
    var value: Double
    
    let date: Date
    
    var createdAt: Date
    var lastUpdatedAt: Date
    
    var isSynced: Bool? = nil
}

// SLEEP
struct SleepDaily: Codable {
    var id: UUID
    let profileId: UUID
    
    let date: Date
    
    var totalSleep: Double
    var deepSleep: Double
    var remSleep: Double
    var lightSleep: Double
    
    var sleepStart: Date
    var sleepEnd: Date
    
    var createdAt: Date
    var lastUpdatedAt: Date
    
    var isSynced: Bool? = nil
}


extension Profile {
    var vitalHourly: [VitalsHourly] {
        DataManager.shared.snapshotVitalsHourly(for: self.profileId)
    }
    
    var vitalDaily: [VitalsDaily] {
        DataManager.shared.snapshotVitalsDaily(for: self.profileId)
    }
    
    var activityHourly: [ActivityHourly] {
        DataManager.shared.snapshotActivityHourly(for: self.profileId)
    }
    
    var activityDaily: [ActivityDaily] {
        DataManager.shared.snapshotActivityDaily(for: self.profileId)
    }
    
    var sleep: [SleepDaily] {
        DataManager.shared.snapshotSleepDaily(for: self.profileId)
    }
}



// MARK: - Legacy Property Shims for Flattened Models 

extension ActivityType {
    static let stepCount = ActivityType.steps
    static let caloriesBurned = ActivityType.calories
    static let distanceCovered = ActivityType.distance
}

extension ActivityHourly {
    var activityType: ActivityType { type }
    var dateUTC: Date { hourStart }
    var hourBucket: Int { Calendar.current.component(.hour, from: hourStart) }
}

extension ActivityDaily {
    var activityType: ActivityType { type }
}

extension VitalsHourly {
    var vitalType: VitalType { type }
    var dateUTC: Date { hourStart }
    var hourBucket: Int { Calendar.current.component(.hour, from: hourStart) }
}

extension VitalsDaily {
    var vitalType: VitalType { type }
}

typealias Sleep = SleepDaily

extension SleepDaily {
    var sleepDate: Date { date }
    var sleepStartUTC: Date { sleepStart }
    var sleepEndUTC: Date { sleepEnd }
    
    // Mock legacy converted values (new model holds hours, old used minutes)
    var totalSleepMinutes: Int { Int(totalSleep * 60) }
    var deepSleepMinutes: Int { Int(deepSleep * 60) }
    var remSleepMinutes: Int { Int(remSleep * 60) }
    var lightSleepMinutes: Int { Int(lightSleep * 60) }
    var awakeMinutes: Int { 
        // Derived or fixed value for UI compatibility
        let otherStages = deepSleepMinutes + remSleepMinutes + lightSleepMinutes
        return max(0, totalSleepMinutes - otherStages)
    }
}



struct NotificationItem: Codable {
    let id: UUID
    let title: String
    let body: String
    let timestamp: Date
    let type: NotificationType
    var isRead: Bool
    let relatedProfileId: UUID?
}

enum NotificationType: String, Codable {
    case performanceAlert
    case challengeSuggestion
    case goalAchieved
    case general
}
import Foundation

struct GoalCalculator {
    static func calculateGoals(dob: Date, gender: Gender) -> (steps: Int, calories: Int, distance: Int, sleep: Double) {
        let ageComponents = Calendar.current.dateComponents([.year], from: dob, to: Date())
        let age = ageComponents.year ?? 30
        
        var steps = 10000
        var calories = 400
        var distance = 6500
        var sleep = 8.0
        
        // Age based logic
        if age < 18 {
            steps = 10000
            sleep = 9.0
            calories = (gender == .male) ? 600 : 500
            distance = (gender == .male) ? 7000 : 6000
        } else if age >= 65 {
            steps = 7000
            sleep = 7.5
            calories = (gender == .male) ? 400 : 300
            distance = (gender == .male) ? 5000 : 4500
        } else {
            // Adults (18-64)
            steps = 10000
            sleep = 8.0
            calories = (gender == .male) ? 600 : 400
            distance = (gender == .male) ? 7500 : 6500
        }
        
        return (steps, calories, distance, sleep)
    }
}
