import Foundation
import SwiftData

@Model
final class Stock {
    var symbol: String
    var nickname: String?
    var version: String  // "v2.2" or "v3.0"
    var seedMoney: Double
    var divisions: Int
    var sellTargetPercent: Double
    var compoundRate: Double  // 반복리 비율 (0-100)
    var currentBuyAmount: Double  // 현재 1회 매수금
    var accumulatedProfit: Double  // 누적수익
    var startDate: Date
    var isActive: Bool
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \Trade.stock)
    var trades: [Trade] = []

    @Relationship(deleteRule: .cascade, inverse: \Settlement.stock)
    var settlements: [Settlement] = []

    init(
        symbol: String,
        nickname: String? = nil,
        version: String = "v3.0",
        seedMoney: Double,
        divisions: Int = 20,
        sellTargetPercent: Double = 15.0,
        compoundRate: Double = 50.0,
        currentBuyAmount: Double? = nil,
        accumulatedProfit: Double = 0,
        startDate: Date = Date(),
        isActive: Bool = true
    ) {
        self.symbol = symbol
        self.nickname = nickname
        self.version = version
        self.seedMoney = seedMoney
        self.divisions = divisions
        self.sellTargetPercent = sellTargetPercent
        self.compoundRate = compoundRate
        self.currentBuyAmount = currentBuyAmount ?? (seedMoney / Double(divisions))
        self.accumulatedProfit = accumulatedProfit
        self.startDate = startDate
        self.isActive = isActive
        self.createdAt = Date()
    }

    var displayName: String {
        if let nickname = nickname, !nickname.isEmpty {
            return "\(symbol) (\(nickname))"
        }
        return symbol
    }

    var initialBuyAmount: Double {
        seedMoney / Double(divisions)
    }
}

// MARK: - Version Presets
extension Stock {
    static func defaultSettings(for symbol: String, version: String) -> (divisions: Int, sellTargetPercent: Double, compoundRate: Double) {
        let isSoxl = symbol.uppercased() == "SOXL"

        if version == "v3.0" {
            return (
                divisions: 20,
                sellTargetPercent: isSoxl ? 20.0 : 15.0,
                compoundRate: 50.0
            )
        } else {
            // v2.2
            return (
                divisions: 40,
                sellTargetPercent: isSoxl ? 12.0 : 10.0,
                compoundRate: 0.0
            )
        }
    }
}
