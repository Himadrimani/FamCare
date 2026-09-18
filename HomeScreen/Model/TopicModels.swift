import Foundation
import UIKit

struct TopicProfile: Codable, Identifiable, Hashable {
    let id: UUID
    let name: String
    let petName: String
    let familyId: UUID
    let email: String
    let avatarUrl: String?

    var displayName: String {
        petName.isEmpty ? name : petName
    }
}

// Isolated from potentially existing 'Topic' to prevent conflicts.
struct Topic: Codable, Identifiable, Hashable {
    let id: UUID
    let createdBy: UUID?
    let title: String
    let createdAt: Date?
    var isSynced: Bool? = nil

    enum CodingKeys: String, CodingKey {
        case id, title, createdBy, createdAt, isSynced
    }
}

struct TopicMember: Codable, Identifiable, Hashable {
    let id: UUID
    let topicId: UUID
    let userId: UUID

    var isSynced: Bool? = nil

    enum CodingKeys: String, CodingKey {
        case id, topicId, userId, isSynced
        // Handle alternate key names from backup JSON
        case topicIdAlt = "topic_id"
        case userIdAlt = "user_id"
    }

    init(id: UUID, topicId: UUID, userId: UUID, isSynced: Bool? = nil) {
        self.id = id
        self.topicId = topicId
        self.userId = userId
        self.isSynced = isSynced
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        // Try camelCase first, fall back to snake_case
        if let tid = try? c.decode(UUID.self, forKey: .topicId) {
            topicId = tid
        } else {
            topicId = (try? c.decode(UUID.self, forKey: .topicIdAlt)) ?? UUID()
        }
        if let uid = try? c.decode(UUID.self, forKey: .userId) {
            userId = uid
        } else {
            userId = (try? c.decode(UUID.self, forKey: .userIdAlt)) ?? UUID()
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(topicId, forKey: .topicId)
        try c.encode(userId, forKey: .userId)
        // Note: isSynced is intentionally excluded from encoding.
        // It is a local-only SQLite flag and does NOT exist as a column in Supabase.
        // Sending it causes Supabase upsert failures (unknown column).
    }
}

// Isolated from existing 'Message' to prevent conflicts.
struct TopicMessage: Codable, Identifiable, Hashable {
    let id: UUID
    let topicId: UUID
    let senderId: UUID
    let content: String
    let createdAt: Date?
    var isSynced: Bool? = nil

    enum CodingKeys: String, CodingKey {
        case id, content, isSynced, topicId, senderId, createdAt
    }
}

struct UserRelationshipNickname: Codable, Hashable {
    let viewerId: UUID
    let targetId: UUID
    let nickname: String
    
    // Must match the exact quoted column names in Supabase: "viewerId", "targetId", "nickname"
    enum CodingKeys: String, CodingKey {
        case viewerId = "viewerId"
        case targetId = "targetId"
        case nickname = "nickname"
    }
}

extension String {
    // Calculates the rendered height of this string when constrained to a given width and font.
    // Used by sizeForItemAt to make each message bubble exactly tall enough for its text.
    // Includes a descender-safe buffer so letters like g, y, p, q are never clipped.
    func height(withConstrainedWidth width: CGFloat, font: UIFont) -> CGFloat {
        let constraintRect = CGSize(width: width, height: .greatestFiniteMagnitude)
        let boundingBox = self.boundingRect(
            with: constraintRect,
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font],
            context: nil
        )
        // Add a small buffer (2pt) to prevent descender clipping on letters like g, y, p, q
        return ceil(boundingBox.height) + 2
    }
}
