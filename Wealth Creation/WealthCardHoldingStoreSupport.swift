import Foundation
import Combine
import SwiftUI

enum WealthCardHoldingBucket: String {
    case green
    case blue
    case purple
    case red
    case grey

    static func resolve(for opportunity: Opportunity) -> WealthCardHoldingBucket {
        if opportunity.hasIncompleteDisplayData {
            return .grey
        }

        let greenIntel =
            opportunity.scoreTint == WealthTheme.green &&
            opportunity.confidenceTint == WealthTheme.green
        let blueIntel =
            (opportunity.scoreTint == WealthTheme.blue &&
             opportunity.confidenceTint != WealthTheme.purple) ||
            (opportunity.confidenceTint == WealthTheme.blue &&
             opportunity.scoreTint != WealthTheme.purple)
        let redIntel =
            opportunity.scoreTint == WealthTheme.red ||
            opportunity.confidenceTint == WealthTheme.red ||
            opportunity.decisionBias == .avoid

        if redIntel {
            return .red
        }

        if greenIntel {
            return .green
        }

        if blueIntel {
            return .blue
        }

        return .purple
    }

    var color: Color {
        switch self {
        case .green:
            return WealthTheme.green
        case .blue:
            return WealthTheme.blue
        case .purple:
            return WealthTheme.purple
        case .red:
            return WealthTheme.red
        case .grey:
            return WealthTheme.grey
        }
    }

    var label: String {
        switch self {
        case .green:
            return "GREEN"
        case .blue:
            return "WATCH"
        case .purple:
            return "MIXED"
        case .red:
            return "AVOID"
        case .grey:
            return "WAIT"
        }
    }
}

extension Opportunity {
    var cardHoldingBucket: WealthCardHoldingBucket {
        WealthCardHoldingBucket.resolve(for: self)
    }
}

struct WealthGreenCheckpointRouting {
    let greenCards: [Opportunity]
    let dispatcherCards: [Opportunity]
    let blueCards: [Opportunity]
    let purpleCards: [Opportunity]
    let redCards: [Opportunity]
    let greyCards: [Opportunity]
}

enum WealthCardHoldingRouter {
    static func routeFromGreenCheckpoint(_ opportunities: [Opportunity]) -> WealthGreenCheckpointRouting {
        var greenCards: [Opportunity] = []
        var dispatcherCards: [Opportunity] = []
        var blueCards: [Opportunity] = []
        var purpleCards: [Opportunity] = []
        var redCards: [Opportunity] = []
        var greyCards: [Opportunity] = []

        for opportunity in opportunities {
            switch opportunity.cardHoldingBucket {
            case .green:
                greenCards.append(opportunity)
            case .blue:
                dispatcherCards.append(opportunity)
                blueCards.append(opportunity)
            case .purple:
                dispatcherCards.append(opportunity)
                purpleCards.append(opportunity)
            case .red:
                redCards.append(opportunity)
            case .grey:
                greyCards.append(opportunity)
            }
        }

        return WealthGreenCheckpointRouting(
            greenCards: greenCards,
            dispatcherCards: dispatcherCards,
            blueCards: blueCards,
            purpleCards: purpleCards,
            redCards: redCards,
            greyCards: greyCards
        )
    }
}

@MainActor
class WealthCardHoldingStore: ObservableObject {
    @Published private(set) var cards: [Opportunity] = []
    @Published private(set) var cardKeys: [String] = []
    @Published private(set) var lastRefresh: Date?

    func sync(cards: [Opportunity], refreshTime: Date?) {
        self.cards = cards
        cardKeys = cards.map(WealthOpportunityLaneRules.laneKey)
        lastRefresh = refreshTime
    }

    func cachedCards(for refreshTime: Date?) -> [Opportunity]? {
        guard matches(refreshTime) else { return nil }
        return cards
    }

    private func matches(_ refreshTime: Date?) -> Bool {
        guard let lastRefresh else { return refreshTime == nil }
        guard let refreshTime else { return false }
        return abs(lastRefresh.timeIntervalSince(refreshTime)) < 0.001
    }
}
