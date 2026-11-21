import Foundation
import HealthKit

class HealthKitManager {
    static let shared = HealthKitManager()
    private let hkService = HealthKitService.shared
    private let db = SQLiteHelper.shared
    
    private init() {}
    
    func updateLocalChallengeProgress(challenge: ChallengeDetails) {
        guard let currentUserId = DataManager.shared.currentUser?.profileId else { return }
        
        let quantityType: HKQuantityType
        switch challenge.subType.lowercased() {
        case "steps":
            quantityType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
        case "calories", "caloriesburned":
            quantityType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!
        case "distance":
            quantityType = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)!
        default:
            return
        }
        
        let start = challenge.startDate
        let end = Date()
        
        hkService.fetchCumulativeSum(for: quantityType, from: start, to: end) { value in
            let priorProgress = DataManager.shared.challengeProgress.first(where: { $0.challengeId == challenge.challengeId && $0.memberId == currentUserId })
            let wasMemberAlreadyComplete = (priorProgress?.goalValue ?? 0) > 0 && (priorProgress?.currentValue ?? 0) >= (priorProgress?.goalValue ?? 0)

            self.db.updateChallengeProgress(
                challengeId: challenge.challengeId,
                memberId: currentUserId,
                currentValue: value
            )
            
            DispatchQueue.main.async {
                if let index = DataManager.shared.challengeProgress.firstIndex(where: { $0.challengeId == challenge.challengeId && $0.memberId == currentUserId }) {
                    DataManager.shared.challengeProgress[index].currentValue = value
                    
                    let allProgress = DataManager.shared.challengeProgress.filter { $0.challengeId == challenge.challengeId }
                    let isFamilyChallenge = allProgress.count > 1
                    let isFamilyNowComplete = isFamilyChallenge && allProgress.allSatisfy { $0.goalValue > 0 && $0.currentValue >= $0.goalValue }
                    
                    if !wasMemberAlreadyComplete && isFamilyNowComplete {
                        RewardsManager.shared.awardFamilyShield(challenge: challenge, participantsCount: allProgress.count)
                    }

                    NotificationCenter.default.post(
                        name: .ChallengeDataDidUpdate,
                        object: nil,
                        userInfo: [NotificationPayloadKey.challengeId: challenge.challengeId.uuidString]
                    )
                    NotificationCenter.default.post(name: NSNotification.Name("DataManagerDidUpdate"), object: nil)
                }
            }
        }
    }
}
