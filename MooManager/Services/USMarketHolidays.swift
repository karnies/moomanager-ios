import Foundation

/// 미국 주식시장(NYSE/NASDAQ) 휴장일 관리
/// - NYSE 공식 휴장일: https://www.nyse.com/markets/hours-calendars
/// - 매년 초에 다음 연도 휴장일 추가 필요
struct USMarketHolidays {

    /// 휴장일 목록 (연도별)
    /// - Note: 연도가 없으면 API 응답 기반으로 fallback 처리됨
    private static let holidays: [Int: [DateComponents]] = [
        2025: [
            DateComponents(year: 2025, month: 1, day: 1),   // New Year's Day
            DateComponents(year: 2025, month: 1, day: 20),  // MLK Day
            DateComponents(year: 2025, month: 2, day: 17),  // Presidents' Day
            DateComponents(year: 2025, month: 4, day: 18),  // Good Friday
            DateComponents(year: 2025, month: 5, day: 26),  // Memorial Day
            DateComponents(year: 2025, month: 6, day: 19),  // Juneteenth
            DateComponents(year: 2025, month: 7, day: 4),   // Independence Day
            DateComponents(year: 2025, month: 9, day: 1),   // Labor Day
            DateComponents(year: 2025, month: 11, day: 27), // Thanksgiving
            DateComponents(year: 2025, month: 12, day: 25), // Christmas
        ],
        2026: [
            DateComponents(year: 2026, month: 1, day: 1),   // New Year's Day
            DateComponents(year: 2026, month: 1, day: 19),  // MLK Day
            DateComponents(year: 2026, month: 2, day: 16),  // Presidents' Day
            DateComponents(year: 2026, month: 4, day: 3),   // Good Friday
            DateComponents(year: 2026, month: 5, day: 25),  // Memorial Day
            DateComponents(year: 2026, month: 6, day: 19),  // Juneteenth
            DateComponents(year: 2026, month: 7, day: 3),   // Independence Day (observed)
            DateComponents(year: 2026, month: 9, day: 7),   // Labor Day
            DateComponents(year: 2026, month: 11, day: 26), // Thanksgiving
            DateComponents(year: 2026, month: 12, day: 25), // Christmas
        ],
        2027: [
            DateComponents(year: 2027, month: 1, day: 1),   // New Year's Day
            DateComponents(year: 2027, month: 1, day: 18),  // MLK Day
            DateComponents(year: 2027, month: 2, day: 15),  // Presidents' Day
            DateComponents(year: 2027, month: 3, day: 26),  // Good Friday
            DateComponents(year: 2027, month: 5, day: 31),  // Memorial Day
            DateComponents(year: 2027, month: 6, day: 18),  // Juneteenth (observed)
            DateComponents(year: 2027, month: 7, day: 5),   // Independence Day (observed)
            DateComponents(year: 2027, month: 9, day: 6),   // Labor Day
            DateComponents(year: 2027, month: 11, day: 25), // Thanksgiving
            DateComponents(year: 2027, month: 12, day: 24), // Christmas (observed)
        ]
    ]

    /// 특정 날짜가 휴장일인지 확인
    /// - Parameter date: 확인할 날짜 (미국 동부시간 기준으로 변환됨)
    /// - Returns: 휴장일이면 true
    static func isHoliday(_ date: Date) -> Bool {
        // 미국 동부시간 기준으로 변환
        var calendar = Calendar(identifier: .gregorian)
        guard let easternTimeZone = TimeZone(identifier: "America/New_York") else {
            return false
        }
        calendar.timeZone = easternTimeZone

        let year = calendar.component(.year, from: date)
        let month = calendar.component(.month, from: date)
        let day = calendar.component(.day, from: date)

        guard let yearHolidays = holidays[year] else {
            // 해당 연도 휴장일 정보가 없으면 false 반환 (갱신 시도하도록)
            return false
        }

        return yearHolidays.contains { components in
            components.month == month && components.day == day
        }
    }

    /// 특정 날짜가 거래일인지 확인 (주말 + 휴장일 체크)
    /// - Parameter date: 확인할 날짜
    /// - Returns: 거래일이면 true
    static func isTradingDay(_ date: Date) -> Bool {
        var calendar = Calendar(identifier: .gregorian)
        guard let easternTimeZone = TimeZone(identifier: "America/New_York") else {
            return true
        }
        calendar.timeZone = easternTimeZone

        let weekday = calendar.component(.weekday, from: date)

        // 주말 체크 (1=일, 7=토)
        if weekday == 1 || weekday == 7 {
            return false
        }

        // 휴장일 체크
        if isHoliday(date) {
            return false
        }

        return true
    }

    /// 특정 날짜 기준 마지막 거래일 반환
    /// - Parameter date: 기준 날짜
    /// - Returns: 가장 최근 거래일 (기준 날짜가 거래일이면 전일 거래일)
    static func lastTradingDay(before date: Date) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        guard let easternTimeZone = TimeZone(identifier: "America/New_York") else {
            return date
        }
        calendar.timeZone = easternTimeZone

        var checkDate = calendar.date(byAdding: .day, value: -1, to: date) ?? date

        // 최대 10일 전까지 탐색 (긴 연휴 대비)
        for _ in 0..<10 {
            if isTradingDay(checkDate) {
                return checkDate
            }
            checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate) ?? checkDate
        }

        return checkDate
    }

    /// 현재 연도의 휴장일 정보가 있는지 확인
    static func hasHolidaysForCurrentYear() -> Bool {
        let year = Calendar.current.component(.year, from: Date())
        return holidays[year] != nil
    }

    /// 다음 연도의 휴장일 정보가 있는지 확인
    static func hasHolidaysForNextYear() -> Bool {
        let nextYear = Calendar.current.component(.year, from: Date()) + 1
        return holidays[nextYear] != nil
    }
}
