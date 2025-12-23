import Foundation
import SwiftData

@Model
final class Settlement {
    var stock: Stock?
    var symbol: String
    var nickname: String?
    var version: String
    var startDate: Date
    var endDate: Date
    var seedMoney: Double
    var divisions: Int
    var buyAmountPerTrade: Double
    var totalBuyAmount: Double
    var totalSellAmount: Double
    var totalFee: Double
    var profit: Double
    var profitRate: Double
    var buyCount: Int
    var sellCount: Int
    var tradingDays: Int
    var seedUsageRate: Double
    var createdAt: Date

    init(
        stock: Stock,
        startDate: Date,
        endDate: Date,
        totalBuyAmount: Double,
        totalSellAmount: Double,
        totalFee: Double,
        buyCount: Int,
        sellCount: Int
    ) {
        self.stock = stock
        self.symbol = stock.symbol
        self.nickname = stock.nickname
        self.version = stock.version
        self.startDate = startDate
        self.endDate = endDate
        self.seedMoney = stock.seedMoney
        self.divisions = stock.divisions
        self.buyAmountPerTrade = stock.currentBuyAmount
        self.totalBuyAmount = totalBuyAmount
        self.totalSellAmount = totalSellAmount
        self.totalFee = totalFee
        let calculatedProfit = totalSellAmount - totalBuyAmount - totalFee
        self.profit = calculatedProfit
        self.profitRate = totalBuyAmount > 0 ? (calculatedProfit / totalBuyAmount) * 100 : 0
        self.buyCount = buyCount
        self.sellCount = sellCount

        let calendar = Calendar.current
        self.tradingDays = calendar.dateComponents([.day], from: startDate, to: endDate).day ?? 0

        self.seedUsageRate = (totalBuyAmount / stock.seedMoney) * 100
        self.createdAt = Date()
    }

    var displayName: String {
        if let nickname = nickname, !nickname.isEmpty {
            return "\(symbol) (\(nickname))"
        }
        return symbol
    }
}
