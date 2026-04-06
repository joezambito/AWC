import Foundation

@MainActor
final class WealthRedCardsStore: WealthCardHoldingStore {
    static let shared = WealthRedCardsStore()

    private override init() {
        super.init()
    }
}
