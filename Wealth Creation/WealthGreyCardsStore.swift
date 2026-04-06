import Foundation

@MainActor
final class WealthGreyCardsStore: WealthCardHoldingStore {
    static let shared = WealthGreyCardsStore()

    private override init() {
        super.init()
    }
}
