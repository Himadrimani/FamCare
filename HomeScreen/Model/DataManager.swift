import Foundation
import UIKit
import Supabase
import Auth
import UserNotifications

final class DataManager {
    static let shared = DataManager()
    private init() {}

    private let bootstrapQueue = DispatchQueue(label: "com.homescreen.datamanager.bootstrap", qos: .userInitiated)

    var currentUser: Profile?
    var family: Family?
    var allProfiles: [Profile] = []
    var messages: [Message] = []
    var challenges: [ChallengeDetails] = []
    var challengeProgress: [ChallengeProgress] = []
    
    // Topic feature data buffers
    var topics: [Topic] = []
    var topicMembers: [TopicMember] = []
    var topicMessages: [TopicMessage] = []

    // global flattened data buffers
    var allVitalsHourly: [VitalsHourly] = []
    var allVitalsDaily: [VitalsDaily] = []
    var allActivityHourly: [ActivityHourly] = []
    var allActivityDaily: [ActivityDaily] = []
    var allSleepDaily: [SleepDaily] = []

    // Serializes all access to the in-memory health buffers above. They are read from the
    // Insight UI (main thread) and mutated by lazy hydration / background sync, so without
    // this lock a concurrent mutation during enumeration can crash (#7). Recursive so a
    // snapshot accessor can hold the lock while it calls `ensureHealthDataLoaded`.
    private let healthBufferLock = NSRecursiveLock()

    // Lazy-loading guards to avoid eager full-table reads on startup.
    private var hasLoadedDirectMessages = false
    private var hasLoadedTopics = false
    private var loadedTopicMemberTopicIds: Set<UUID> = []
    private var loadedTopicMessageTopicIds: Set<UUID> = []
    private var loadedHealthProfileIds: Set<UUID> = []
    private var profilePictureMigrationInFlight: Set<UUID> = []
    private var hasDisabledProfilePictureMigration = false

    private let migrationKey = "isDataMigratedToSQLite"
    private let currentUserIdKey = "DataManagerCurrentUserId"
    private let healthSyncResetKey = "healthSyncFlagsResetDone"
    private let healthKitLinkedProfileIdKey = "HealthKitLinkedProfileId"
    private var isRefreshingCurrentUserHealth = false

    // Relative identity/naming buffer
    var personalNicknames: [UUID: String] = [:]
    
    #if DEBUG
    // DEBUG-only test helpers. These are compiled out of release (App Store) builds so they
    // can never be used to bypass authentication or impersonate an identity in production.

    // For testing: set this to a name (e.g. "anil") or email to force the app to login as them.
    var testingOverrideIdentity: String? = ""

    // Bootstrap anchor: paste any profile's UUID here to seed the app from Supabase
    // when SQLite is empty (fresh install, simulator reset, etc.).
    // Set to nil to disable. Also acts as a profile switcher for testing.
    var bootstrapUserId: String? = nil  // e.g. "A1B2C3D4-..."
    #endif

    private let migrationVersion = 3  // Bump this number to force a fresh re-migration

    private struct AppBootstrapSnapshot {
        let currentUser: Profile?
        let family: Family?
        let allProfiles: [Profile]
        let personalNicknames: [UUID: String]
        let challenges: [ChallengeDetails]
        let challengeProgress: [ChallengeProgress]
        let profilesCount: Int

        var hasEssentialData: Bool {
            profilesCount > 0 || !challenges.isEmpty
        }
    }

    enum AuthenticationError: LocalizedError {
        /// The account was created but Supabase returned no session because email
        /// confirmation is required. The user must verify their email before logging in.
        case emailConfirmationRequired
        case emailAlreadyRegistered
        /// Credentials were valid but no application profile exists for this user.
        case profileNotFound
        case invalidName

        var errorDescription: String? {
            switch self {
            case .emailConfirmationRequired:
                return "Account created. Please check your email and confirm your address, then log in."
            case .emailAlreadyRegistered:
                return "This email is already registered. Please try another email or log in."
            case .profileNotFound:
                return "We couldn't find your FamCare profile. Please sign up to finish setting up your account."
            case .invalidName:
                return "Enter your full name."
            }
        }
    }

    /// Signs the user in against the REAL Supabase Auth backend.
    ///
    /// Fail-closed by design: invalid credentials, unknown accounts, network failures,
    /// or a missing profile all throw. There is NO local/offline fallback and no
    /// fabricated profile — the Supabase session is the only source of truth.
    @discardableResult
    func signIn(email: String, password: String) async throws -> Profile {
        let normalizedEmail = normalizeEmail(email)

        // 1. Authenticate first. Throws on invalid credentials / offline / timeout.
        let session = try await SupabaseManager.shared.client.auth.signIn(
            email: normalizedEmail,
            password: password
        )
        let authUserId = session.user.id

        // 2. Fetch the profile (network) BEFORE touching local data. A transient failure
        //    here must never wipe the user's offline cache or eject them — so we fetch
        //    without persisting yet.
        guard let profile = try await loadProfileForAuthenticatedUser(userId: authUserId, persistLocally: false) else {
            // Valid login but no application profile. Fail safely; never fabricate one.
            try? await SupabaseManager.shared.client.auth.signOut()
            clearCurrentUser()
            throw AuthenticationError.profileNotFound
        }

        // 3. Profile confirmed. Only now is it safe to reset the local cache for the
        //    incoming user and persist the new identity. Persisting is best-effort: if it
        //    fails, SyncManager backfills from the server on load rather than ejecting the
        //    user. (A failed sign-in or missing profile never touches local data.)
        SQLiteHelper.shared.clearAllData()
        try? await saveIdentityLocally(profile: profile)

        setCurrentUser(profileId: profile.profileId)
        return profile
    }
    func signInWithApple(idToken: String, nonce: String, fullName: String?) async throws -> (profile: Profile?, sessionUser: Supabase.User) {
        // 1. Authenticate with Apple ID token
        let session = try await SupabaseManager.shared.client.auth.signInWithIdToken(
            credentials: .init(provider: .apple, idToken: idToken, nonce: nonce)
        )
        let authUserId = session.user.id
        
        // 2. Try to load the profile
        if let profile = try await loadProfileForAuthenticatedUser(userId: authUserId, persistLocally: false) {
            SQLiteHelper.shared.clearAllData()
            try? await saveIdentityLocally(profile: profile)
            setCurrentUser(profileId: profile.profileId)
            return (profile, session.user)
        } else {
            // Profile doesn't exist yet, return nil profile but include the user so UI can handle signup
            return (nil, session.user)
        }
    }


    @discardableResult
    func signUp(fullName: String, email: String, password: String, dob: Date, heightCm: Double, weightKg: Double, gender: Gender, profilePicUrl: String?, targetFamily: Family? = nil) async throws -> Profile {
        let normalizedEmail = normalizeEmail(email)
        let nameParts = splitName(fullName)

        guard !nameParts.firstName.isEmpty else {
            throw AuthenticationError.invalidName
        }
        
        // Wipe local database before creating a new user to prevent stale mock data mixing
        SQLiteHelper.shared.clearAllData()

        let response = try await SupabaseManager.shared.client.auth.signUp(email: normalizedEmail, password: password)
        let user = response.user
        let authUserId = user.id

        // Supabase returns a user with an empty `identities` array when the email is
        // already registered (email-enumeration protection). Treat that as a duplicate
        // account so we can show a clear "already registered" message instead of a
        // confusing "verify your email" prompt.
        if user.identities?.isEmpty == true {
            throw AuthenticationError.emailAlreadyRegistered
        }

        // If email confirmation is enabled in the Supabase dashboard, signUp returns a
        // user but no session. Do NOT treat this as fully authenticated — tell the user
        // to confirm their email. (With confirmations disabled, a session is returned.)
        guard response.session != nil else {
            throw AuthenticationError.emailConfirmationRequired
        }

        // Idempotent: if a profile already exists for this UUID, reuse it (no duplicate).
        if let existingProfile = try await loadProfileForAuthenticatedUser(userId: authUserId) {
            setCurrentUser(profileId: existingProfile.profileId)
            return existingProfile
        }

        do {
            let profile = try await createProfileForSignedUpUser(
                profileId: authUserId,
                firstName: nameParts.firstName,
                lastName: nameParts.lastName,
                email: normalizedEmail,
                dob: dob,
                heightCm: heightCm,
                weightKg: weightKg,
                gender: gender,
                profilePicUrl: profilePicUrl,
                targetFamily: targetFamily
            )
            setCurrentUser(profileId: profile.profileId)
            return profile
        } catch {
            // The auth account was created but profile/family setup failed (e.g. a transient
            // network drop). Without cleanup the user would be permanently locked out: they
            // can't log in (no profile) and can't sign up again (email "already registered").
            // Roll back the just-created auth account so the email is freed and they can retry.
            // Best-effort — the delete runs while this brand-new session is still valid.
            try? await SupabaseManager.shared.client.functions.invoke("delete-user")
            try? await SupabaseManager.shared.client.auth.signOut()
            clearCurrentUser()
            throw error
        }
    }

    /// Loads the application profile for the authenticated user, keyed by the Supabase
    /// Auth UUID (`profileId == auth.uid()` in this project). Email is never used as the
    /// primary lookup key, so email casing/changes can't strand a valid session.
    private func loadProfileForAuthenticatedUser(userId: UUID, persistLocally: Bool = true) async throws -> Profile? {
        let response = try await SupabaseManager.shared.client
            .from("Profiles")
            .select()
            .eq("profileId", value: userId.uuidString)
            .execute()

        guard var profile = try supabaseDecoder().decode([Profile].self, from: response.data).first else {
            return nil
        }

        profile.isSynced = true
        if persistLocally {
            try await saveIdentityLocally(profile: profile)
        }
        return profile
    }

