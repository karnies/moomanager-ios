import Foundation

/// Yahoo Finance API 서비스
actor YahooFinanceService {
    static let shared = YahooFinanceService()

    private let baseURL = "https://query1.finance.yahoo.com/v8/finance/chart"

    struct StockQuote {
        let symbol: String
        let currentPrice: Double
        let previousClose: Double
        let previousCloseDate: Date?
        let change: Double
        let changePercent: Double
    }

    struct RsiData {
        let symbol: String
        let rsi: Double
        let rsiChange: Double
        let recommend: Double
    }

    // MARK: - Public Methods

    /// 단일 종목 시세 조회
    func getQuote(symbol: String) async throws -> StockQuote {
        let url = URL(string: "\(baseURL)/\(symbol)?interval=1d&range=5d")!
        let (data, _) = try await URLSession.shared.data(from: url)

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let chart = json["chart"] as? [String: Any],
              let results = chart["result"] as? [[String: Any]],
              let result = results.first else {
            throw YahooFinanceError.invalidResponse
        }

        guard let meta = result["meta"] as? [String: Any],
              let regularMarketPrice = meta["regularMarketPrice"] as? Double else {
            throw YahooFinanceError.invalidResponse
        }

        // 전일 종가 및 날짜 추출
        var previousClose = meta["previousClose"] as? Double ?? regularMarketPrice
        var previousCloseDate: Date?

        if let indicators = result["indicators"] as? [String: Any],
           let quotes = indicators["quote"] as? [[String: Any]],
           let quote = quotes.first,
           let closes = quote["close"] as? [Double?],
           let timestamps = result["timestamp"] as? [Int] {

            // 마지막에서 두 번째 완료된 거래일의 종가
            let validCloses = closes.compactMap { $0 }
            if validCloses.count >= 2 {
                previousClose = validCloses[validCloses.count - 2]

                // 종가 날짜
                let validTimestamps = timestamps.suffix(validCloses.count)
                if validTimestamps.count >= 2 {
                    let index = validTimestamps.count - 2
                    let timestamp = Array(validTimestamps)[index]
                    previousCloseDate = Date(timeIntervalSince1970: TimeInterval(timestamp))
                }
            }
        }

        let change = regularMarketPrice - previousClose
        let changePercent = previousClose > 0 ? (change / previousClose) * 100 : 0

        return StockQuote(
            symbol: symbol,
            currentPrice: regularMarketPrice,
            previousClose: previousClose,
            previousCloseDate: previousCloseDate,
            change: change,
            changePercent: changePercent
        )
    }

    /// RSI 데이터 조회
    func getRsiData(symbol: String, period: Int = 14) async throws -> RsiData {
        let url = URL(string: "\(baseURL)/\(symbol)?interval=1d&range=30d")!
        let (data, _) = try await URLSession.shared.data(from: url)

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let chart = json["chart"] as? [String: Any],
              let results = chart["result"] as? [[String: Any]],
              let result = results.first,
              let indicators = result["indicators"] as? [String: Any],
              let quotes = indicators["quote"] as? [[String: Any]],
              let quote = quotes.first,
              let closes = quote["close"] as? [Double?] else {
            throw YahooFinanceError.invalidResponse
        }

        let validCloses = closes.compactMap { $0 }
        guard validCloses.count > period else {
            throw YahooFinanceError.insufficientData
        }

        let rsi = calculateRsi(closes: validCloses, period: period)
        let previousRsi = calculateRsi(closes: Array(validCloses.dropLast()), period: period)
        let rsiChange = rsi - previousRsi
        let recommend = InfiniteBuyingCalculations.calculateRsiRecommend(rsi: rsi)

        return RsiData(
            symbol: symbol,
            rsi: rsi,
            rsiChange: rsiChange,
            recommend: recommend
        )
    }

    /// 여러 종목 시세 조회
    func getQuotes(symbols: [String]) async throws -> [StockQuote] {
        try await withThrowingTaskGroup(of: StockQuote?.self) { group in
            for symbol in symbols {
                group.addTask {
                    try? await self.getQuote(symbol: symbol)
                }
            }

            var quotes: [StockQuote] = []
            for try await quote in group {
                if let quote = quote {
                    quotes.append(quote)
                }
            }
            return quotes
        }
    }

    // MARK: - Private Methods

    private func calculateRsi(closes: [Double], period: Int) -> Double {
        guard closes.count > period else { return 50 }

        var gains: [Double] = []
        var losses: [Double] = []

        for i in 1..<closes.count {
            let change = closes[i] - closes[i - 1]
            if change >= 0 {
                gains.append(change)
                losses.append(0)
            } else {
                gains.append(0)
                losses.append(abs(change))
            }
        }

        // Wilder's Smoothing
        var avgGain = gains.prefix(period).reduce(0, +) / Double(period)
        var avgLoss = losses.prefix(period).reduce(0, +) / Double(period)

        for i in period..<gains.count {
            avgGain = (avgGain * Double(period - 1) + gains[i]) / Double(period)
            avgLoss = (avgLoss * Double(period - 1) + losses[i]) / Double(period)
        }

        guard avgLoss > 0 else { return 100 }

        let rs = avgGain / avgLoss
        return 100 - (100 / (1 + rs))
    }
}

// MARK: - Errors
enum YahooFinanceError: Error, LocalizedError {
    case invalidResponse
    case insufficientData

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from Yahoo Finance"
        case .insufficientData:
            return "Insufficient data for calculation"
        }
    }
}
