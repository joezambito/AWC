import Foundation

@MainActor
final class WealthGreenCardsStore: WealthCardHoldingStore {
    static let shared = WealthGreenCardsStore()

    private override init() {
        super.init()
    }
}