    private func saveIdentityLocally(profile: Profile) async throws {
        let familyResponse = try await SupabaseManager.shared.client
            .from("Families")
            .select()
            .eq("familyId", value: profile.familyId.uuidString)
            .execute()

        if var family = try supabaseDecoder().decode([Family].self, from: familyResponse.data).first {
            family.isSynced = true
            SQLiteHelper.shared.bootstrapSaveIdentity(family: family, profile: profile)
        } else {
            SQLiteHelper.shared.saveProfile(profile)
        }
    }

    private func createProfileForSignedUpUser(
        profileId: UUID,
        firstName: String,
        lastName: String,
        email: String,
        dob: Date? = nil,
        heightCm: Double? = nil,
        weightKg: Double? = nil,
        gender: Gender? = nil,
        profilePicUrl: String? = nil,
        targetFamily: Family? = nil
    ) async throws -> Profile {
        struct FamilyDTO: Encodable {
            let familyId: UUID
            let familyName: String
            let sharableCode: String
            let createdBy: UUID?
            let createdAt: Date
            let lastUpdatedAt: Date
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
            let dob: Date
            let profilePic: String
            let heightCm: Double
            let weightKg: Double
            let timeZone: String
            let stepGoal: Int
            let caloriesGoal: Int
            let distanceGoal: Int
            let sleepGoal: Double
            let createdAt: Date
            let lastUpdatedAt: Date
            let isSynced: Bool?
        }

        let now = Date()
        let family: Family
        if let target = targetFamily {
            family = target
        } else {
            let familyId = UUID()
            family = Family(
                familyId: familyId,
                familyName: "\(firstName)'s Family",
                sharableCode: generate6DigitReferralCode(),
                createdBy: profileId,
                createdAt: now,
                lastUpdatedAt: now,
                isSynced: true
            )
        }
        
        let resolvedDob = dob ?? now
        let resolvedGender = gender ?? .others
        let calculatedGoals = GoalCalculator.calculateGoals(dob: resolvedDob, gender: resolvedGender)
        
        let profile = Profile(
            profileId: profileId,
            familyId: family.familyId,
            firstName: firstName,
            lastName: lastName,
            nickName: firstName,
            email: email,
            gender: resolvedGender,
            dob: resolvedDob,
            profilePic: profilePicUrl ?? "person.circle",
            heightCm: heightCm ?? 170,
            weightKg: weightKg ?? 70,
            timeZone: TimeZone.current.identifier,
            stepGoal: calculatedGoals.steps,
            caloriesGoal: calculatedGoals.calories,
            distanceGoal: calculatedGoals.distance,
            sleepGoal: calculatedGoals.sleep,
            createdAt: now,
            lastUpdatedAt: now,
            visibleMetricIds: nil,
            isSynced: true
        )

        let familyDTO = FamilyDTO(
            familyId: family.familyId,
            familyName: family.familyName,
            sharableCode: family.sharableCode,
            createdBy: family.createdBy,
            createdAt: family.createdAt,
            lastUpdatedAt: family.lastUpdatedAt,
            isSynced: true
        )
        let profileDTO = ProfileDTO(
            profileId: profile.profileId,
            familyId: profile.familyId,
            firstName: profile.firstName,
            lastName: profile.lastName,
            nickName: profile.nickName,
            email: profile.email,
            gender: profile.gender.rawValue,
            dob: profile.dob,
            profilePic: profile.profilePic,
            heightCm: profile.heightCm,
            weightKg: profile.weightKg,
            timeZone: profile.timeZone,
            stepGoal: profile.stepGoal,
            caloriesGoal: profile.caloriesGoal,
            distanceGoal: profile.distanceGoal,
            sleepGoal: profile.sleepGoal,
            createdAt: profile.createdAt,
            lastUpdatedAt: profile.lastUpdatedAt,
            isSynced: true
        )

        if targetFamily == nil {
            try await SupabaseManager.shared.client.from("Families").insert(familyDTO).execute()
        }
        try await SupabaseManager.shared.client.from("Profiles").insert(profileDTO).execute()

        SQLiteHelper.shared.bootstrapSaveIdentity(family: family, profile: profile)
        return profile
    }

    @MainActor
    private func clearCurrentUser() {
        self.currentUser = nil
        self.family = nil
        self.allProfiles.removeAll()
        self.personalNicknames.removeAll()
        UserDefaults.standard.removeObject(forKey: self.currentUserIdKey)
        // Also drop cached health data so nothing lingers in RAM after logout /
        // account deletion (the SQLite tables are wiped separately) (#12).
        clearInMemoryHealthData()
    }

    /// Sends a password-recovery email via Supabase Auth. The email contains a secure link that
    /// opens the app (via the `homescreenapp://reset-password` deep link) where the user can set a
    /// new password. Throws on network/backend errors.
    func sendPasswordReset(email: String) async throws {
        let normalizedEmail = normalizeEmail(email)
        try await SupabaseManager.shared.client.auth.resetPasswordForEmail(
            normalizedEmail,
            redirectTo: SupabaseManager.passwordResetRedirectURL
        )
    }

    /// Establishes a recovery session from the password-reset deep link the user tapped in their
    /// email. On success the user is authenticated with a short-lived recovery session and can set
    /// a new password via ``updatePassword(_:)``. Throws on an invalid/expired link.
    @discardableResult
    func completeRecovery(from url: URL) async throws -> Bool {
        _ = try await SupabaseManager.shared.client.auth.session(from: url)
        return true
    }

    /// Updates the signed-in user's password (used during password recovery). After updating,
    /// the temporary recovery session is cleared so the user signs in fresh with the new password.
    func updatePassword(_ newPassword: String) async throws {
        _ = try await SupabaseManager.shared.client.auth.update(
            user: UserAttributes(password: newPassword)
        )
        try? await SupabaseManager.shared.client.auth.signOut()
    }

    @MainActor
    func signOut() async {
        try? await SupabaseManager.shared.client.auth.signOut()
        clearCurrentUser()
        SQLiteHelper.shared.clearAllData()
        NotificationCenter.default.post(name: NSNotification.Name("UserDidLogOut"), object: nil)
    }

    /// Returns whether there is a valid, live Supabase Auth session. Supabase persists the
    /// session locally and refreshes it here if it is close to expiry (works offline while the
    /// stored token is still valid). This is the source of truth for "is the user logged in".
    func hasValidSession() async -> Bool {
        return (try? await SupabaseManager.shared.client.auth.session) != nil
    }

    /// Whether the SDK currently holds a recovery session (set after a PASSWORD_RECOVERY
    /// deep link is processed). Used to gate the "Set New Password" screen.
    func hasRecoverySession() -> Bool {
        return SupabaseManager.shared.client.auth.currentSession != nil
    }

    /// Clears the local "current user" pointer WITHOUT wiping cached offline data. Used when the
    /// real Supabase session is missing/expired at launch so the UI drops back to authentication
    /// while leaving unrelated local caches (health, etc.) intact.
    @MainActor
    func clearActiveUserForInvalidSession() {
        clearCurrentUser()
    }

    enum AccountDeletionError: LocalizedError {
        case remoteDeletionFailed(String)
        var errorDescription: String? {
            switch self {
            case .remoteDeletionFailed(let detail):
                return "We couldn't fully delete your account: \(detail)"
            }
        }
    }

    /// Permanently deletes the current user's account, including their Supabase Auth login and all
    /// server-side personal data. The privileged deletion runs in the `delete-user` Edge Function
    /// (service-role key, never shipped in the app); the caller is identified from their JWT so a
    /// user can only delete their own account.
    ///
    /// Must be called while the user is still authenticated. Throws if the server-side deletion
    /// fails, so the UI can keep the account instead of silently signing the user out.
    @MainActor
    func deleteProfileAndSignOut(profileId: UUID) async throws {
        // 1. Permanently delete the auth account + all server-side data via the Edge Function,
        //    while the session (JWT) is still valid.
        do {
            try await SupabaseManager.shared.client.functions.invoke("delete-user")
            print("DataManager: Account permanently deleted via delete-user function.")
        } catch {
            print("DataManager: delete-user function failed: \(error)")
            throw AccountDeletionError.remoteDeletionFailed(error.localizedDescription)
        }

        // 2. Sign out from Supabase Auth (session is now invalid anyway).
        try? await SupabaseManager.shared.client.auth.signOut()

        // 3. Local cleanup.
        SQLiteHelper.shared.deleteProfile(id: profileId)
        clearCurrentUser()
        SQLiteHelper.shared.clearAllData()

        // 4. Route the UI back to onboarding/login.
        NotificationCenter.default.post(name: NSNotification.Name("UserDidLogOut"), object: nil)
    }

