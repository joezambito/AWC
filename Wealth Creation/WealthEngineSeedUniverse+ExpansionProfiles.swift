import Foundation

extension WealthEngineStore {
    static func profile(for tone: ExpandedTone) -> WealthExpandedSeedProfile {
        switch tone {
        case .surge:
            return WealthExpandedSeedProfile(technical: 84, fundamental: 72, alternative: 78, social: 74, institutional: 76, catalyst: 83, sectorFlow: 81, risk: 24, probability: 74, timeToTarget: "1-4 days", prospect: "SURGE SETUP", timeWindow: "HOURS", catalystBucket: "Momentum Catalyst", urgency: "WATCH", targetFitLabel: "COMP FIT", speedLabel: "FAST", dataQualityLabel: "FRESH", optionsFlow: 70, darkPool: 48, insider: 8, filing: 24, spreadBps: 13, slippageRisk: 14, earningsRisk: 12, macroRisk: 10, newsScore: 80, analysisAge: 28, dataAge: 2_400)
        case .active:
            return WealthExpandedSeedProfile(technical: 78, fundamental: 80, alternative: 63, social: 49, institutional: 74, catalyst: 72, sectorFlow: 74, risk: 19, probability: 70, timeToTarget: "3-7 days", prospect: "ACTIVE ROTATION", timeWindow: "HOURS", catalystBucket: "General Catalyst", urgency: "WATCH", targetFitLabel: "TARGET FIT", speedLabel: "ACTIVE", dataQualityLabel: "FRESH", optionsFlow: 54, darkPool: 40, insider: 6, filing: 28, spreadBps: 11, slippageRisk: 11, earningsRisk: 10, macroRisk: 9, newsScore: 74, analysisAge: 60, dataAge: 5_400)
        case .watch:
            return WealthExpandedSeedProfile(technical: 71, fundamental: 73, alternative: 56, social: 41, institutional: 64, catalyst: 65, sectorFlow: 67, risk: 26, probability: 64, timeToTarget: "4-10 days", prospect: "WATCHLIST BUILD", timeWindow: "DAYS", catalystBucket: "Rotation Catalyst", urgency: "WATCH", targetFitLabel: "WATCH FIT", speedLabel: "ACTIVE", dataQualityLabel: "FRESH", optionsFlow: 35, darkPool: 22, insider: 4, filing: 16, spreadBps: 17, slippageRisk: 17, earningsRisk: 9, macroRisk: 15, newsScore: 67, analysisAge: 100, dataAge: 9_000)
        case .monitor:
            return WealthExpandedSeedProfile(technical: 62, fundamental: 74, alternative: 39, social: 20, institutional: 52, catalyst: 50, sectorFlow: 56, risk: 28, probability: 58, timeToTarget: "1-3 weeks", prospect: "MONITOR FLOW", timeWindow: "DAYS", catalystBucket: "Allocation Catalyst", urgency: "MONITOR", targetFitLabel: "MISSION FIT", speedLabel: "STEADY", dataQualityLabel: "FRESH", optionsFlow: 18, darkPool: 12, insider: 2, filing: 12, spreadBps: 19, slippageRisk: 18, earningsRisk: 7, macroRisk: 19, newsScore: 58, analysisAge: 180, dataAge: 18_000)
        case .defensive:
            return WealthExpandedSeedProfile(technical: 55, fundamental: 82, alternative: 30, social: 12, institutional: 48, catalyst: 41, sectorFlow: 46, risk: 18, probability: 57, timeToTarget: "2-4 weeks", prospect: "DEFENSIVE WATCH", timeWindow: "WEEKS", catalystBucket: "Defensive Catalyst", urgency: "MONITOR", targetFitLabel: "MISSION FIT", speedLabel: "STEADY", dataQualityLabel: "FRESH", optionsFlow: 9, darkPool: 7, insider: 1, filing: 10, spreadBps: 10, slippageRisk: 10, earningsRisk: 6, macroRisk: 14, newsScore: 56, analysisAge: 220, dataAge: 21_600)
        case .speculative:
            return WealthExpandedSeedProfile(technical: 47, fundamental: 41, alternative: 58, social: 52, institutional: 24, catalyst: 44, sectorFlow: 39, risk: 46, probability: 49, timeToTarget: "1-2 weeks", prospect: "HIGH RISK WATCH", timeWindow: "HOURS", catalystBucket: "Recovery Catalyst", urgency: "LOW", targetFitLabel: "WATCH FIT", speedLabel: "SLOW", dataQualityLabel: "AGING", optionsFlow: 14, darkPool: 8, insider: 1, filing: 5, spreadBps: 28, slippageRisk: 30, earningsRisk: 10, macroRisk: 26, newsScore: 49, analysisAge: 260, dataAge: 32_400)
        }
    }

    static func adjustedProfile(
        base: WealthExpandedSeedProfile,
        shelfOnly: Bool
    ) -> WealthExpandedSeedProfile {
        guard shelfOnly else { return base }

        return WealthExpandedSeedProfile(
            technical: max(42, base.technical - 16),
            fundamental: max(46, base.fundamental - 10),
            alternative: max(30, base.alternative - 10),
            social: max(12, base.social - 10),
            institutional: max(24, base.institutional - 18),
            catalyst: max(28, base.catalyst - 16),
            sectorFlow: max(32, base.sectorFlow - 14),
            risk: min(68, base.risk + 14),
            probability: max(48, base.probability - 12),
            timeToTarget: "1-3 weeks",
            prospect: "CATALOG WATCH",
            timeWindow: "DAYS",
            catalystBucket: "Market Shelf",
            urgency: "MONITOR",
            targetFitLabel: "WATCH FIT",
            speedLabel: "MONITOR",
            dataQualityLabel: base.dataQualityLabel,
            optionsFlow: max(6, base.optionsFlow - 20),
            darkPool: max(4, base.darkPool - 16),
            insider: max(1, base.insider - 3),
            filing: max(6, base.filing - 10),
            spreadBps: base.spreadBps + 9,
            slippageRisk: base.slippageRisk + 12,
            earningsRisk: base.earningsRisk + 4,
            macroRisk: base.macroRisk + 8,
            newsScore: max(42, base.newsScore - 12),
            analysisAge: base.analysisAge + 180,
            dataAge: base.dataAge + 18_000
        )
    }
}
