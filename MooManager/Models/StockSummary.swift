import Foundation
import SwiftData

/// 종목 요약 정보 (홈 화면 카드에 표시)
struct StockSummary: Identifiable {
    let id: PersistentIdentifier
    let stock: Stock
    let currentPrice: Double
    let closePriceDate: Date?
    let rsiValue: Double?

    // 보유 현황
    let totalQuantity: Int
    let totalBuyAmount: Double
    let holdingBuyAmount: Double  // 보유분 매입금
    let realizedProfit: Double    // 실현 손익

    // 계산된 값들
    var averagePrice: Double {
        totalQuantity > 0 ? holdingBuyAmount / Double(totalQuantity) : 0
    }

    var valuation: Double {
        Double(totalQuantity) * currentPrice
    }

    var unrealizedProfit: Double {
        valuation - holdingBuyAmount
    }

    var unrealizedProfitRate: Double {
        holdingBuyAmount > 0 ? (unrealizedProfit / holdingBuyAmount) * 100 : 0
    }

    var tValue: Double {
        InfiniteBuyingCalculations.calculateTValue(
            totalBuyAmount: holdingBuyAmount,
            buyAmountPerTrade: stock.currentBuyAmount
        )
    }

    var starPercent: Double {
        InfiniteBuyingCalculations.calculateStarPercent(
            sellTargetPercent: stock.sellTargetPercent,
            divisions: stock.divisions,
            tValue: tValue
        )
    }

    var isFirstHalf: Bool {
        InfiniteBuyingCalculations.isFirstHalf(tValue: tValue, divisions: stock.divisions)
    }

    var isQuarterMode: Bool {
        tValue > Double(stock.divisions - 1) && tValue < Double(stock.divisions)
    }

    // 매수 가이드
    var starBuyPrice: Double {
        averagePrice * (1 + starPercent / 100)
    }

    var averageBuyPrice: Double {
        averagePrice
    }

    var starBuyQuantity: Int {
        let amount = isFirstHalf ? stock.currentBuyAmount / 2 : stock.currentBuyAmount
        return starBuyPrice > 0 ? Int(amount / starBuyPrice) : 0
    }

    var averageBuyQuantity: Int {
        guard isFirstHalf else { return 0 }
        return averageBuyPrice > 0 ? Int((stock.currentBuyAmount / 2) / averageBuyPrice) : 0
    }

    // 매도 가이드
    var starSellPrice: Double {
        averagePrice * (1 + starPercent / 100) + 0.01
    }

    var limitSellPrice: Double {
        averagePrice * (1 + stock.sellTargetPercent / 100)
    }

    var quarterSellQuantity: Int {
        totalQuantity / 4
    }

    var remainingSellQuantity: Int {
        totalQuantity - quarterSellQuantity
    }
}

// MARK: - Hashable for List
extension StockSummary: Hashable {
    static func == (lhs: StockSummary, rhs: StockSummary) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Portfolio Summary
struct PortfolioSummary {
    let stocks: [StockSummary]
    let updatedAt: Date

    var totalInvestment: Double {
        stocks.reduce(0) { $0 + $1.holdingBuyAmount }
    }

    var totalValuation: Double {
        stocks.reduce(0) { $0 + $1.valuation }
    }

    var totalUnrealizedProfit: Double {
        stocks.reduce(0) { $0 + $1.unrealizedProfit }
    }

    var totalRealizedProfit: Double {
        stocks.reduce(0) { $0 + $1.realizedProfit }
    }

    var totalProfitRate: Double {
        totalInvestment > 0 ? (totalUnrealizedProfit / totalInvestment) * 100 : 0
    }
}
