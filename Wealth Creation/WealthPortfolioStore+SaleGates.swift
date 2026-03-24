import Foundation

extension WealthPortfolioStore {
    func saleGateKey(symbol: String, market: String) -> String {
        "\(symbol.uppercased())-\(market.uppercased())"
    }

    private func legacySaleGateKey(symbol: String) -> String {
        symbol.uppercased()
    }

    func lastSoldPrice(for symbol: String, market: String) -> Double? {
        let key = saleGateKey(symbol: symbol, market: market)
        return saleGates[key]?.lastSoldPrice ?? saleGates[legacySaleGateKey(symbol: symbol)]?.lastSoldPrice
    }

    func recordSoldPrice(_ price: Double, for symbol: String, market: String, soldAt: Date = .now) {
        let key = saleGateKey(symbol: symbol, market: market)
        let existing = saleGates[key]
        saleGates[key] = PersistedSaleGate(
            symbol: symbol,
            market: market,
            lastSoldPrice: price,
            soldAt: soldAt,
            cooldownUntil: existing?.cooldownUntil,
            cooldownReason: existing?.cooldownReason
        )
    }

    func buyCooldown(for symbol: String, market: String, now: Date = .now) -> (until: Date, reason: String)? {
        let key = saleGateKey(symbol: symbol, market: market)
        guard
            let gate = saleGates[key] ?? saleGates[legacySaleGateKey(symbol: symbol)],
            let cooldownUntil = gate.cooldownUntil,
            cooldownUntil > now
        else {
            return nil
        }

        return (cooldownUntil, gate.cooldownReason ?? "AI cooldown is active for this share.")
    }

    func setBuyCooldown(until: Date, for symbol: String, market: String, reason: String) {
        let key = saleGateKey(symbol: symbol, market: market)
        let existing = saleGates[key]
        saleGates[key] = PersistedSaleGate(
            symbol: symbol,
            market: market,
            lastSoldPrice: existing?.lastSoldPrice ?? 0,
            soldAt: existing?.soldAt ?? .distantPast,
            cooldownUntil: until,
            cooldownReason: reason
        )
    }

    func clearExpiredBuyCooldown(for symbol: String, market: String, now: Date = .now) {
        let key = saleGateKey(symbol: symbol, market: market)
        let legacyKey = legacySaleGateKey(symbol: symbol)
        guard
            let gate = saleGates[key] ?? saleGates[legacyKey],
            let cooldownUntil = gate.cooldownUntil,
            cooldownUntil <= now
        else {
            return
        }

        saleGates[legacyKey] = nil

        saleGates[key] = PersistedSaleGate(
            symbol: gate.symbol,
            market: gate.market,
            lastSoldPrice: gate.lastSoldPrice,
            soldAt: gate.soldAt,
            cooldownUntil: nil,
            cooldownReason: nil
        )
    }
}
