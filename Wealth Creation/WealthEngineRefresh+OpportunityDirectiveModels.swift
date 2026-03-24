import Foundation

struct WealthOpportunityDirectiveContext {
    let trustState: WealthTrustState
    let executionStyle: WealthExecutionStyle
    let permission: WealthPermissionState
    let hungerMode: WealthHungerMode
    let allocationPercent: Int
    let positionSizePercent: Int
    let conviction: WealthConvictionLevel
    let commandText: String
    let targetDirective: String
    let targetCoveragePercent: Int
    let sourceReliabilityScore: Int
    let shareReliabilityScore: Int
    let priorityScore: Int
    let trustReason: String
}
