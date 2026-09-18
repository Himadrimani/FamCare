import Foundation
import Supabase

let client = SupabaseClient(
    supabaseURL: URL(string: "https://bypxwhpopgcbxbwiyaym.supabase.co")!,
    supabaseKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJ5cHh3aHBvcGdjYnhid2l5YXltIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODYwMzE5NTAsImV4cCI6MjEwMTYwNzk1MH0.j7Ni96zGO-3Xq9fMrEjgMq5ToRky4wQxX8xmCFuw6NA"
)

struct FamilyDTO: Encodable {
    let familyId: UUID
    let familyName: String
    let sharableCode: String
    let createdBy: UUID?
    let createdAt: String
    let lastUpdatedAt: String
    let isSynced: Bool?
}

struct ProfileDTO: Encodable {
    let profileId: UUID
    let familyId: UUID
    let firstName: String
    let lastName: String
    let nickName: String?
    let email: String
    let gender: String
    let dob: String
    let profilePic: String
    let heightCm: Double
    let weightKg: Double
    let timeZone: String
    let stepGoal: Int
    let caloriesGoal: Int
    let distanceGoal: Int
    let createdAt: String
    let lastUpdatedAt: String
    let isSynced: Bool?
}

Task {
    do {
        let email = "test\(UUID().uuidString.prefix(8))@mail.com"
        let res = try await client.auth.signUp(email: email, password: "password123")
        let userId = res.user.id
        let familyId = UUID()
        
        let familyDTO = FamilyDTO(
            familyId: familyId,
            familyName: "Test Family",
            sharableCode: "123456",
            createdBy: userId,
            createdAt: "2026-08-01T00:00:00Z",
            lastUpdatedAt: "2026-08-01T00:00:00Z",
            isSynced: true
        )
        
        let profileDTO = ProfileDTO(
            profileId: userId,
            familyId: familyId,
            firstName: "Test",
            lastName: "User",
            nickName: "Tester",
            email: email,
            gender: "male",
            dob: "2000-01-01",
            profilePic: "person.circle",
            heightCm: 180,
            weightKg: 80,
            timeZone: "UTC",
            stepGoal: 10000,
            caloriesGoal: 2000,
            distanceGoal: 5,
            createdAt: "2026-08-01T00:00:00Z",
            lastUpdatedAt: "2026-08-01T00:00:00Z",
            isSynced: true
        )
        
        print("Inserting family...")
        try await client.from("Families").insert(familyDTO).execute()
        print("Inserted family successfully")
        
        print("Inserting profile...")
        try await client.from("Profiles").insert(profileDTO).execute()
        print("Inserted profile successfully")
    } catch {
        print("Error: \(error)")
    }
    exit(0)
}

RunLoop.main.run()
