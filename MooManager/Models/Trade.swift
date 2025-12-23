import Foundation
import SwiftData

enum TradeType: String, Codable, CaseIterable {
    case buy = "BUY"
    case sell = "SELL"

    var displayName: String {
        switch self {
        case .buy: return "매수"
        case .sell: return "매도"
        }
    }
}

enum OrderType: String, Codable, CaseIterable {
    case loc = "LOC"      // Limit on Close (장 시작가)
    case limit = "LIMIT"  // 지정가
    case moc = "MOC"      // Market on Close (장 마감가)

    var displayName: String {
        switch self {
        case .loc: return "LOC"
        case .limit: return "지정가"
        case .moc: return "MOC"
        }
    }
}

@Model
final class Trade {
    var stock: Stock?
    var tradeDate: Date
    var tradeType: String  // TradeType.rawValue
    var orderType: String  // OrderType.rawValue
    var price: Double
    var quantity: Int
    var fee: Double
    var amount: Double
    var isSettlement: Bool
    var createdAt: Date

    init(
        stock: Stock,
        tradeDate: Date = Date(),
        tradeType: TradeType,
        orderType: OrderType,
        price: Double,
        quantity: Int,
        fee: Double = 0
    ) {
        self.stock = stock
        self.tradeDate = tradeDate
        self.tradeType = tradeType.rawValue
        self.orderType = orderType.rawValue
        self.price = price
        self.quantity = quantity
        self.fee = fee
        self.amount = price * Double(quantity)
        self.isSettlement = false
        self.createdAt = Date()
    }

    var tradeTypeEnum: TradeType {
        TradeType(rawValue: tradeType) ?? .buy
    }

    var orderTypeEnum: OrderType {
        OrderType(rawValue: orderType) ?? .loc
    }

    var isBuy: Bool {
        tradeTypeEnum == .buy
    }

    var totalAmount: Double {
        if isBuy {
            return amount + fee
        } else {
            return amount - fee
        }
    }
}
