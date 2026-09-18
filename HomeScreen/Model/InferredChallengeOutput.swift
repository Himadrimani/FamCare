import Foundation
import FoundationModels

@Generable
struct InferredChallengeOutput {
    @Guide(description: "The generated concise title name of the challenge parsed from the user's input phrase.")
    let name: String
    
    @Guide(description: "A detailed summary description of what participants must accomplish in this challenge.")
    let description: String?
    
    @Guide(description: "The trackable metric parameter underlying the challenge. Must be exactly one of these options.", .anyOf(["steps", "caloriesBurned", "distance", "custom"]))
    let subType: String
    
    @Guide(description: "The numeric target goal value per individual member (e.g., 10000 for steps, 15 for distance). For social tasks, this must always default to 1.0.")
    let goalValue: Double
    
    @Guide(description: "The requested timeframe of the challenge measured strictly in total number of whole days.")
    let durationDays: Int
    
    @Guide(description: "An array listing the exact first names of family members explicitly mentioned or requested in the input prompt text.")
    let participantNames: [String]
}
