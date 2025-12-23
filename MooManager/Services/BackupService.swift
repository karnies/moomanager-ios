import Foundation
import SwiftData

/// JSON 백업/복원 서비스
class BackupService {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Import from JSON

    struct ImportResult {
        let stocks: Int
        let trades: Int
        let settlements: Int
    }

    func importFromJSON(url: URL) async throws -> ImportResult {
        // 파일 읽기
        let data = try Data(contentsOf: url)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        guard let json = json else {
            throw BackupError.invalidFormat
        }

        // 버전 체크
        guard json["version"] != nil else {
            throw BackupError.invalidFormat
        }

        // ID 매핑 (Flutter oldId -> Swift newStock)
        var stockIdMapping: [Int: Stock] = [:]

        var stocksImported = 0
        var tradesImported = 0
        var settlementsImported = 0

        // 1. 종목 가져오기
        if let stocksList = json["stocks"] as? [[String: Any]] {
            for stockData in stocksList {
                do {
                    let oldId = stockData["id"] as? Int ?? 0

                    let stock = Stock(
                        symbol: stockData["symbol"] as? String ?? "",
                        nickname: stockData["nickname"] as? String,
                        version: stockData["version"] as? String ?? "v3.0",
                        seedMoney: (stockData["seedMoney"] as? NSNumber)?.doubleValue ?? 0,
                        divisions: stockData["divisions"] as? Int ?? 20,
                        sellTargetPercent: (stockData["sellTargetPercent"] as? NSNumber)?.doubleValue ?? 15,
                        compoundRate: (stockData["compoundRate"] as? NSNumber)?.doubleValue ?? 50,
                        currentBuyAmount: (stockData["currentBuyAmount"] as? NSNumber)?.doubleValue,
                        accumulatedProfit: (stockData["accumulatedProfit"] as? NSNumber)?.doubleValue ?? 0,
                        startDate: parseDate(stockData["startDate"] as? String),
                        isActive: stockData["isActive"] as? Bool ?? true
                    )

                    modelContext.insert(stock)
                    stockIdMapping[oldId] = stock
                    stocksImported += 1
                } catch {
                    continue
                }
            }
        }

        // 저장 후 ID 매핑 확정
        try modelContext.save()

        // 2. 매매이력 가져오기
        if let tradesList = json["trades"] as? [[String: Any]] {
            for tradeData in tradesList {
                do {
                    let oldStockId = tradeData["stockId"] as? Int ?? 0
                    guard let stock = stockIdMapping[oldStockId] else { continue }

                    let tradeTypeStr = tradeData["tradeType"] as? String ?? "BUY"
                    let orderTypeStr = tradeData["orderType"] as? String ?? "LOC"

                    let trade = Trade(
                        stock: stock,
                        tradeDate: parseDate(tradeData["tradeDate"] as? String),
                        tradeType: TradeType(rawValue: tradeTypeStr) ?? .buy,
                        orderType: OrderType(rawValue: orderTypeStr) ?? .loc,
                        price: (tradeData["price"] as? NSNumber)?.doubleValue ?? 0,
                        quantity: tradeData["quantity"] as? Int ?? 0,
                        fee: (tradeData["fee"] as? NSNumber)?.doubleValue ?? 0
                    )

                    // isSettlement 복원
                    trade.isSettlement = tradeData["isSettlement"] as? Bool ?? false

                    modelContext.insert(trade)
                    tradesImported += 1
                } catch {
                    continue
                }
            }
        }

        // 3. 정산이력 가져오기
        if let settlementsList = json["settlements"] as? [[String: Any]] {
            for settData in settlementsList {
                do {
                    let oldStockId = settData["stockId"] as? Int ?? 0
                    let stock = stockIdMapping[oldStockId]

                    // Settlement 수동 생성 (init 없이)
                    let settlement = createSettlement(from: settData, stock: stock)

                    modelContext.insert(settlement)
                    settlementsImported += 1
                } catch {
                    continue
                }
            }
        }

        try modelContext.save()

        return ImportResult(
            stocks: stocksImported,
            trades: tradesImported,
            settlements: settlementsImported
        )
    }