    func generate6DigitReferralCode() -> String {
        let chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<6).map { _ in chars.randomElement()! })
    }

    private func normalizeEmail(_ email: String) -> String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func splitName(_ fullName: String) -> (firstName: String, lastName: String) {
        let parts = fullName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: " ")
            .map(String.init)

        guard let firstName = parts.first else {
            return ("", "")
        }

        return (firstName, parts.dropFirst().joined(separator: " "))
    }

    private func supabaseDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        let fractionalISO = ISO8601DateFormatter()
        fractionalISO.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let standardISO = ISO8601DateFormatter()
        standardISO.formatOptions = [.withInternetDateTime]
        
        let fallbackFormats = [
            "yyyy-MM-dd HH:mm:ssXXXXX",
            "yyyy-MM-dd HH:mm:ssX",
            "yyyy-MM-dd HH:mm:ss",
            "yyyy-MM-dd'T'HH:mm:ssXXXXX",
            "yyyy-MM-dd'T'HH:mm:ssX",
            "yyyy-MM-dd'T'HH:mm:ss",
            "yyyy-MM-dd"
        ]
        let fallbackFormatters: [DateFormatter] = fallbackFormats.map { format in
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone.current
            formatter.dateFormat = format
            return formatter
        }
        
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let raw = try container.decode(String.self).trimmingCharacters(in: .whitespacesAndNewlines)
            
            var candidates: [String] = [raw]
            if raw.contains(" ") {
                let isoLike = raw.replacingOccurrences(of: " ", with: "T")
                candidates.append(isoLike)
                if isoLike.hasSuffix("+00") { candidates.append(isoLike + ":00") }
                if isoLike.hasSuffix("-00") { candidates.append(isoLike + ":00") }
            }
            
            for candidate in candidates {
                if let date = fractionalISO.date(from: candidate) { return date }
                if let date = standardISO.date(from: candidate) { return date }
                for formatter in fallbackFormatters {
                    if let date = formatter.date(from: candidate) { return date }
                }
            }

            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid Supabase date: \(raw)")
        }
        return decoder
    }

    func loadAppData(triggerSync: Bool = true) {
        // One-time fix: health records migrated from JSON had isSynced = true, reset to push them
        if !UserDefaults.standard.bool(forKey: healthSyncResetKey) {
            SQLiteHelper.shared.resetHealthSyncFlags()
            UserDefaults.standard.set(true, forKey: healthSyncResetKey)
        }

        // One-time fix: purge residual mock health data from SQLite to start fresh with real data
        if !UserDefaults.standard.bool(forKey: "purgedOldMockHealthData_v4") {
            print("DataManager: Purging residual mock health data from SQLite...")
            SQLiteHelper.shared.clearHealthTables()
            UserDefaults.standard.set(true, forKey: "purgedOldMockHealthData_v4")
        }

        print("DataManager: Loading from SQLite...")
        bootstrapQueue.async {
            let snapshot = self.makeBootstrapSnapshot()

            DispatchQueue.main.async {
                self.applyBootstrapSnapshot(snapshot)
                self.migrateProfilePicturesToSupabaseIfNeeded()
                NotificationCenter.default.post(name: NSNotification.Name("DataManagerDidUpdate"), object: nil)
                self.refreshCurrentUserHealthDataFromHealthKit()

                guard triggerSync else { return }

                Task {
                    let hasSession = (try? await SupabaseManager.shared.client.auth.session) != nil
                    if !hasSession {
                        print("Supabase: No authenticated session. Skipping sync.")
                        return
                    }

                    print("Supabase: Active session found.")
                    await SyncManager.shared.syncAll(force: true)
                    await SyncManager.shared.setupRealtimeSubscriptions()
                }
            }
        }
    }

    @discardableResult
    private func loadFromSQLite() -> Bool {
        let snapshot = makeBootstrapSnapshot()
        applyBootstrapSnapshot(snapshot)
        return snapshot.hasEssentialData
    }

    private func makeBootstrapSnapshot() -> AppBootstrapSnapshot {
        let sqlite = SQLiteHelper.shared

        let profiles = sqlite.fetchProfiles()
        let currentUser: Profile?
        let allProfiles: [Profile]
        if !profiles.isEmpty {
            let savedUserId = UserDefaults.standard.string(forKey: currentUserIdKey)

            #if DEBUG
            // DEBUG-only testing override: force the current user to any locally cached
            // profile by name/email. Never compiled into release (App Store) builds.
            let testingString = testingOverrideIdentity?
                .lowercased()
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !testingString.isEmpty,
               let testingMatch = profiles.first(where: { $0.email.lowercased() == testingString || $0.firstName.lowercased() == testingString }) {
                currentUser = testingMatch
                print("DataManager: ⚠️ Testing Override Active! Logged in as: \(testingMatch.firstName)")
                UserDefaults.standard.set(testingMatch.profileId.uuidString, forKey: currentUserIdKey)
            } else if let targetId = savedUserId,
                      let savedUser = profiles.first(where: { $0.profileId.uuidString == targetId }) {
                currentUser = savedUser
            } else {
                currentUser = nil
            }
            #else
            // Release: the current user is strictly the previously signed-in identity.
            if let targetId = savedUserId,
               let savedUser = profiles.first(where: { $0.profileId.uuidString == targetId }) {
                currentUser = savedUser
            } else {
                currentUser = nil
            }
            #endif

            let scopedProfiles: [Profile]
            if let currentUser {
                scopedProfiles = profiles.filter { $0.familyId == currentUser.familyId }
            } else {
                scopedProfiles = profiles
            }
            allProfiles = scopedProfiles.filter { $0.profileId != currentUser?.profileId }
        } else {
            currentUser = nil
            allProfiles = []
        }

        let family: Family?
        let families = sqlite.fetchFamilies()
        if let currentUser,
           let matchedFamily = families.first(where: { $0.familyId == currentUser.familyId }) {
            family = matchedFamily
        } else {
            family = nil
        }

        let personalNicknames: [UUID: String]
        if let currentUser {
            personalNicknames = sqlite.fetchRelationshipNicknames(for: currentUser.profileId)
        } else {
            personalNicknames = [:]
        }

        let challenges = sqlite.fetchChallengeDetails()
        let challengeProgress = sqlite.fetchChallengeProgress()

        return AppBootstrapSnapshot(
            currentUser: currentUser,
            family: family,
            allProfiles: allProfiles,
            personalNicknames: personalNicknames,
            challenges: challenges,
            challengeProgress: challengeProgress,
            profilesCount: profiles.count
        )
    }

    private func applyBootstrapSnapshot(_ snapshot: AppBootstrapSnapshot) {
        currentUser = snapshot.currentUser
        family = snapshot.family
        allProfiles = snapshot.allProfiles
        personalNicknames = snapshot.personalNicknames
        challenges = snapshot.challenges
        challengeProgress = snapshot.challengeProgress

        // seedMockHealthDataIfNeeded()

        // Reset lazy buffers so screens load only what they need.
        messages.removeAll()
        topics.removeAll()
        topicMembers.removeAll()
        topicMessages.removeAll()
        allVitalsDaily.removeAll()
        allVitalsHourly.removeAll()
        allActivityDaily.removeAll()
        allActivityHourly.removeAll()
        allSleepDaily.removeAll()

        hasLoadedDirectMessages = false
        hasLoadedTopics = false
        loadedTopicMemberTopicIds.removeAll()
        loadedTopicMessageTopicIds.removeAll()
        loadedHealthProfileIds.removeAll()

        print("DataManager: Core identity/family loaded (Profiles: \(snapshot.profilesCount)). Messages, topics, and health are now lazy-loaded per screen.")
    }

    func refreshLoadedCachesAfterSync() {
        let snapshot = makeBootstrapSnapshot()
        currentUser = snapshot.currentUser
        family = snapshot.family
        allProfiles = snapshot.allProfiles
        
        // seedMockHealthDataIfNeeded()
        
        challenges = snapshot.challenges
        challengeProgress = snapshot.challengeProgress
        var mergedNicknames = personalNicknames
        for (profileId, nickname) in snapshot.personalNicknames
            where !nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            mergedNicknames[profileId] = nickname
        }
        personalNicknames = mergedNicknames
        migrateProfilePicturesToSupabaseIfNeeded()

        if hasLoadedDirectMessages {
            reloadDirectMessagesFromSQLite()
        }

        if hasLoadedTopics {
            reloadTopicsFromSQLite(includePreviouslyLoadedMessages: true)
        }

        let healthProfileIds = loadedHealthProfileIds
        for profileId in healthProfileIds {
            reloadHealthDataAsync(for: profileId)
        }
    }

    private func reloadDirectMessagesFromSQLite() {
        if let currentUserId = currentUser?.profileId {
            messages = SQLiteHelper.shared.fetchMessages(for: currentUserId)
            for i in 0..<messages.count {
                var msg = messages[i]
                if msg.receiverId == currentUserId && msg.deliveredAt == nil {
                    msg.deliveredAt = Date()
                    messages[i] = msg
                    SQLiteHelper.shared.saveMessage(msg)
                    SyncManager.shared.pushNewDirectMessage(msg)
                }
            }
        } else {
            messages = SQLiteHelper.shared.fetchAllMessages()
        }
        messages.sort { $0.timestampUTC < $1.timestampUTC }
        hasLoadedDirectMessages = true
    }

    func ensureDirectMessagesLoaded() {
        guard !hasLoadedDirectMessages else { return }
        reloadDirectMessagesFromSQLite()
    }

    @discardableResult
    func fetchDirectMessages(between userA: UUID, and userB: UUID) -> [Message] {
        let fetched = SQLiteHelper.shared.fetchMessages(between: userA, and: userB)
        mergeMessagesIntoCache(fetched)
        return fetched
    }

    private func mergeMessagesIntoCache(_ incoming: [Message]) {
        guard !incoming.isEmpty else { return }
        var byId = Dictionary(uniqueKeysWithValues: messages.map { ($0.messageId, $0) })
        for message in incoming {
            byId[message.messageId] = message
        }
        messages = Array(byId.values).sorted { $0.timestampUTC < $1.timestampUTC }
    }

    func ensureTopicsLoadedForCurrentUser(includeMessages: Bool = false) {
        if !hasLoadedTopics {
            reloadTopicsFromSQLite(includePreviouslyLoadedMessages: false)
        }
        if includeMessages {
            ensureTopicMessagesLoaded(for: topics.map { $0.id })
        }
    }

    private func reloadTopicsFromSQLite(includePreviouslyLoadedMessages: Bool) {
        guard let currentUserId = currentUser?.profileId else {
            topics.removeAll()
            topicMembers.removeAll()
            topicMessages.removeAll()
            hasLoadedTopics = true
            loadedTopicMemberTopicIds.removeAll()
            loadedTopicMessageTopicIds.removeAll()
            return
        }

        let sqlite = SQLiteHelper.shared
        let previousTopicMessageIds = loadedTopicMessageTopicIds
        let allTopics = sqlite.fetchTopics()
        var filteredTopics: [Topic] = []
        var filteredMembers: [TopicMember] = []
        var allowedTopicIds: Set<UUID> = []

        for topic in allTopics {
            let members = sqlite.fetchTopicMembers(for: topic.id)
            if members.contains(where: { $0.userId == currentUserId }) {
                filteredTopics.append(topic)
                filteredMembers.append(contentsOf: members)
                allowedTopicIds.insert(topic.id)
            }
        }

        topics = filteredTopics
        topicMembers = dedupeTopicMembers(filteredMembers)
        loadedTopicMemberTopicIds = allowedTopicIds
        hasLoadedTopics = true

        if includePreviouslyLoadedMessages {
            let topicsToReload = previousTopicMessageIds.intersection(allowedTopicIds)
            topicMessages.removeAll { topicsToReload.contains($0.topicId) }
            for topicId in topicsToReload {
                topicMessages.append(contentsOf: sqlite.fetchTopicMessages(for: topicId))
            }
            topicMessages.sort { ($0.createdAt ?? .distantPast) < ($1.createdAt ?? .distantPast) }
            loadedTopicMessageTopicIds = topicsToReload
        } else {
            topicMessages.removeAll()
            loadedTopicMessageTopicIds.removeAll()
        }
    }

    func ensureTopicMembersLoaded(for topicId: UUID) {
        ensureTopicsLoadedForCurrentUser(includeMessages: false)
        guard !loadedTopicMemberTopicIds.contains(topicId) else { return }
        let fetched = SQLiteHelper.shared.fetchTopicMembers(for: topicId)
        topicMembers = dedupeTopicMembers(topicMembers + fetched)
        loadedTopicMemberTopicIds.insert(topicId)
    }

    func ensureTopicMessagesLoaded(for topicId: UUID) {
        ensureTopicMessagesLoaded(for: [topicId])
    }

    func ensureTopicMessagesLoaded(for topicIds: [UUID]) {
        ensureTopicsLoadedForCurrentUser(includeMessages: false)

        let sqlite = SQLiteHelper.shared
        let idsToLoad = Set(topicIds).subtracting(loadedTopicMessageTopicIds)
        guard !idsToLoad.isEmpty else { return }

        for topicId in idsToLoad {
            topicMessages.append(contentsOf: sqlite.fetchTopicMessages(for: topicId))
            loadedTopicMessageTopicIds.insert(topicId)
        }
        topicMessages.sort { ($0.createdAt ?? .distantPast) < ($1.createdAt ?? .distantPast) }
    }

    private func dedupeTopicMembers(_ members: [TopicMember]) -> [TopicMember] {
        var seen: Set<UUID> = []
        var output: [TopicMember] = []
        for member in members {
            if seen.insert(member.id).inserted {
                output.append(member)
            }
        }
        return output
    }

    func ensureHealthDataLoaded(for profileId: UUID) {
        healthBufferLock.lock()
        defer { healthBufferLock.unlock() }

        if loadedHealthProfileIds.contains(profileId) {
            return
        }

        let sqlite = SQLiteHelper.shared
        allVitalsDaily.removeAll { $0.profileId == profileId }
        allVitalsHourly.removeAll { $0.profileId == profileId }
        allActivityDaily.removeAll { $0.profileId == profileId }
        allActivityHourly.removeAll { $0.profileId == profileId }
        allSleepDaily.removeAll { $0.profileId == profileId }

        allVitalsDaily.append(contentsOf: sqlite.fetchVitalsDaily(for: profileId))
        allVitalsHourly.append(contentsOf: sqlite.fetchVitalsHourly(for: profileId))
        allActivityDaily.append(contentsOf: sqlite.fetchActivityDaily(for: profileId))
        allActivityHourly.append(contentsOf: sqlite.fetchActivityHourly(for: profileId))
        allSleepDaily.append(contentsOf: sqlite.fetchSleepDaily(for: profileId))

        loadedHealthProfileIds.insert(profileId)
    }

    func reloadHealthDataAsync(for profileId: UUID) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let sqlite = SQLiteHelper.shared
            
            let newVitalsDaily = sqlite.fetchVitalsDaily(for: profileId)
            let newVitalsHourly = sqlite.fetchVitalsHourly(for: profileId)
            let newActivityDaily = sqlite.fetchActivityDaily(for: profileId)
            let newActivityHourly = sqlite.fetchActivityHourly(for: profileId)
            let newSleepDaily = sqlite.fetchSleepDaily(for: profileId)
            
            DispatchQueue.main.async {
                self.healthBufferLock.lock()
                
                self.allVitalsDaily.removeAll { $0.profileId == profileId }
                self.allVitalsHourly.removeAll { $0.profileId == profileId }
                self.allActivityDaily.removeAll { $0.profileId == profileId }
                self.allActivityHourly.removeAll { $0.profileId == profileId }
                self.allSleepDaily.removeAll { $0.profileId == profileId }
                
                self.allVitalsDaily.append(contentsOf: newVitalsDaily)
                self.allVitalsHourly.append(contentsOf: newVitalsHourly)
                self.allActivityDaily.append(contentsOf: newActivityDaily)
                self.allActivityHourly.append(contentsOf: newActivityHourly)
                self.allSleepDaily.append(contentsOf: newSleepDaily)
                
                self.loadedHealthProfileIds.insert(profileId)
                self.healthBufferLock.unlock()
                
                NotificationCenter.default.post(name: NSNotification.Name("DataManagerDidUpdate"), object: nil)
            }
        }
    }

    // MARK: - Thread-safe health-buffer snapshots (#7)
    // The Profile.* health accessors go through these so reads always happen under the
    // lock and return an isolated copy that is safe to enumerate on the caller's thread.

    func snapshotVitalsHourly(for profileId: UUID) -> [VitalsHourly] {
        healthBufferLock.lock(); defer { healthBufferLock.unlock() }
        ensureHealthDataLoaded(for: profileId)
        return allVitalsHourly.filter { $0.profileId == profileId }
    }

    func snapshotVitalsDaily(for profileId: UUID) -> [VitalsDaily] {
        healthBufferLock.lock(); defer { healthBufferLock.unlock() }
        ensureHealthDataLoaded(for: profileId)
        return allVitalsDaily.filter { $0.profileId == profileId }
    }

    func snapshotActivityHourly(for profileId: UUID) -> [ActivityHourly] {
        healthBufferLock.lock(); defer { healthBufferLock.unlock() }
        ensureHealthDataLoaded(for: profileId)
        return allActivityHourly.filter { $0.profileId == profileId }
    }

    func snapshotActivityDaily(for profileId: UUID) -> [ActivityDaily] {
        healthBufferLock.lock(); defer { healthBufferLock.unlock() }
        ensureHealthDataLoaded(for: profileId)
        return allActivityDaily.filter { $0.profileId == profileId }
    }

    func snapshotSleepDaily(for profileId: UUID) -> [SleepDaily] {
        healthBufferLock.lock(); defer { healthBufferLock.unlock() }
        ensureHealthDataLoaded(for: profileId)
        return allSleepDaily.filter { $0.profileId == profileId }
    }

    /// Clears all in-memory health buffers and lazy-load guards. Used on logout / account
    /// deletion so no health data lingers in RAM after the DB is wiped (#12).
    func clearInMemoryHealthData() {
        healthBufferLock.lock()
        allVitalsDaily.removeAll()
        allVitalsHourly.removeAll()
        allActivityDaily.removeAll()
        allActivityHourly.removeAll()
        allSleepDaily.removeAll()
        loadedHealthProfileIds.removeAll()
        healthBufferLock.unlock()
        WellnessCache.shared.invalidateAll()
    }
    
    
    // Save a personal nickname for another user (only visible to current user)
    func savePersonalNickname(targetId: UUID, nickname: String) {
        guard let current = currentUser else { return }
        
        SQLiteHelper.shared.saveRelationshipNickname(viewerId: current.profileId, targetId: targetId, nickname: nickname)
        personalNicknames[targetId] = nickname
        
        print("DataManager: Saved personal nickname '\(nickname)' for user \(targetId).")
        NotificationCenter.default.post(name: NSNotification.Name("DataManagerDidUpdate"), object: nil)
        SyncManager.shared.pushRelationshipNickname(viewerId: current.profileId, targetId: targetId, nickname: nickname)
    }

    // MARK: - Persistence & Mutation Handlers
    
    // MARK: - Relative Naming Logic
    
    func getDisplayName(for profile: Profile) -> String {
        // A viewer-specific nickname (what the current user calls this person) wins.
        if let nick = personalNicknames[profile.profileId],
           !nick.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return nick
        }

        // The profile's own nickname, unless it's the legacy default "Me" (treated as unset).
        if let nickName = profile.nickName,
           !nickName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           nickName.lowercased() != "me" {
            return nickName
        }

        // Default to the first name entered at signup.
        return profile.firstName
    }
    
    // Switch the active user profile and persist the choice
    @MainActor
    func setCurrentUser(profileId: UUID) {
        self.performSetCurrentUser(profileId: profileId)
    }

    @MainActor
    private func performSetCurrentUser(profileId: UUID) {
        let sqlite = SQLiteHelper.shared
        let profiles = sqlite.fetchProfiles()
        
        if let newCurrent = profiles.first(where: { $0.profileId == profileId }) {
            self.currentUser = newCurrent
            self.allProfiles = profiles.filter { $0.familyId == newCurrent.familyId && $0.profileId != profileId }
            UserDefaults.standard.set(profileId.uuidString, forKey: currentUserIdKey)

            // Switching identity invalidates user-scoped lazy caches.
            hasLoadedDirectMessages = false
            hasLoadedTopics = false
            loadedTopicMemberTopicIds.removeAll()
            loadedTopicMessageTopicIds.removeAll()
            loadedHealthProfileIds.removeAll()
            messages.removeAll()
            topics.removeAll()
            topicMembers.removeAll()
            topicMessages.removeAll()
            allVitalsDaily.removeAll()
            allVitalsHourly.removeAll()
            allActivityDaily.removeAll()
            allActivityHourly.removeAll()
            allSleepDaily.removeAll()
            
            print("DataManager: Switched current user to \(newCurrent.firstName).")
            NotificationCenter.default.post(name: NSNotification.Name("DataManagerDidUpdate"), object: nil)
            refreshCurrentUserHealthDataFromHealthKit()
            
            // Immediately refresh remote-backed data for the newly selected user.
            // Without this, family members can remain on stale/empty local health caches.
            Task {
                let hasSession = (try? await SupabaseManager.shared.client.auth.session) != nil
                guard hasSession else { return }
                await SyncManager.shared.syncAll(force: true)
                await SyncManager.shared.setupRealtimeSubscriptions()
            }
        }
    }

    // Updates a profile and persists it to SQLite, then pushes to Supabase immediately
    func updateProfile(_ profile: Profile) {
        SQLiteHelper.shared.saveProfile(profile)
        upsertProfileInMemory(profile, notify: true)
        // Immediately push profile change to Supabase
        SyncManager.shared.pushProfileUpdate(profile)
    }

    func updateChallenge(_ challenge: ChallengeDetails) {
        var updatedChallenge = challenge
        updatedChallenge.isSynced = false
        updatedChallenge.lastUpdatedAt = Date()
        
        SQLiteHelper.shared.saveChallengeDetails(updatedChallenge)
        
        if let index = challenges.firstIndex(where: { $0.challengeId == updatedChallenge.challengeId }) {
            challenges[index] = updatedChallenge
        } else {
            challenges.append(updatedChallenge)
        }
        
        NotificationCenter.default.post(name: NSNotification.Name("DataManagerDidUpdate"), object: nil)
        
        Task {
            await SyncManager.shared.pushUnsyncedData()
        }
    }
    
    func deleteChallenge(_ challenge: ChallengeDetails) {
        challenges.removeAll(where: { $0.challengeId == challenge.challengeId })
        challengeProgress.removeAll(where: { $0.challengeId == challenge.challengeId })
        
        SQLiteHelper.shared.deleteChallengeDetails(challengeId: challenge.challengeId)
        
        NotificationCenter.default.post(name: NSNotification.Name("DataManagerDidUpdate"), object: nil)
        
        Task {
            SyncManager.shared.deleteChallengeDetailsRemote(challengeId: challenge.challengeId)
        }
    }

    func applyRemoteProfileUpdate(_ profile: Profile) {
        upsertProfileInMemory(profile, notify: true)
    }

    private func upsertProfileInMemory(_ profile: Profile, notify: Bool) {
        if let current = currentUser, profile.familyId != current.familyId {
            return
        }

        if profile.profileId == currentUser?.profileId {
            self.currentUser = profile
        } else if let index = allProfiles.firstIndex(where: { $0.profileId == profile.profileId }) {
            self.allProfiles[index] = profile
        } else {
            self.allProfiles.append(profile)
        }

        if notify {
            NotificationCenter.default.post(name: NSNotification.Name("DataManagerDidUpdate"), object: nil)
        }
    }
    


    // Dumps the current in-memory structures safely onto the disk so data isn't lost
    func saveDataLocally() {
        let sqlite = SQLiteHelper.shared
        
        if let fam = family { 
            sqlite.saveFamily(fam)
        }
        if let user = currentUser { sqlite.saveProfile(user) }
        for profile in allProfiles { sqlite.saveProfile(profile) }
        for challenge in challenges { sqlite.saveChallengeDetails(challenge) }
        for progress in challengeProgress { sqlite.saveChallengeProgress(progress) }

        for msg in messages { sqlite.saveMessage(msg) }
        for topic in topics { sqlite.saveTopic(topic) }
        for member in topicMembers { sqlite.saveTopicMember(member) }
        for tMsg in topicMessages { sqlite.saveTopicMessage(tMsg) }
        
        // Note: Health data is typically saved during the sync process itself, 
        // but we can ensure it's persisted here too if needed.
        for vital in allVitalsDaily { sqlite.saveVitalsDaily(vital) }
        for activity in allActivityDaily { sqlite.saveActivityDaily(activity) }
        for sleep in allSleepDaily { sqlite.saveSleepDaily(sleep) }
        
        print("DataManager: Successfully persisted all buffers to SQLite.")
    }
    
    // MARK: - Mutator Helpers
    
    func insertDirectMessage(_ message: Message) {
        messages.append(message)
        SQLiteHelper.shared.saveMessage(message)
        NotificationCenter.default.post(name: NSNotification.Name("DataManagerDidUpdate"), object: nil)
        // Immediately push to Supabase without waiting for periodic sync
        SyncManager.shared.pushNewDirectMessage(message)
    }

    func updateDirectMessage(_ message: Message) {
        if let index = messages.firstIndex(where: { $0.messageId == message.messageId }) {
            messages[index] = message
            SQLiteHelper.shared.saveMessage(message)
            NotificationCenter.default.post(name: NSNotification.Name("DataManagerDidUpdate"), object: nil)
            SyncManager.shared.pushNewDirectMessage(message)
        }
    }

    func deleteMessage(_ message: Message) {
        messages.removeAll(where: { $0.messageId == message.messageId })
        SQLiteHelper.shared.deleteMessage(id: message.messageId)
        NotificationCenter.default.post(name: NSNotification.Name("DataManagerDidUpdate"), object: nil)
        SyncManager.shared.deleteMessageRemote(id: message.messageId)
    }
    
    func createTopicLocally(title: String, creatorId: UUID, members: [UUID]) -> Topic {
        let newTopic = Topic(id: UUID(), createdBy: creatorId, title: title, createdAt: Date())
        topics.append(newTopic)
        SQLiteHelper.shared.saveTopic(newTopic)
        hasLoadedTopics = true
        loadedTopicMemberTopicIds.insert(newTopic.id)
        
        var newMembers: [TopicMember] = []
        for memberId in members {
            let member = TopicMember(id: UUID(), topicId: newTopic.id, userId: memberId)
            topicMembers.append(member)
            SQLiteHelper.shared.saveTopicMember(member)
            newMembers.append(member)
        }
        
        NotificationCenter.default.post(name: NSNotification.Name("DataManagerDidUpdate"), object: nil)
        // Immediately push to Supabase
        SyncManager.shared.pushNewTopic(newTopic, members: newMembers)
        return newTopic
    }
    
    func insertTopicMessageLocally(_ message: TopicMessage) {
        topicMessages.append(message)
        loadedTopicMessageTopicIds.insert(message.topicId)
        SQLiteHelper.shared.saveTopicMessage(message)
        NotificationCenter.default.post(name: NSNotification.Name("DataManagerDidUpdate"), object: nil)
        // Immediately push to Supabase
        SyncManager.shared.pushNewTopicMessage(message)
    }

    func deleteTopicMessage(_ message: TopicMessage) {
        topicMessages.removeAll(where: { $0.id == message.id })
        SQLiteHelper.shared.deleteTopicMessage(id: message.id)
        NotificationCenter.default.post(name: NSNotification.Name("DataManagerDidUpdate"), object: nil)
        SyncManager.shared.deleteTopicMessageRemote(id: message.id)
    }
    
    func leaveTopic(topicId: UUID, memberId: UUID) {
        if let member = topicMembers.first(where: { $0.topicId == topicId && $0.userId == memberId }) {
            topicMembers.removeAll(where: { $0.id == member.id })
            SQLiteHelper.shared.deleteTopicMember(id: member.id)
            NotificationCenter.default.post(name: NSNotification.Name("DataManagerDidUpdate"), object: nil)
            SyncManager.shared.leaveTopicRemote(memberId: member.id)
        }
    }
    
    func deleteTopic(_ topic: Topic) {
        topics.removeAll(where: { $0.id == topic.id })
        SQLiteHelper.shared.deleteTopic(id: topic.id)
        NotificationCenter.default.post(name: NSNotification.Name("DataManagerDidUpdate"), object: nil)
        SyncManager.shared.deleteTopicRemote(id: topic.id)
    }

    // loadChallengeLibrary removed

    private func migrateProfilePicturesToSupabaseIfNeeded() {
        guard !hasDisabledProfilePictureMigration,
              ImageManager.shared.canUploadProfilePictures else { return }

        let profilesNeedingMigration = ([currentUser].compactMap { $0 } + allProfiles).filter {
            let value = $0.profilePic.trimmingCharacters(in: .whitespacesAndNewlines)
            return !value.isEmpty && !value.lowercased().hasPrefix("http")
        }

        guard !profilesNeedingMigration.isEmpty else { return }

        for profile in profilesNeedingMigration {
            if profilePictureMigrationInFlight.contains(profile.profileId) {
                continue
            }

            profilePictureMigrationInFlight.insert(profile.profileId)
            Task { [weak self] in
                guard let self else { return }
                defer {
                    Task { @MainActor [weak self] in
                        self?.profilePictureMigrationInFlight.remove(profile.profileId)
                    }
                }

                guard let image = ImageManager.shared.resolveImageForMigration(path: profile.profilePic),
                      let uploadedURL = await ImageManager.shared.uploadImageToSupabase(image, for: profile.profileId) else {
                    if !ImageManager.shared.canUploadProfilePictures {
                        await MainActor.run {
                            self.hasDisabledProfilePictureMigration = true
                        }
                    }
                    return
                }

                var updatedProfile = profile
                updatedProfile.profilePic = uploadedURL
                updatedProfile.lastUpdatedAt = Date()

                await MainActor.run {
                    self.updateProfile(updatedProfile)
                }
            }
        }
    }

    func seedMockHealthDataIfNeeded() {
        return // Mock data completely disabled per user request
        
        let sqlite = SQLiteHelper.shared
        
        var allMembers = allProfiles
        if let currentUser = currentUser {
            allMembers.append(currentUser)
        }
        
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        for member in allMembers {
            let pid = member.profileId
            
            // Check if there is already daily health data for this profile in SQLite
            let existingActivity = sqlite.fetchActivityDaily(for: pid)
            if !existingActivity.isEmpty {
                continue
            }
            
            print("DataManager: Seeding realistic mock wellness data for family member: \(member.firstName)...")
            
            // Generate data for the past 30 days
            for dayOffset in 0..<30 {
                guard let targetDate = calendar.date(byAdding: .day, value: -dayOffset, to: today) else { continue }
                
                // --- 1. Daily Activity (Steps, Distance, Calories) ---
                let stepGoal = member.stepGoal > 0 ? member.stepGoal : 10000
                let distanceGoal = member.distanceGoal > 0 ? member.distanceGoal : 5000
                let calorieGoal = member.caloriesGoal > 0 ? member.caloriesGoal : 2000
                
                let multiplier = Double.random(in: 0.7...1.2)
                let dailySteps = Int(Double(stepGoal) * multiplier)
                let dailyDistance = Double(distanceGoal) * multiplier
                let dailyCalories = Double(calorieGoal) * multiplier
                
                let stepsId = UUID()
                let stepRow = ActivityDaily(
                    id: stepsId,
                    profileId: pid,
                    type: .steps,
                    value: Double(dailySteps),
                    date: targetDate,
                    createdAt: targetDate,
                    lastUpdatedAt: targetDate,
                    isSynced: true
                )
                sqlite.saveActivityDaily(stepRow)
                
                let distId = UUID()
                let distRow = ActivityDaily(
                    id: distId,
                    profileId: pid,
                    type: .distance,
                    value: dailyDistance,
                    date: targetDate,
                    createdAt: targetDate,
                    lastUpdatedAt: targetDate,
                    isSynced: true
                )
                sqlite.saveActivityDaily(distRow)
                
                let calId = UUID()
                let calRow = ActivityDaily(
                    id: calId,
                    profileId: pid,
                    type: .calories,
                    value: dailyCalories,
                    date: targetDate,
                    createdAt: targetDate,
                    lastUpdatedAt: targetDate,
                    isSynced: true
                )
                sqlite.saveActivityDaily(calRow)
                
                // --- 2. Hourly Activity (Steps, Distance, Calories for today) ---
                if dayOffset == 0 {
                    for hour in 0..<24 {
                        guard let hourStart = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: targetDate) else { continue }
                        
                        var hourlyMultiplier = 0.0
                        if hour >= 7 && hour <= 22 {
                            hourlyMultiplier = Double.random(in: 0.02...0.12)
                        } else {
                            hourlyMultiplier = Double.random(in: 0.0...0.01)
                        }
                        
                        let hrSteps = Double(dailySteps) * hourlyMultiplier
                        let hrDist = dailyDistance * hourlyMultiplier
                        let hrCal = dailyCalories * hourlyMultiplier
                        
                        let hrStepRow = ActivityHourly(
                            id: UUID(),
                            profileId: pid,
                            type: .steps,
                            value: hrSteps,
                            hourStart: hourStart,
                            sampleCount: hrSteps > 0 ? 1 : 0,
                            createdAt: hourStart,
                            lastUpdatedAt: hourStart,
                            isSynced: true
                        )
                        sqlite.saveActivityHourly(hrStepRow)
                        
                        let hrDistRow = ActivityHourly(
                            id: UUID(),
                            profileId: pid,
                            type: .distance,
                            value: hrDist,
                            hourStart: hourStart,
                            sampleCount: hrDist > 0 ? 1 : 0,
                            createdAt: hourStart,
                            lastUpdatedAt: hourStart,
                            isSynced: true
                        )
                        sqlite.saveActivityHourly(hrDistRow)
                        
                        let hrCalRow = ActivityHourly(
                            id: UUID(),
                            profileId: pid,
                            type: .calories,
                            value: hrCal,
                            hourStart: hourStart,
                            sampleCount: hrCal > 0 ? 1 : 0,
                            createdAt: hourStart,
                            lastUpdatedAt: hourStart,
                            isSynced: true
                        )
                        sqlite.saveActivityHourly(hrCalRow)
                    }
                }
                
                // --- 3. Daily Vitals (Heart Rate, HRV) ---
                let baseHR = Double.random(in: 60...75)
                let minHR = baseHR - Double.random(in: 5...12)
                let maxHR = baseHR + Double.random(in: 30...60)
                let avgHR = baseHR + Double.random(in: 2...8)
                
                let hrDailyRow = VitalsDaily(
                    id: UUID(),
                    profileId: pid,
                    type: .heartRate,
                    date: targetDate,
                    minValue: minHR,
                    avgValue: avgHR,
                    maxValue: maxHR,
                    createdAt: targetDate,
                    lastUpdatedAt: targetDate,
                    isSynced: true
                )
                sqlite.saveVitalsDaily(hrDailyRow)
                
                let baseHRV = Double.random(in: 30...70)
                let minHRV = baseHRV - Double.random(in: 10...20)
                let maxHRV = baseHRV + Double.random(in: 15...30)
                let avgHRV = baseHRV + Double.random(in: 0...5)
                
                let hrvDailyRow = VitalsDaily(
                    id: UUID(),
                    profileId: pid,
                    type: .hrv,
                    date: targetDate,
                    minValue: minHRV,
                    avgValue: avgHRV,
                    maxValue: maxHRV,
                    createdAt: targetDate,
                    lastUpdatedAt: targetDate,
                    isSynced: true
                )
                sqlite.saveVitalsDaily(hrvDailyRow)
                
                // --- 4. Sleep Daily ---
                let totalSleep = Double.random(in: 6.5...8.5)
                let totalMin = totalSleep * 60.0
                let deepMin = totalMin * Double.random(in: 0.15...0.25)
                let remMin = totalMin * Double.random(in: 0.18...0.25)
                let lightMin = totalMin - deepMin - remMin
                
                guard let prevDay = calendar.date(byAdding: .day, value: -1, to: targetDate),
                      let sleepStart = calendar.date(bySettingHour: 23, minute: Int.random(in: 0...59), second: 0, of: prevDay) else { continue }
                let sleepEnd = calendar.date(byAdding: .minute, value: Int(totalMin), to: sleepStart) ?? targetDate
                
                let sleepRow = SleepDaily(
                    id: UUID(),
                    profileId: pid,
                    date: targetDate,
                    totalSleep: totalSleep,
                    deepSleep: deepMin / 60.0,
                    remSleep: remMin / 60.0,
                    lightSleep: lightMin / 60.0,
                    sleepStart: sleepStart,
                    sleepEnd: sleepEnd,
                    createdAt: targetDate,
                    lastUpdatedAt: targetDate,
                    isSynced: true
                )
                sqlite.saveSleepDaily(sleepRow)
            }
        }
    }
}

