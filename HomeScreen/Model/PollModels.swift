import Foundation

struct PollData: Codable, Equatable {
    let id: UUID
    let topicId: UUID
    let creatorId: UUID
    var question: String
    var options: [PollOption]
    var allowsMultipleAnswers: Bool
    var createdAt: Date
    
    struct PollOption: Codable, Equatable, Identifiable {
        let id: String
        var text: String
        var voterIds: [UUID]
        
        var voteCount: Int {
            return voterIds.count
        }
    }
    
    var totalVotes: Int {
        return options.reduce(0) { $0 + $1.voterIds.count }
    }
    
    var uniqueVotersCount: Int {
        return Set(options.flatMap { $0.voterIds }).count
    }
    
    static func parse(from content: String) -> PollData? {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("[POLL:") && trimmed.hasSuffix("]") else { return nil }
        let jsonString = String(trimmed.dropFirst("[POLL:".count).dropLast())
        guard let data = jsonString.data(using: .utf8) else { return nil }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let poll = try? decoder.decode(PollData.self, from: data) {
            return poll
        }
        
        // Resilient fallback decoder
        let fallbackDecoder = JSONDecoder()
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        fallbackDecoder.dateDecodingStrategy = .custom { d in
            let container = try d.singleValueContainer()
            let str = try container.decode(String.self)
            if let date = formatter.date(from: str) { return date }
            if let date = ISO8601DateFormatter().date(from: str) { return date }
            return Date()
        }
        return try? fallbackDecoder.decode(PollData.self, from: data)
    }
    
    func encodeToMessageContent() -> String? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(self),
              let jsonString = String(data: data, encoding: .utf8) else { return nil }
        return "[POLL:\(jsonString)]"
    }
    
    mutating func toggleVote(userId: UUID, optionId: String) {
        guard let index = options.firstIndex(where: { $0.id == optionId }) else { return }
        let hasVoted = options[index].voterIds.contains(userId)
        
        if allowsMultipleAnswers {
            if hasVoted {
                options[index].voterIds.removeAll { $0 == userId }
            } else {
                if !options[index].voterIds.contains(userId) {
                    options[index].voterIds.append(userId)
                }
            }
        } else {
            // Single choice
            if hasVoted {
                options[index].voterIds.removeAll { $0 == userId }
            } else {
                for i in 0..<options.count {
                    options[i].voterIds.removeAll { $0 == userId }
                }
                options[index].voterIds.append(userId)
            }
        }
    }
    
    mutating func merge(with other: PollData) {
        for otherOpt in other.options {
            guard let idx = options.firstIndex(where: { $0.id == otherOpt.id }) else { continue }
            for voterId in otherOpt.voterIds {
                if !options[idx].voterIds.contains(voterId) {
                    options[idx].voterIds.append(voterId)
                }
            }
        }
    }
    
    mutating func apply(vote: PollVotePayload) {
        guard vote.pollId == self.id else { return }
        let voterId = vote.voterId
        let selectedSet = Set(vote.selectedOptionIds)
        
        for i in 0..<options.count {
            var voters = options[i].voterIds.filter { $0 != voterId }
            if selectedSet.contains(options[i].id) {
                voters.append(voterId)
            }
            options[i].voterIds = voters
        }
    }
}

struct PollVotePayload: Codable, Equatable {
    let pollId: UUID
    let voterId: UUID
    let selectedOptionIds: [String]
    let timestamp: Date
    
    static func parse(from content: String) -> PollVotePayload? {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("[POLL_VOTE:") && trimmed.hasSuffix("]") else { return nil }
        let jsonString = String(trimmed.dropFirst("[POLL_VOTE:".count).dropLast())
        guard let data = jsonString.data(using: .utf8) else { return nil }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let vote = try? decoder.decode(PollVotePayload.self, from: data) {
            return vote
        }
        
        let fallbackDecoder = JSONDecoder()
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        fallbackDecoder.dateDecodingStrategy = .custom { d in
            let container = try d.singleValueContainer()
            let str = try container.decode(String.self)
            if let date = formatter.date(from: str) { return date }
            if let date = ISO8601DateFormatter().date(from: str) { return date }
            return Date()
        }
        return try? fallbackDecoder.decode(PollVotePayload.self, from: data)
    }
    
    func encodeToMessageContent() -> String? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(self),
              let jsonString = String(data: data, encoding: .utf8) else { return nil }
        return "[POLL_VOTE:\(jsonString)]"
    }
}
