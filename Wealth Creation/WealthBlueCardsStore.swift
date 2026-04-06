import Foundation

@MainActor
final class WealthBlueCardsStore: WealthCardHoldingStore {
    static let shared = WealthBlueCardsStore()

    private override init() {
        super.init()
    }
}
