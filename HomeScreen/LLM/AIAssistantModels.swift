import Foundation

// MARK: - Message Models

struct AIAssistantMessage: Codable {
    let role: String       // "user", "assistant"
    let content: String?
    
    // Tool call fields (for create_challenge / create_message_group actions)
    let tool_calls: [ToolCall]?
    
    init(role: String, content: String?, tool_calls: [ToolCall]? = nil) {
        self.role = role
        self.content = content
        self.tool_calls = tool_calls
    }
}

struct ToolCall: Codable {
    let id: String
    let type: String
    let function: ToolFunction
}

struct ToolFunction: Codable {
    let name: String
    let arguments: String // JSON string
}

// MARK: - Request / Response

struct AIAssistantRequest: Codable {
    let messages: [AIAssistantMessage]
}

struct AIAssistantResponse: Codable {
    let message: AIAssistantMessage?
    let error: String?
}

// MARK: - Tool Argument Models (for client-side action handling)

struct CreateChallengeArgs: Codable {
    let challengeName: String
    let description: String?
    let metric: String
    let goalValue: Double
    let durationDays: Int
    let participants: [String]
}

struct CreateMessageGroupArgs: Codable {
    let groupName: String
    let participants: [String]
}
