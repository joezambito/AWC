import Combine
import SwiftUI

@MainActor
final class WealthBehaviorSettingsStore: ObservableObject {
    static let shared = WealthBehaviorSettingsStore()

    static let defaultBuyGate = 60
    static let defaultTargetFit = 0.12
    static let defaultRotateEdge = 5
    static let defaultFeeEdgeMult = 1.5
    static let defaultProfitLock = 8.0

    private enum StorageKey {
        static let buyGate = "awc_behavior_buy_gate"
        static let targetFit = "awc_behavior_target_fit"
        static let rotateEdge = "awc_behavior_rotate_edge"
        static let feeEdgeMult = "awc_behavior_fee_edge_mult"
        static let profitLock = "awc_behavior_profit_lock_pct"
    }

    @Published var buyGate: Int {
        didSet { defaults.set(buyGate, forKey: StorageKey.buyGate) }
    }

    @Published var targetFit: Double {
        didSet { defaults.set(targetFit, forKey: StorageKey.targetFit) }
    }

    @Published var rotateEdge: Int {
        didSet { defaults.set(rotateEdge, forKey: StorageKey.rotateEdge) }
    }

    @Published var feeEdgeMult: Double {
        didSet { defaults.set(feeEdgeMult, forKey: StorageKey.feeEdgeMult) }
    }

    @Published var profitLock: Double {
        didSet { defaults.set(profitLock, forKey: StorageKey.profitLock) }
    }

    private let defaults: UserDefaults

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        buyGate = defaults.object(forKey: StorageKey.buyGate) as? Int ?? Self.defaultBuyGate
        targetFit = defaults.object(forKey: StorageKey.targetFit) as? Double ?? Self.defaultTargetFit
        rotateEdge = defaults.object(forKey: StorageKey.rotateEdge) as? Int ?? Self.defaultRotateEdge
        feeEdgeMult = defaults.object(forKey: StorageKey.feeEdgeMult) as? Double ?? Self.defaultFeeEdgeMult
        profitLock = defaults.object(forKey: StorageKey.profitLock) as? Double ?? Self.defaultProfitLock
    }

    var isFactoryDefault: Bool {
        buyGate == Self.defaultBuyGate &&
        abs(targetFit - Self.defaultTargetFit) < 0.0001 &&
        rotateEdge == Self.defaultRotateEdge &&
        abs(feeEdgeMult - Self.defaultFeeEdgeMult) < 0.0001 &&
        abs(profitLock - Self.defaultProfitLock) < 0.0001
    }

    func resetToFactoryDefaults() {
        buyGate = Self.defaultBuyGate
        targetFit = Self.defaultTargetFit
        rotateEdge = Self.defaultRotateEdge
        feeEdgeMult = Self.defaultFeeEdgeMult
        profitLock = Self.defaultProfitLock
    }
}

@MainActor
final class WealthProtectionSettingsStore: ObservableObject {
    static let shared = WealthProtectionSettingsStore()

    static let defaultFloorReserve: Double = 0
    static let defaultDemoBalance: Double = 0
    static let defaultShieldPercent: Double = 35
    static let defaultProfitTargetValue: Double = 150
    static let defaultSurgeOverridePercent: Double = 12

    private enum StorageKey {
        static let killSwitch = "awc_protection_kill_switch"
        static let shieldPercent = "awc_protection_shield_percent"
        static let profitTargetValue = "awc_protection_profit_target"
        static let floorReserve = "awc_protection_floor_reserve"
        static let surgeEnabled = "awc_protection_surge_enabled"
        static let surgeOverridePercent = "awc_protection_surge_override_percent"
        static let speedAlertEnabled = "awc_protection_speed_alert_enabled"
        static let capitalAlertEnabled = "awc_protection_capital_alert_enabled"
        static let baseCurrency = "awc_protection_base_currency"
        static let demoBalance = "awc_protection_demo_balance"
        static let demoMode = "awc_protection_demo_mode"
    }

    @Published var killSwitch: Bool {
        didSet { defaults.set(killSwitch, forKey: StorageKey.killSwitch) }
    }

    @Published var shieldPercent: Double {
        didSet { defaults.set(shieldPercent, forKey: StorageKey.shieldPercent) }
    }

    @Published var profitTargetValue: Double {
        didSet { defaults.set(profitTargetValue, forKey: StorageKey.profitTargetValue) }
    }

    @Published var floorReserve: Double {
        didSet { defaults.set(floorReserve, forKey: StorageKey.floorReserve) }
    }

    @Published var surgeEnabled: Bool {
        didSet { defaults.set(surgeEnabled, forKey: StorageKey.surgeEnabled) }
    }

    @Published var surgeOverridePercent: Double {
        didSet { defaults.set(surgeOverridePercent, forKey: StorageKey.surgeOverridePercent) }
    }

    @Published var speedAlertEnabled: Bool {
        didSet { defaults.set(speedAlertEnabled, forKey: StorageKey.speedAlertEnabled) }
    }

    @Published var capitalAlertEnabled: Bool {
        didSet { defaults.set(capitalAlertEnabled, forKey: StorageKey.capitalAlertEnabled) }
    }

    @Published var baseCurrency: String {
        didSet { defaults.set(baseCurrency, forKey: StorageKey.baseCurrency) }
    }

    @Published var demoBalance: Double {
        didSet { defaults.set(demoBalance, forKey: StorageKey.demoBalance) }
    }

    @Published var demoMode: Bool {
        didSet { defaults.set(demoMode, forKey: StorageKey.demoMode) }
    }

    private let defaults: UserDefaults

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        killSwitch = defaults.object(forKey: StorageKey.killSwitch) as? Bool ?? false
        shieldPercent = defaults.object(forKey: StorageKey.shieldPercent) as? Double ?? Self.defaultShieldPercent
        profitTargetValue = defaults.object(forKey: StorageKey.profitTargetValue) as? Double ?? Self.defaultProfitTargetValue
        floorReserve = defaults.object(forKey: StorageKey.floorReserve) as? Double ?? Self.defaultFloorReserve
        surgeEnabled = defaults.object(forKey: StorageKey.surgeEnabled) as? Bool ?? true
        surgeOverridePercent = defaults.object(forKey: StorageKey.surgeOverridePercent) as? Double ?? Self.defaultSurgeOverridePercent
        speedAlertEnabled = defaults.object(forKey: StorageKey.speedAlertEnabled) as? Bool ?? true
        capitalAlertEnabled = defaults.object(forKey: StorageKey.capitalAlertEnabled) as? Bool ?? true
        baseCurrency = defaults.string(forKey: StorageKey.baseCurrency) ?? "AUD"
        demoBalance = defaults.object(forKey: StorageKey.demoBalance) as? Double ?? Self.defaultDemoBalance
        demoMode = defaults.object(forKey: StorageKey.demoMode) as? Bool ?? false
    }

    func resetToFactoryDefaults() {
        killSwitch = false
        shieldPercent = Self.defaultShieldPercent
        profitTargetValue = Self.defaultProfitTargetValue
        floorReserve = Self.defaultFloorReserve
        surgeEnabled = true
        surgeOverridePercent = Self.defaultSurgeOverridePercent
        speedAlertEnabled = true
        capitalAlertEnabled = true
        baseCurrency = "AUD"
        demoBalance = Self.defaultDemoBalance
        demoMode = false
    }
}
