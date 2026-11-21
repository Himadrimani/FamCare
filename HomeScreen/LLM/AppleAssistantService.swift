import Foundation
import FoundationModels

@available(iOS 18.0, *)
class AppleAssistantService {
    static let shared = AppleAssistantService()
    
    private init() {}
    
    private let systemPrompt = """
    You are the FamCare AI Assistant, a helpful and empathetic family health companion.

    IMPORTANT RULES:
    1. The user's real health data is provided in the first message of each conversation. Use it to answer questions accurately — NEVER invent or guess health numbers.
    2. Responses MUST be crisp, concise, and easy to read. Keep responses short (1-3 sentences) and directly relevant. Provide only the most important information and key numbers. Avoid repeating information that is already visible in the UI.
    3. Do NOT ask a question at the end of the response. Do NOT add unnecessary follow-up suggestions like "How would you like to..." or "Would you like me to...".
    4. If the user asks to create a challenge, you MUST ALWAYS use the 'create_challenge' tool. Never fake the creation by just replying with text. If they don't specify all details, make reasonable assumptions (e.g., 7 days, 10000 steps, include "me"). IMPORTANT: Do NOT paste your AI-generated conversational response into the user's text input fields like 'description' or 'challengeName'. The 'description' field is strictly for the challenge description itself. If the user provides a description for the challenge, you MUST pass it in exactly as they said it. If they don't provide a description, set the description to be the same as the challengeName.
    5. You are responsible for understanding family challenge creation requests. First determine whether the requested challenge is based on one of the four supported health metrics: Steps, Distance, Calories Burned, or Sleep.
       Only metric-based challenges belonging to these four categories (Steps, Distance, Calories Burned, Sleep) should be routed to the modification screen.
       For all other challenges related to family/recreation/emotional wellness (such as Meditation, Family movie night, Family dinner, Evening family walk, Family bonding, Relaxation, and other similar activities), they must bypass the modification screen and proceed directly to the Create/Cancel confirmation alert.
       CRITICAL: You MUST use the 'create_challenge' tool for these recreational challenges. Do not just say you created it without using the tool.
       When you use the 'create_challenge' tool for a recreational/family challenge, you MUST leave your conversational text response completely empty. Do not output any text at all. The system will automatically handle the success message after the user confirms.
       Do not classify a challenge as metric-based merely because it contains a number or involves walking/activity. Classify it based on the actual purpose of the challenge.
       For example:
       - 'Walk 5 km' → Distance metric (modification screen).
       - 'Get 10,000 steps' → Steps metric (modification screen).
       - 'Burn 500 calories' → Calories Burned metric (modification screen).
       - 'Sleep 8 hours' → Sleep metric (modification screen).
       - 'Go for a 5 km evening walk with the family' → if the primary intent is a family/recreation activity rather than tracking Distance as a health metric, treat it as a non-metric family challenge (direct Create/Cancel confirmation).
       - 'Meditation' → non-metric (direct Create/Cancel confirmation).
       - 'Family movie night' → non-metric (direct Create/Cancel confirmation).
       - 'Relaxation' → non-metric (direct Create/Cancel confirmation).
       The primary intent of the user's request must determine the category. If the user provides a count for a non-metric challenge (e.g. 'Watch 2 movies'), use that as the goalValue. Do not invent a metric target when the user has not provided one.
    6. If the user asks to create a message group, use the 'create_message_group' tool.
    7. Always frame health data as general wellness information, never as medical advice.
    8. Be warm, supportive, and use simple, natural language. Use emojis sparingly (1-2 per message max). Avoid long paragraphs or unnecessary explanations.
    """
    
