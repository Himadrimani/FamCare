import Foundation
import Supabase

class SupabaseManager {
    static let shared = SupabaseManager()

    // TODO: Replace with your actual Supabase URL and Anon Key
    /// Custom URL scheme used for auth deep links (e.g. password-reset email links).
    /// Must match the CFBundleURLSchemes entry in Info.plist and the Redirect URL
    /// allow-list in the Supabase dashboard (URL Configuration).
    static let passwordResetRedirectURL = URL(string: "homescreenapp://reset-password")!

    let client = SupabaseClient(
        supabaseURL: URL(string: "https://bypxwhpopgcbxbwiyaym.supabase.co")!,
        supabaseKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJ5cHh3aHBvcGdjYnhid2l5YXltIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODYwMzE5NTAsImV4cCI6MjEwMTYwNzk1MH0.j7Ni96zGO-3Xq9fMrEjgMq5ToRky4wQxX8xmCFuw6NA",
        options: SupabaseClientOptions(
            auth: SupabaseClientOptions.AuthOptions(
                redirectToURL: SupabaseManager.passwordResetRedirectURL,
                emitLocalSessionAsInitialSession: true
            )
        )
    )

    private init() {}
}
