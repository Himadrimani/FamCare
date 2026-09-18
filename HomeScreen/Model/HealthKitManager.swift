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
            self.db.updateChallengeProgress(
                challengeId: challenge.challengeId,
                memberId: currentUserId,
                currentValue: value
            )
            
            DispatchQueue.main.async {
                if let index = DataManager.shared.challengeProgress.firstIndex(where: { $0.challengeId == challenge.challengeId && $0.memberId == currentUserId }) {
                    DataManager.shared.challengeProgress[index].currentValue = value
                    NotificationCenter.default.post(name: NSNotification.Name("DataManagerDidUpdate"), object: nil)
                }
            }
        }
    }
}
