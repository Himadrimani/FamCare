import Foundation
import Supabase

func testInvoke() async throws {
    let body = ["hello": "world"]
    let response = try await SupabaseManager.shared.client.functions.invoke("ai_assistant", options: FunctionInvokeOptions(body: body))
}