extension DataManager {
    // MARK: - Family Health-Sharing Consent

    private var healthSharingConsentKey: String { "FamilyHealthSharingConsented" }

    /// Whether the user has given explicit consent to share their HealthKit-derived
    /// data with family members (i.e. upload it to Supabase). New users opt in during
    /// HealthKit onboarding and can revoke anytime from Profile → Apple Health. Reading
    /// HealthKit for local, on-device display does NOT require this consent.
    ///
    /// Migration: if the user has NOT made an explicit choice yet but a HealthKit link
    /// already exists, they connected under a prior build (whose permission copy stated
    /// data is shared with family), so we grandfather them as consented to avoid silently
    /// breaking their existing family sharing. Users who never connected default to `false`.
    var isFamilyHealthSharingConsented: Bool {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: healthSharingConsentKey) == nil {
            return linkedHealthKitProfileId() != nil
        }
        return defaults.bool(forKey: healthSharingConsentKey)
    }

    /// Records the user's family health-sharing consent decision.
    /// When granting, the current user's local health rows are re-flagged unsynced so
    /// they get uploaded on the next sync. When revoking, future uploads stop and the
    /// already-shared server-side rows are best-effort deleted so sharing truly ends.
    @MainActor
    func setFamilyHealthSharingConsent(_ granted: Bool) {
        let previous = isFamilyHealthSharingConsented
        UserDefaults.standard.set(granted, forKey: healthSharingConsentKey)
        guard granted != previous else { return }

        if granted {
            if let pid = currentUser?.profileId {
                SQLiteHelper.shared.markCurrentUserHealthDataUnsynced(for: pid)
            }
            Task { await SyncManager.shared.pushCurrentUserHealthDataNow() }
        } else {
            Task { await SyncManager.shared.deleteCurrentUserRemoteHealthData() }
        }
        NotificationCenter.default.post(name: NSNotification.Name("DataManagerDidUpdate"), object: nil)
    }

    private func setLinkedHealthKitProfileId(_ profileId: UUID) {
        UserDefaults.standard.set(profileId.uuidString, forKey: healthKitLinkedProfileIdKey)
    }

    private func linkedHealthKitProfileId() -> UUID? {
        guard let raw = UserDefaults.standard.string(forKey: healthKitLinkedProfileIdKey) else { return nil }
        return UUID(uuidString: raw)
    }
    
    /// True when currently logged-in user is the device profile that should sync HealthKit.
    func isCurrentUserHealthKitLinked() -> Bool {
        #if targetEnvironment(simulator)
        return false
        #else
        guard let currentUser, let linked = linkedHealthKitProfileId() else { return false }
        return currentUser.profileId == linked
        #endif
    }
    
    private func resolveOrCreateHealthKitLink(for profile: Profile) -> Bool {
        #if targetEnvironment(simulator)
        return false
        #else
        if let linked = linkedHealthKitProfileId() {
            let knownProfiles = [currentUser].compactMap { $0 } + allProfiles
            let linkedStillExists = knownProfiles.contains(where: { $0.profileId == linked })
            if linkedStillExists {
                return linked == profile.profileId
            }
        }

        // The authenticated in-app user is the only profile that should ever
        // read from this device's HealthKit. Persist that link immediately so
        // the first app launch can request HealthKit permission.
        if currentUser?.profileId == profile.profileId {
            setLinkedHealthKitProfileId(profile.profileId)
            return true
        }
        
        // Prefer explicit "Me" marker from family profiles to avoid accidental linking.
        let knownProfiles = [currentUser].compactMap { $0 } + allProfiles
        if let meProfile = knownProfiles.first(where: {
            ($0.nickName ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "me"
        }) {
            setLinkedHealthKitProfileId(meProfile.profileId)
            return profile.profileId == meProfile.profileId
        }
        
        // Fallback: auto-detect likely device owner by recent local activity (last 3 days).
        let sqlite = SQLiteHelper.shared
        let calendar = Calendar.current
        let start = calendar.date(byAdding: .day, value: -2, to: calendar.startOfDay(for: Date())) ?? Date.distantPast
        let likelyOwner = knownProfiles.max(by: { lhs, rhs in
            let lhsScore = sqlite.fetchActivityDaily(for: lhs.profileId).filter { $0.date >= start && $0.value > 0 }.count
            let rhsScore = sqlite.fetchActivityDaily(for: rhs.profileId).filter { $0.date >= start && $0.value > 0 }.count
            return lhsScore < rhsScore
        })
        
        if let owner = likelyOwner {
            let ownerScore = sqlite.fetchActivityDaily(for: owner.profileId).filter { $0.date >= start && $0.value > 0 }.count
            if ownerScore > 0 {
                setLinkedHealthKitProfileId(owner.profileId)
                return profile.profileId == owner.profileId
            }
        }
        
        // No reliable owner resolution: skip HealthKit sync instead of risking wrong-profile overwrite.
        return false
        #endif
    }
    
    func refreshCurrentUserHealthDataFromHealthKit() {
        #if targetEnvironment(simulator)
        print("DataManager: Running on Simulator. Skipping HealthKit, fetching from Supabase.")
        return
        #else
        
        guard !isRefreshingCurrentUserHealth else { return }
        guard let currentUser else { return }
        guard resolveOrCreateHealthKitLink(for: currentUser) else {
            #if DEBUG
            print("HealthKit sync skipped: current profile is not linked to this device HealthKit owner.")
            #endif
            return
        }

        isRefreshingCurrentUserHealth = true

        HealthKitService.shared.fetchWellnessPayload(for: currentUser.profileId) { [weak self] result in
            guard let self else { return }

            defer {
                DispatchQueue.main.async {
                    self.isRefreshingCurrentUserHealth = false
                }
            }

            switch result {
            case .failure(let error):
                #if DEBUG
                print("HealthKit sync skipped for current user: \(error.localizedDescription)")
                #endif
                // DO NOT clear health data on failure. Keep the previously fetched data.
                self.reloadHealthDataAsync(for: currentUser.profileId)
            case .success(let payload):
                SQLiteHelper.shared.replaceHealthData(
                    for: currentUser.profileId,
                    activityDaily: payload.activityDaily,
                    activityHourly: payload.activityHourly,
                    vitalsDaily: payload.vitalsDaily,
                    vitalsHourly: payload.vitalsHourly,
                    sleepDaily: payload.sleepDaily
                )

                self.reloadHealthDataAsync(for: currentUser.profileId)
                
                // Immediately publish current user's HealthKit data to Supabase
                // so other family logins can see real data without waiting for periodic sync.
                Task {
                    await SyncManager.shared.pushCurrentUserHealthDataNow()
                }
            }
        }
        #endif
    }
}

