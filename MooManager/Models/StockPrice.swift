import Foundation
import SwiftData

@Model
final class StockPrice {
    @Attribute(.unique) var symbol: String
    var closePrice: Double
    var closePriceDate: Date?
    var rsiValue: Double?
    var rsiRecommend: Double?
    var rsiChange: Double?
    var updatedAt: Date

    init(
        symbol: String,
        closePrice: Double,
        closePriceDate: Date? = nil,
        rsiValue: Double? = nil,
        rsiRecommend: Double? = nil,
        rsiChange: Double? = nil
    ) {
        self.symbol = symbol
        self.closePrice = closePrice
        self.closePriceDate = closePriceDate
        self.rsiValue = rsiValue
        self.rsiRecommend = rsiRecommend
        self.rsiChange = rsiChange
        self.updatedAt = Date()
    }

    var isStale: Bool {
        let calendar = Calendar.current
        let now = Date()
        let hour = calendar.component(.hour, from: now)

        // 한국시간 기준 오전 8시 이후면 당일 업데이트 필요
        if hour >= 8 {
            return !calendar.isDateInToday(updatedAt)
        }
        return false
    }
}
