import Foundation

public enum HealthMetricType: String, Codable, CaseIterable {
    case steps = "steps"
    case calories = "calories"
    case distance = "distance"
    case heartRate = "heartRate"
    case hrv = "hrv"
    case sleep = "sleep"
    case summary = "summary"
    
    public var displayName: String {
        switch self {
        case .steps: return "Steps"
        case .calories: return "Calories"
        case .distance: return "Distance"
        case .heartRate: return "Heart Rate"
        case .hrv: return "HRV"
        case .sleep: return "Sleep"
        case .summary: return "Wellness Summary"
        }
    }
}

public enum HealthPermissionLevel: String, Codable, CaseIterable {
    case none = "none"
    case summaryOnly = "summary_only"
    case fullDetail = "full_detail"
}

public struct FamilyHealthPermission: Codable, Identifiable, Equatable {
    public let id: UUID
    public let familyId: UUID
    public let ownerProfileId: UUID
    public let viewerProfileId: UUID
    public let metricType: String
    public var permissionLevel: String
    public var isAllowed: Bool
    public let createdAt: Date?
    public var updatedAt: Date?
    public var expiresAt: Date?
    
    public init(
        id: UUID = UUID(),
        familyId: UUID,
        ownerProfileId: UUID,
        viewerProfileId: UUID,
        metricType: String,
        permissionLevel: String = "summary_only",
        isAllowed: Bool = true,
        createdAt: Date? = Date(),
        updatedAt: Date? = Date(),
        expiresAt: Date? = nil
    ) {
        self.id = id
        self.familyId = familyId
        self.ownerProfileId = ownerProfileId
        self.viewerProfileId = viewerProfileId
        self.metricType = metricType
        self.permissionLevel = permissionLevel
        self.isAllowed = isAllowed
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.expiresAt = expiresAt
    }
}