class ImageManager {
    static let shared = ImageManager()
    private let profilePicturesBucket = "avatars"
    private(set) var canUploadProfilePictures = true

    // L1: In-memory (fastest — survives the session)
    private var memoryCache: [String: UIImage] = [:]

    // L2: Disk cache directory (survives app restarts)
    private let diskCacheDir: URL = {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let dir = caches.appendingPathComponent("ProfilePicCache", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    private init() {}

    // MARK: - Disk Cache Helpers

    private func diskKey(for urlString: String) -> String {
        // hashValue is randomized per app launch. Use a stable base64 string instead.
        let base64 = Data(urlString.utf8).base64EncodedString()
        let safeFilename = base64.replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "+", with: "-")
        return safeFilename + ".jpg"
    }

    private func diskCacheURL(for urlString: String) -> URL {
        diskCacheDir.appendingPathComponent(diskKey(for: urlString))
    }

    private func saveImageToDisk(_ image: UIImage, for urlString: String) {
        guard let data = image.jpegData(compressionQuality: 0.8) else { return }
        let url = diskCacheURL(for: urlString)
        try? data.write(to: url, options: .atomic)
    }

    private func loadImageFromDisk(for urlString: String) -> UIImage? {
        let url = diskCacheURL(for: urlString)
        guard FileManager.default.fileExists(atPath: url.path),
              let image = UIImage(contentsOfFile: url.path) else { return nil }
        return image
    }

    // MARK: - Upload to Supabase Storage

    func uploadImageToSupabase(_ image: UIImage, for profileId: UUID) async -> String? {
        let filename = "\(profileId.uuidString)_\(Int(Date().timeIntervalSince1970)).jpg"

        guard canUploadProfilePictures else {
            let fallbackURL = "local_\(filename)"
            memoryCache[fallbackURL] = image
            saveImageToDisk(image, for: fallbackURL)
            return fallbackURL
        }
        guard let data = image.jpegData(compressionQuality: 0.6) else { return nil }

        do {
            try await SupabaseManager.shared.client.storage
                .from(profilePicturesBucket)
                .upload(filename, data: data, options: FileOptions(contentType: "image/jpeg", upsert: true))

            let publicURLString = "https://bypxwhpopgcbxbwiyaym.supabase.co/storage/v1/object/public/\(profilePicturesBucket)/\(filename)"

            // Cache immediately at both layers
            memoryCache[publicURLString] = image
            saveImageToDisk(image, for: publicURLString)

            print("ImageManager: Uploaded and cached profile photo.")
            return publicURLString
        } catch {
            if String(describing: error).localizedCaseInsensitiveContains("bucket not found") {
                canUploadProfilePictures = false
                print("ImageManager: Profile picture uploads disabled because the Supabase storage bucket '\(profilePicturesBucket)' does not exist.")
            }
            print("ImageManager: Upload error — \(error)")
            let fallbackURL = "local_\(filename)"
            memoryCache[fallbackURL] = image
            saveImageToDisk(image, for: fallbackURL)
            return fallbackURL
        }
    }

    func resolveImageForMigration(path: String) -> UIImage? {
        let key = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return nil }

        if let cached = memoryCache[key] {
            return cached
        }

        if let diskImage = loadImageFromDisk(for: key) {
            memoryCache[key] = diskImage
            return diskImage
        }

        let fileURL = getDocumentsDirectory().appendingPathComponent(key)
        if FileManager.default.fileExists(atPath: fileURL.path),
           let image = UIImage(contentsOfFile: fileURL.path) {
            memoryCache[key] = image
            return image
        }

        if let bundleImage = UIImage(named: key) {
            return bundleImage
        }

        return nil
    }

