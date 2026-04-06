import Foundation

@MainActor
final class WealthPurpleCardsStore: WealthCardHoldingStore {
    static let shared = WealthPurpleCardsStore()

    private override init() {
        super.init()
    }
}
