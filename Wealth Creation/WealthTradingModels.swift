import Foundation

struct BrokerProfile: Identifiable, Hashable {
    let id: UUID
    let name: String
    let feeLabel: String
    let mode: String
    let safety: String
    let trusted: Bool
    let feeScore: Int

    init(
        id: UUID = UUID(),
        name: String,
        feeLabel: String,
        mode: String,
        safety: String,
        trusted: Bool,
        feeScore: Int
    ) {
        self.id = id
        self.name = name
        self.feeLabel = feeLabel
        self.mode = mode
        self.safety = safety
        self.trusted = trusted
        self.feeScore = feeScore
    }
}
