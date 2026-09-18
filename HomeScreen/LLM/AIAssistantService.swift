import Foundation

class AIAssistantService {
    static let shared = AIAssistantService()
    private init() {}
    
    private let edgeFunctionUrl = "https://bypxwhpopgcbxbwiyaym.supabase.co/functions/v1/ai_assistant"
    
    private let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJ5cHh3aHBvcGdjYnhid2l5YXltIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODYwMzE5NTAsImV4cCI6MjEwMTYwNzk1MH0.j7Ni96zGO-3Xq9fMrEjgMq5ToRky4wQxX8xmCFuw6NA"
    
    /// Sends the user's conversation (with health context injected) to the edge function.
    /// Returns the AI's response message.
    func sendMessage(userMessages: [AIAssistantMessage]) async throws -> AIAssistantMessage {
        // 1. Build the health data context
        let healthContext = AssistantDataProvider.buildContext()
        
        // 2. Construct the messages array:
        //    - First message: context (as a user message with a system prefix)
        //    - Then: the actual user conversation
        let contextMessage = AIAssistantMessage(
            role: "user",
            content: "[SYSTEM CONTEXT — This is the user's real health data. Use it to answer questions. Do NOT repeat this raw data back to the user. Summarize naturally and conversationally.]\n\n\(healthContext)"
        )
        
        // We need to pair the context message with an acknowledgment so the
        // conversation alternates user/assistant properly for Gemini
        let contextAck = AIAssistantMessage(
            role: "assistant",
            content: "I have the family health data. I'll use it to answer questions naturally."
        )
        
        var fullMessages = [contextMessage, contextAck]
        fullMessages.append(contentsOf: userMessages)
        
        // 3. Build the HTTP request
        guard let url = URL(string: edgeFunctionUrl) else {
            throw AIAssistantError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30
        
        let requestBody = AIAssistantRequest(messages: fullMessages)
        request.httpBody = try JSONEncoder().encode(requestBody)
        
        // 4. Execute
        let (data, response) = try await URLSession.shared.data(for: request)
        
        // 5. Validate HTTP response
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIAssistantError.networkError("Invalid response from server")
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            // Try to extract error message from response body
            if let errorResponse = try? JSONDecoder().decode(AIAssistantResponse.self, from: data),
               let errorMsg = errorResponse.error {
                throw AIAssistantError.serverError(errorMsg)
            }
            throw AIAssistantError.httpError(httpResponse.statusCode)
        }
        
        // 6. Decode response
        let result: AIAssistantResponse
        do {
            result = try JSONDecoder().decode(AIAssistantResponse.self, from: data)
        } catch {
            // Log the raw response for debugging
            let rawString = String(data: data, encoding: .utf8) ?? "(unable to decode)"
            print("AI Assistant: Failed to decode response: \(rawString)")
            throw AIAssistantError.decodingError
        }
        
        guard let message = result.message else {
            throw AIAssistantError.emptyResponse
        }
        
        return message
    }
}

// MARK: - Error Types

enum AIAssistantError: LocalizedError {
    case invalidURL
    case networkError(String)
    case httpError(Int)
    case serverError(String)
    case decodingError
    case emptyResponse
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid service URL."
        case .networkError(let msg):
            return "Network error: \(msg)"
        case .httpError(let code):
            return "Server returned error \(code). Please try again."
        case .serverError(let msg):
            return msg
        case .decodingError:
            return "Unexpected response format. Please try again."
        case .emptyResponse:
            return "The AI returned an empty response. Please try again."
        }
    }
}