    private func createSettlement(from data: [String: Any], stock: Stock?) -> Settlement {
        let settlement = Settlement(
            stock: stock ?? Stock(symbol: data["symbol"] as? String ?? "", seedMoney: 0),
            startDate: parseDate(data["startDate"] as? String),
            endDate: parseDate(data["endDate"] as? String),
            totalBuyAmount: (data["totalBuyAmount"] as? NSNumber)?.doubleValue ?? 0,
            totalSellAmount: (data["totalSellAmount"] as? NSNumber)?.doubleValue ?? 0,
            totalFee: (data["totalFee"] as? NSNumber)?.doubleValue ?? 0,
            buyCount: data["buyCount"] as? Int ?? 0,
            sellCount: data["sellCount"] as? Int ?? 0
        )

        // 백업 데이터에서 직접 복원
        settlement.symbol = data["symbol"] as? String ?? ""
        settlement.nickname = data["nickname"] as? String
        settlement.seedMoney = (data["seedMoney"] as? NSNumber)?.doubleValue ?? 0
        settlement.divisions = data["divisions"] as? Int ?? 20
        settlement.buyAmountPerTrade = (data["buyAmountPerTrade"] as? NSNumber)?.doubleValue ?? 0
        settlement.profit = (data["profit"] as? NSNumber)?.doubleValue ?? 0
        settlement.profitRate = (data["profitRate"] as? NSNumber)?.doubleValue ?? 0
        settlement.tradingDays = data["tradingDays"] as? Int ?? 0
        settlement.seedUsageRate = (data["seedUsageRate"] as? NSNumber)?.doubleValue ?? 0
        settlement.stock = stock

        return settlement
    }

    // MARK: - Export to JSON

