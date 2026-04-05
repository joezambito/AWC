import Foundation
import Combine

// MARK: - WealthPortfolioStore
//
// Central store for portfolio state (holdings, activity, buying power).
// The full implementation lives in the real Xcode project.
// This stub satisfies references from extension files already in git.

@MainActor
final class WealthPortfolioStore: ObservableObject {

    static let shared = WealthPortfolioStore()
    private init() {}

    @Published private(set) var holdings: [Holding] = []
    @Published private(set) var activityOpportunities: [Opportunity] = []
    @Published private(set) var freeBuyingPower: Double = 0
}