    // MARK: - Set Image on UIImageView (Memory → Disk → Network)

    func setImage(for imageView: UIImageView, from path: String?) {
        let defaultImage = UIImage(systemName: "person.circle.fill")?.withTintColor(.systemGray, renderingMode: .alwaysOriginal)
        guard let path = path, !path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            imageView.image = defaultImage
            return
        }

        let key = path.trimmingCharacters(in: .whitespacesAndNewlines)

        // 1. Memory cache (instant)
        if let cached = memoryCache[key] {
            imageView.image = cached
            return
        }

        // 2. Disk cache (fast, survives restarts)
        if let diskImage = loadImageFromDisk(for: key) {
            memoryCache[key] = diskImage
            imageView.image = diskImage
            return
        }

        // 3. Network fetch for Supabase Storage URLs
        if key.starts(with: "http"), let url = URL(string: key) {
            imageView.image = defaultImage
            URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
                guard let self = self, let data = data, let image = UIImage(data: data) else { return }
                self.memoryCache[key] = image
                self.saveImageToDisk(image, for: key)
                DispatchQueue.main.async { imageView.image = image }
            }.resume()
            return
        }

        // 4. Local documents directory (e.g. user-captured photo before upload)
        let fileURL = getDocumentsDirectory().appendingPathComponent(key)
        if FileManager.default.fileExists(atPath: fileURL.path), let image = UIImage(contentsOfFile: fileURL.path) {
            memoryCache[key] = image
            imageView.image = image
            return
        }

        // 5. Bundle assets (fallback for system names like "dad_avatar")
        if let bundleImage = UIImage(named: key) {
            imageView.image = bundleImage
            return
        }

        imageView.image = defaultImage
    }

    // MARK: - Set Image on UIButton

    func setButtonImage(for button: UIButton, from path: String?) {
        let defaultImage = UIImage(systemName: "person.circle.fill")?.withTintColor(.systemGray, renderingMode: .alwaysOriginal)
        guard let path = path, !path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            button.setImage(defaultImage, for: .normal); return
        }

        let key = path.trimmingCharacters(in: .whitespacesAndNewlines)

        if let cached = memoryCache[key] { button.setImage(cached, for: .normal); return }

        if let diskImage = loadImageFromDisk(for: key) {
            memoryCache[key] = diskImage
            button.setImage(diskImage, for: .normal)
            return
        }

        if key.starts(with: "http"), let url = URL(string: key) {
            button.setImage(defaultImage, for: .normal)
            URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
                guard let self = self, let data = data, let image = UIImage(data: data) else { return }
                self.memoryCache[key] = image
                self.saveImageToDisk(image, for: key)
                DispatchQueue.main.async { button.setImage(image, for: .normal) }
            }.resume()
            return
        }

        if let bundleImage = UIImage(named: key) { button.setImage(bundleImage, for: .normal); return }
        button.setImage(defaultImage, for: .normal)
    }

    // MARK: - Synchronous Load (legacy callers)

    func loadImage(named: String) -> UIImage? {
        if let cached = memoryCache[named] { return cached }
        if let disk = loadImageFromDisk(for: named) { memoryCache[named] = disk; return disk }
        let fileURL = getDocumentsDirectory().appendingPathComponent(named)
        if FileManager.default.fileExists(atPath: fileURL.path), let image = UIImage(contentsOfFile: fileURL.path) { return image }
        return UIImage(named: named) ?? UIImage(systemName: "person.circle.fill")?.withTintColor(.systemGray, renderingMode: .alwaysOriginal)
    }

    // MARK: - Cache Management

    /// Pre-warm the disk cache for a list of profile picture URLs (call after pulling profiles)
    func prefetchProfilePictures(for profiles: [Profile]) {
        for profile in profiles {
            let url = profile.profilePic
            guard url.starts(with: "http"), memoryCache[url] == nil, loadImageFromDisk(for: url) == nil else { continue }
            guard let nsUrl = URL(string: url) else { continue }
            URLSession.shared.dataTask(with: nsUrl) { [weak self] data, _, _ in
                guard let self = self, let data = data, let image = UIImage(data: data) else { return }
                self.memoryCache[url] = image
                self.saveImageToDisk(image, for: url)
                print("ImageManager: Pre-cached picture for \(profile.firstName)")
            }.resume()
        }
    }

    /// Clears disk cache (useful for storage management / logout)
    func clearDiskCache() {
        try? FileManager.default.removeItem(at: diskCacheDir)
        try? FileManager.default.createDirectory(at: diskCacheDir, withIntermediateDirectories: true)
        memoryCache.removeAll()
        print("ImageManager: Disk cache cleared.")
    }

    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
}

