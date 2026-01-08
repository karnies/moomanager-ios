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
        // 미국 동부시간 캘린더 (서머타임 자동 처리)
        var usCalendar = Calendar(identifier: .gregorian)
        guard let easternTimeZone = TimeZone(identifier: "America/New_York") else {
            return true
        }
        usCalendar.timeZone = easternTimeZone

        let now = Date()
        let usHour = usCalendar.component(.hour, from: now)
        let isTodayTradingDay = USMarketHolidays.isTradingDay(now)
        let isMarketClosed = usHour >= 16 // 미국 장 마감: 오후 4시

        // 우리가 가져야 할 종가 날짜 계산
        // - 오늘이 거래일 + 장 마감 후: 어제 거래일 종가가 필요
        // - 그 외: 마지막 거래일 종가가 필요 (= 가장 최근 거래일)
        let expectedClosePriceDay: Date
        if isTodayTradingDay && isMarketClosed {
            // 장 마감 후: 어제 거래일 종가 (오늘 종가는 이미 확정되었지만, 우리 앱은 "전일 종가"를 표시)
            expectedClosePriceDay = USMarketHolidays.lastTradingDay(before: now)
        } else {
            // 장 마감 전 또는 휴장일: 마지막 거래일 종가
            expectedClosePriceDay = USMarketHolidays.lastTradingDay(before: now)
        }

        // 저장된 종가 날짜와 비교
        if let savedDate = closePriceDate {
            let savedDay = usCalendar.startOfDay(for: savedDate)
            let expectedDay = usCalendar.startOfDay(for: expectedClosePriceDay)

            // 저장된 종가가 기대하는 날짜와 같거나 이후면 fresh
            if savedDay >= expectedDay {
                return false
            }
        }

        // closePriceDate가 없거나 오래된 경우: stale
        return true
    }

}