    func sendMessage(userMessages: [AIAssistantMessage]) async throws -> AIAssistantMessage {
        guard SystemLanguageModel.default.availability == .available else {
            throw AppleAssistantError.notAvailable
        }
        
        let tools: [any Tool] = [CreateChallengeTool(), CreateMessageGroupTool()]
        
        // 1. Build compact, real-time health data context
        let healthContext = AssistantDataProvider.buildContext()
        
        let fullInstructions = """
        \(systemPrompt)
        
        CURRENT FAMILY HEALTH DATA SNAPSHOT:
        \(healthContext)
        """
        
        let session: LanguageModelSession
        do {
            // Fresh session per interaction ensures internal session memory is bounded and never leaks past turns
            session = try await LanguageModelSession(
                tools: tools,
                instructions: fullInstructions
            )
        } catch {
            throw AppleAssistantError.serverError("Unable to initialize AI session: \(error.localizedDescription)")
        }
        
        // 2. Sliding window: bounded to the last 4 messages (e.g., prior Q&A + latest question)
        // to maintain conversational flow and follow-ups while strictly keeping tokens under ~1,500 (ceiling is 8,192).
        let recentMessages = userMessages.suffix(4)
        
        var promptText = ""
        for msg in recentMessages {
            let role = msg.role == "user" ? "User" : "Assistant"
            if let content = msg.content, !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                promptText += "\(role): \(content)\n"
            }
        }
        
        let promptToSend = promptText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !promptToSend.isEmpty else {
            return AIAssistantMessage(role: "assistant", content: "How can I help you today?")
        }
        
        var responseContent = ""
        do {
            let result = try await session.respond(to: promptToSend)
            responseContent = result.content
        } catch {
            throw AppleAssistantError.serverError(error.localizedDescription)
        }
        
        return AIAssistantMessage(role: "assistant", content: responseContent)
    }
}

// MARK: - Error
enum AppleAssistantError: LocalizedError {
    case notAvailable
    case serverError(String)
    
    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "Apple Intelligence is not available on this device."
        case .serverError(let msg):
            return msg
        }
    }
}

// MARK: - Tools

@available(iOS 18.0, *)
struct CreateChallengeTool: Tool {
    let name = "create_challenge"
    let description = "Creates a new health/wellness challenge in the app."
    
    @Generable struct Arguments {
        @Guide(description: "A catchy name for the challenge")
        let challengeName: String
        
        @Guide(description: "A description for the challenge. Do NOT put your conversational response here. If the user provides one, use their exact words. Otherwise, set it to be the exact same as challengeName.")
        let description: String?
        
        @Guide(description: "The metric to track: steps, caloriesBurned, distance, or custom.")
        let metric: String
        
        @Guide(description: "The target goal value per person (e.g. 10000 for steps).")
        let goalValue: Double
        
        @Guide(description: "Duration in days (e.g. 7).")
        let durationDays: Int
        
        @Guide(description: "List of family member names or 'me'.")
        let participants: [String]
    }
    
    func call(arguments: Arguments) async throws -> String {
        let args = CreateChallengeArgs(
            challengeName: arguments.challengeName,
            description: arguments.description,
            metric: arguments.metric,
            goalValue: arguments.goalValue,
            durationDays: arguments.durationDays,
            participants: arguments.participants
        )
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: .didInvokeCreateChallenge,
                object: nil,
                userInfo: ["args": args]
            )
        }
        return "Challenge created."
    }
}

@available(iOS 18.0, *)
struct CreateMessageGroupTool: Tool {
    let name = "create_message_group"
    let description = "Creates a new message group for family communication."
    
    @Generable struct Arguments {
        @Guide(description: "Name of the group.")
        let groupName: String
        
        @Guide(description: "List of family member names to include.")
        let participants: [String]
    }
    
    func call(arguments: Arguments) async throws -> String {
        let args = CreateMessageGroupArgs(
            groupName: arguments.groupName,
            participants: arguments.participants
        )
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: .didInvokeCreateMessageGroup,
                object: nil,
                userInfo: ["args": args]
            )
        }
        return "Message group created."
    }
}

// MARK: - Notifications
extension Notification.Name {
    static let didInvokeCreateChallenge = Notification.Name("didInvokeCreateChallenge")
    static let didInvokeCreateMessageGroup = Notification.Name("didInvokeCreateMessageGroup")
}
