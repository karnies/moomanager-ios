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
        // 한국 타임존 기준으로 판단
        var calendar = Calendar(identifier: .gregorian)
        guard let koreaTimeZone = TimeZone(identifier: "Asia/Seoul") else {
            return true // 타임존 생성 실패시 갱신 시도
        }
        calendar.timeZone = koreaTimeZone

        let now = Date()
        let koreaHour = calendar.component(.hour, from: now)

        // 미국 장 마감 시간: 한국시간 오전 6시(서머타임) ~ 7시(표준시)
        // 여유를 두고 오전 7시 기준으로 판단
        let marketCloseHourKST = 7

        // 현재 시점 기준 마지막 거래일 계산 (주말 + 휴장일 고려)
        let lastTradingDay = USMarketHolidays.lastTradingDay(before: now)

        // 마지막 거래일의 장 마감 시간 (한국시간 오전 7시)
        guard let lastTradingDayKST = convertToKoreaTime(lastTradingDay, calendar: calendar),
              let lastMarketClose = calendar.date(byAdding: .day, value: 1, to: lastTradingDayKST),
              let lastMarketCloseTime = calendar.date(bySettingHour: marketCloseHourKST, minute: 0, second: 0, of: lastMarketClose) else {
            return true
        }

        // 오늘이 거래일이고 장 마감 후(오전 7시 이후)라면, 오늘 데이터가 필요
        if USMarketHolidays.isTradingDay(now) && koreaHour >= marketCloseHourKST {
            guard let todayMarketClose = calendar.date(bySettingHour: marketCloseHourKST, minute: 0, second: 0, of: now) else {
                return true
            }
            return updatedAt < todayMarketClose
        }

        // 그 외의 경우: 마지막 거래일 장 마감 이후 업데이트 되었는지 확인
        return updatedAt < lastMarketCloseTime
    }

    /// 미국 동부시간 날짜를 한국시간으로 변환
    private func convertToKoreaTime(_ date: Date, calendar: Calendar) -> Date? {
        // 미국 동부시간 기준 날짜의 시작을 한국시간으로
        var usCalendar = Calendar(identifier: .gregorian)
        usCalendar.timeZone = TimeZone(identifier: "America/New_York")!
        let startOfDay = usCalendar.startOfDay(for: date)
        return startOfDay
    }
}
