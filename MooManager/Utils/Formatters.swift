import Foundation

/// 포맷터 유틸리티
struct Formatters {
    private static let currencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "$"
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter
    }()

    private static let currencyNoDecimalFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "$"
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 0
        return formatter
    }()

    private static let numberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        return formatter
    }()

    private static let integerFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter
    }()

    private static let percentFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        return formatter
    }()

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy.MM.dd"
        return formatter
    }()

    private static let shortDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM.dd"
        return formatter
    }()

    private static let yearMonthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "yyyy. MM월"
        return formatter
    }()

    private static let fullDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "yyyy년 M월 d일 (E)"
        return formatter
    }()

    // MARK: - Currency
    static func currency(_ value: Double) -> String {
        currencyFormatter.string(from: NSNumber(value: value)) ?? "$0.00"
    }

    static func currencyInt(_ value: Double) -> String {
        currencyNoDecimalFormatter.string(from: NSNumber(value: value)) ?? "$0"
    }

    static func profitCurrency(_ value: Double) -> String {
        let prefix = value >= 0 ? "+" : ""
        return prefix + currency(value)
    }

    // MARK: - Numbers
    static func number(_ value: Double) -> String {
        numberFormatter.string(from: NSNumber(value: value)) ?? "0"
    }

    static func integer(_ value: Int) -> String {
        integerFormatter.string(from: NSNumber(value: value)) ?? "0"
    }

    static func percent(_ value: Double) -> String {
        let prefix = value >= 0 ? "+" : ""
        return "\(prefix)\(percentFormatter.string(from: NSNumber(value: value)) ?? "0")%"
    }

    static func percentNoSign(_ value: Double) -> String {
        "\(percentFormatter.string(from: NSNumber(value: value)) ?? "0")%"
    }

    // MARK: - Dates
    static func date(_ date: Date) -> String {
        dateFormatter.string(from: date)
    }

    static func shortDate(_ date: Date) -> String {
        shortDateFormatter.string(from: date)
    }

    static func yearMonth(_ date: Date) -> String {
        yearMonthFormatter.string(from: date)
    }

    static func fullDate(_ date: Date) -> String {
        fullDateFormatter.string(from: date)
    }

    static func dateRange(start: Date, end: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yy.M.d"
        return "\(formatter.string(from: start)) ~ \(formatter.string(from: end))"
    }

    static func weekday(_ date: Date) -> String {
        let weekdays = ["일", "월", "화", "수", "목", "금", "토"]
        let index = Calendar.current.component(.weekday, from: date) - 1
        return weekdays[index]
    }

    // MARK: - Stock specific
    static func quantity(_ value: Int) -> String {
        "\(integer(value))주"
    }

    static func tValue(_ value: Double) -> String {
        String(format: "%.2fT", value)
    }

    static func price(_ value: Double) -> String {
        String(format: "$%.2f", value)
    }
}
