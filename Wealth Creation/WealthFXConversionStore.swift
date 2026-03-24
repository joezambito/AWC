import Foundation

enum WealthFXConversionStore {
    private static let fallbackRatesToAUD: [String: Double] = [
        "AUD": 1.0,
        "USD": 1.53,
        "CAD": 1.13,
        "GBP": 1.97,
        "EUR": 1.67,
        "JPY": 0.0102,
        "HKD": 0.197,
        "KRW": 0.00114,
        "TWD": 0.048,
        "NZD": 0.92,
        "BRL": 0.31,
        "MXN": 0.089,
        "ZAR": 0.082,
        "THB": 0.043,
        "IDR": 0.000094,
        "MYR": 0.34,
        "PHP": 0.027,
        "VND": 0.000060,
        "KWD": 4.98,
        "OMR": 3.97,
        "BHD": 4.05,
        "AED": 0.42,
        "SAR": 0.41,
        "ILS": 0.42,
        "TRY": 0.046,
        "PLN": 0.39,
        "NOK": 0.15
    ]

    static func fxQuoteKey(for currency: String) -> WealthBrokerQuoteKey? {
        let upper = currency.uppercased()
        guard upper != "AUD" else { return nil }
        return WealthBrokerQuoteKey(symbol: upper, market: "FX-AUD")
    }

    static func fxContract(for currency: String) -> WealthIBKRContract? {
        let upper = currency.uppercased()
        guard let key = fxQuoteKey(for: upper) else { return nil }

        return WealthIBKRContract(
            key: key,
            symbol: upper,
            secType: "CASH",
            exchange: "IDEALPRO",
            currency: "AUD"
        )
    }

    static func rateToAUD(for currency: String, quotes: [WealthBrokerQuoteKey: WealthBrokerQuote]) -> Double {
        let upper = currency.uppercased()
        if upper == "AUD" {
            return 1
        }

        if let key = fxQuoteKey(for: upper), let live = quotes[key], live.price > 0 {
            return live.price
        }

        return fallbackRatesToAUD[upper] ?? 1
    }
}