class NotificationManager {
    static let shared = NotificationManager()

    private init() {
        requestAuthorization()
    }

    var notifications: [NotificationItem] = []

    var unreadCount: Int {
        notifications.filter { !$0.isRead }.count
    }

    func markAllAsRead() {
        for index in notifications.indices {
            notifications[index].isRead = true
        }
        NotificationCenter.default.post(name: NSNotification.Name("NewNotificationAdded"), object: nil)
    }

    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            print("Notification permission granted: \(granted)")
        }
    }

    func checkRulesAndGenerateNotifications() {
        guard let currentUser = DataManager.shared.currentUser else { return }

        let allMembers = [currentUser] + DataManager.shared.allProfiles
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let hour = calendar.component(.hour, from: Date())

        for member in allMembers {
            // Only raise a low-wellness alert when there is enough data to trust the score (#2),
            // using the centralized threshold (#9).
            let wellness = member.wellnessResult(for: Date())
            if wellness.hasSufficientData && wellness.score < StandardInsightConfig.lowWellnessNotificationThreshold {
                addNotification(
                    title: "\(member.displayName)'s wellness is low",
                    body: "\(member.displayName) is at \(Int(wellness.score * 100))% wellness today. They might need a nudge!",
                    type: .performanceAlert,
                    relatedProfileId: member.profileId
                )
            }
            
            // Abnormal Vitals Alert (HR / HRV)
            if let abnormalVital = member.getAbnormalVital(on: today) {
                let title: String
                let body: String
                
                switch abnormalVital.type {
                case "low_hr":
                    title = "\(member.displayName)'s HR is low"
                    body = "\(member.displayName)'s heart rate is below their expected range. Current: \(Int(abnormalVital.value)) BPM."
                case "high_hr":
                    title = "\(member.displayName)'s HR is high"
                    body = "\(member.displayName)'s heart rate is above their expected range. Current: \(Int(abnormalVital.value)) BPM."
                case "low_hrv":
                    title = "\(member.displayName)'s HRV dropped"
                    body = "\(member.displayName)'s HRV has dropped significantly below their expected range. Current: \(Int(abnormalVital.value)) ms."
                default:
                    title = "\(member.displayName)'s vital is abnormal"
                    body = "\(member.displayName)'s vital is outside expected range."
                }
                
                addNotification(
                    title: title,
                    body: body,
                    type: .performanceAlert,
                    relatedProfileId: member.profileId
                )
            }

            if hour >= 6 && hour < 12,
               let sleep = member.sleep.first(where: { calendar.isDate($0.date, inSameDayAs: today) }),
               sleep.totalSleep < StandardInsightConfig.shortSleepHours {
                addNotification(
                    title: "\(member.displayName) had short sleep",
                    body: "\(member.displayName) only clocked \(String(format: "%.1f", sleep.totalSleep))h of sleep. Coordination might be lower today.",
                    type: .performanceAlert,
                    relatedProfileId: member.profileId
                )
            }

            let stepsToday = member.activityDaily
                .filter { $0.type == .steps && calendar.isDate($0.date, inSameDayAs: today) }
                .reduce(0) { $0 + $1.value }
            let stepGoal = Double(member.stepGoal)

            if hour >= 14 && hour < 19 && stepsToday < (stepGoal * 0.3) {
                addNotification(
                    title: "\(member.displayName) needs a move",
                    body: "\(member.displayName) is lagging on steps today. Send some motivation.",
                    type: .performanceAlert,
                    relatedProfileId: member.profileId
                )
            } else if hour >= 19 && stepsToday < (stepGoal * 0.7) {
                addNotification(
                    title: "\(member.displayName) is behind targets",
                    body: "\(member.displayName) has only completed \(Int(stepsToday)) steps. Why not start a family walk?",
                    type: .performanceAlert,
                    relatedProfileId: member.profileId
                )
            }

            let caloriesToday = member.activityDaily
                .filter { $0.type == .calories && calendar.isDate($0.date, inSameDayAs: today) }
                .reduce(0) { $0 + $1.value }
            let calorieGoal = Double(member.caloriesGoal)

            if hour >= 17 && caloriesToday < (calorieGoal * 0.5) {
                addNotification(
                    title: "Family Activity Nudge",
                    body: "\(member.displayName) is below their calorie goal. Time for some group activity?",
                    type: .performanceAlert,
                    relatedProfileId: member.profileId
                )
            }
        }
    }

    private func addNotification(title: String, body: String, type: NotificationType, relatedProfileId: UUID?) {
        let today = Calendar.current.startOfDay(for: Date())
        let exists = notifications.contains {
            $0.title == title && Calendar.current.isDate($0.timestamp, inSameDayAs: today)
        }

        guard !exists else { return }

        let item = NotificationItem(
            id: UUID(),
            title: title,
            body: body,
            timestamp: Date(),
            type: type,
            isRead: false,
            relatedProfileId: relatedProfileId
        )

        notifications.insert(item, at: 0)
        scheduleLocalNotification(for: item)
        NotificationCenter.default.post(name: NSNotification.Name("NewNotificationAdded"), object: nil)
    }

    private func scheduleLocalNotification(for item: NotificationItem) {
        let content = UNMutableNotificationContent()
        content.title = item.title
        content.body = item.body
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: item.id.uuidString, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    func clearAll() {
        notifications.removeAll()
        NotificationCenter.default.post(name: NSNotification.Name("NewNotificationAdded"), object: nil)
    }
}