    func exportToJSON() async throws -> Data {
        // 모든 데이터 조회
        let stocksDescriptor = FetchDescriptor<Stock>(sortBy: [SortDescriptor(\.createdAt)])
        let stocks = try modelContext.fetch(stocksDescriptor)

        let tradesDescriptor = FetchDescriptor<Trade>(sortBy: [SortDescriptor(\.tradeDate)])
        let trades = try modelContext.fetch(tradesDescriptor)

        let settlementsDescriptor = FetchDescriptor<Settlement>(sortBy: [SortDescriptor(\.createdAt)])
        let settlements = try modelContext.fetch(settlementsDescriptor)

        // Stock ID 매핑 생성 (PersistentIdentifier -> Int)
        var stockIdMap: [PersistentIdentifier: Int] = [:]
        for (index, stock) in stocks.enumerated() {
            stockIdMap[stock.persistentModelID] = index + 1
        }

        // JSON 생성
        let jsonData: [String: Any] = [
            "version": "1.0",
            "appName": "MooManager",
            "exportedAt": ISO8601DateFormatter().string(from: Date()),
            "stocks": stocks.enumerated().map { index, stock in
                [
                    "id": index + 1,
                    "symbol": stock.symbol,
                    "nickname": stock.nickname as Any,
                    "version": stock.version,
                    "seedMoney": stock.seedMoney,
                    "divisions": stock.divisions,
                    "sellTargetPercent": stock.sellTargetPercent,
                    "compoundRate": stock.compoundRate,
                    "currentBuyAmount": stock.currentBuyAmount,
                    "accumulatedProfit": stock.accumulatedProfit,
                    "startDate": ISO8601DateFormatter().string(from: stock.startDate),
                    "isActive": stock.isActive,
                    "createdAt": ISO8601DateFormatter().string(from: stock.createdAt)
                ]
            },
            "trades": trades.enumerated().map { index, trade in
                let stockId = trade.stock != nil ? stockIdMap[trade.stock!.persistentModelID] ?? 0 : 0
                return [
                    "id": index + 1,
                    "stockId": stockId,
                    "tradeDate": ISO8601DateFormatter().string(from: trade.tradeDate),
                    "tradeType": trade.tradeType,
                    "orderType": trade.orderType,
                    "price": trade.price,
                    "quantity": trade.quantity,
                    "fee": trade.fee,
                    "amount": trade.amount,
                    "isSettlement": trade.isSettlement,
                    "createdAt": ISO8601DateFormatter().string(from: trade.createdAt)
                ]
            },
            "settlements": settlements.enumerated().map { index, settlement in
                let stockId = settlement.stock != nil ? stockIdMap[settlement.stock!.persistentModelID] ?? 0 : 0
                return [
                    "id": index + 1,
                    "stockId": stockId,
                    "symbol": settlement.symbol,
                    "nickname": settlement.nickname as Any,
                    "startDate": ISO8601DateFormatter().string(from: settlement.startDate),
                    "endDate": ISO8601DateFormatter().string(from: settlement.endDate),
                    "seedMoney": settlement.seedMoney,
                    "divisions": settlement.divisions,
                    "buyAmountPerTrade": settlement.buyAmountPerTrade,
                    "totalBuyAmount": settlement.totalBuyAmount,
                    "totalSellAmount": settlement.totalSellAmount,
                    "totalFee": settlement.totalFee,
                    "profit": settlement.profit,
                    "profitRate": settlement.profitRate,
                    "buyCount": settlement.buyCount,
                    "sellCount": settlement.sellCount,
                    "tradingDays": settlement.tradingDays,
                    "seedUsageRate": settlement.seedUsageRate,
                    "createdAt": ISO8601DateFormatter().string(from: settlement.createdAt)
                ]
            }
        ]

        return try JSONSerialization.data(withJSONObject: jsonData, options: [.prettyPrinted, .sortedKeys])
    }

    // MARK: - Helpers

    private func parseDate(_ string: String?) -> Date {
        guard let string = string, !string.isEmpty else { return Date() }

        // Flutter의 toIso8601String() 형식: 2024-01-15T10:30:00.000Z 또는 2024-01-15T10:30:00.000
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)

        // 밀리초 + Z 포함
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
        if let date = dateFormatter.date(from: string) {
            return date
        }

        // 밀리초 포함 (Z 없음)
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS"
        if let date = dateFormatter.date(from: string) {
            return date
        }

        // 초까지만 + Z
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
        if let date = dateFormatter.date(from: string) {
            return date
        }

        // 초까지만 (Z 없음)
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        if let date = dateFormatter.date(from: string) {
            return date
        }

        // ISO8601DateFormatter 시도
        let iso8601Formatter = ISO8601DateFormatter()
        iso8601Formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso8601Formatter.date(from: string) {
            return date
        }

        iso8601Formatter.formatOptions = [.withInternetDateTime]
        if let date = iso8601Formatter.date(from: string) {
            return date
        }

        // 날짜만 있는 형식
        dateFormatter.dateFormat = "yyyy-MM-dd"
        if let date = dateFormatter.date(from: string) {
            return date
        }

        // yyyy-MM-dd HH:mm:ss 형식 (Flutter csv_service에서 사용)
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        if let date = dateFormatter.date(from: string) {
            return date
        }

        print("Failed to parse date: \(string)")
        return Date()
    }
}

// MARK: - Errors

enum BackupError: Error, LocalizedError {
    case invalidFormat
    case fileNotFound
    case exportFailed

    var errorDescription: String? {
        switch self {
        case .invalidFormat:
            return "유효하지 않은 백업 파일입니다"
        case .fileNotFound:
            return "파일을 찾을 수 없습니다"
        case .exportFailed:
            return "내보내기 실패"
        }
    }
}
