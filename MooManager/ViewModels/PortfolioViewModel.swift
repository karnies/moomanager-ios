import Foundation
import SwiftData
import Observation

@Observable
class PortfolioViewModel {
    var portfolioSummary: PortfolioSummary?
    var isLoading = false
    var errorMessage: String?

    private var modelContext: ModelContext?

    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
    }

    @MainActor
    func loadPortfolio() async {
        guard let context = modelContext else { return }

        isLoading = true
        errorMessage = nil

        do {
            // 활성 종목 조회
            let descriptor = FetchDescriptor<Stock>(
                predicate: #Predicate { $0.isActive },
                sortBy: [SortDescriptor(\.createdAt)]
            )
            let stocks = try context.fetch(descriptor)

            // 시세 업데이트
            await updatePrices(for: stocks)

            // 종목별 요약 생성
            var summaries: [StockSummary] = []
            for stock in stocks {
                if let summary = await createStockSummary(for: stock, context: context) {
                    summaries.append(summary)
                }
            }

            portfolioSummary = PortfolioSummary(stocks: summaries, updatedAt: Date())
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    @MainActor
    func refreshPrices() async {
        guard let context = modelContext else { return }

        isLoading = true

        do {
            let descriptor = FetchDescriptor<Stock>(
                predicate: #Predicate { $0.isActive }
            )
            let stocks = try context.fetch(descriptor)

            // 강제 시세 업데이트
            for stock in stocks {
                await updatePrice(for: stock.symbol, forceUpdate: true)
            }

            // 포트폴리오 재로드
            await loadPortfolio()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func updatePrices(for stocks: [Stock]) async {
        for stock in stocks {
            await updatePrice(for: stock.symbol, forceUpdate: false)
        }
    }

    private func updatePrice(for symbol: String, forceUpdate: Bool) async {
        guard let context = modelContext else { return }

        do {
            // 캐시된 가격 확인
            let descriptor = FetchDescriptor<StockPrice>(
                predicate: #Predicate { $0.symbol == symbol }
            )
            let cachedPrices = try context.fetch(descriptor)

            if let cached = cachedPrices.first, !cached.isStale, !forceUpdate {
                return // 캐시 사용
            }

            // Yahoo Finance에서 시세 조회
            let quote = try await YahooFinanceService.shared.getQuote(symbol: symbol)
            let rsiData = try? await YahooFinanceService.shared.getRsiData(symbol: symbol)

            print("📈 [\(symbol)] API 응답 - 종가: \(quote.previousClose), 날짜: \(String(describing: quote.previousCloseDate))")

            // 저장 또는 업데이트
            if let existing = cachedPrices.first {
                existing.closePrice = quote.previousClose
                existing.closePriceDate = quote.previousCloseDate
                existing.rsiValue = rsiData?.rsi
                existing.rsiRecommend = rsiData?.recommend
                existing.rsiChange = rsiData?.rsiChange
                existing.updatedAt = Date()
            } else {
                let newPrice = StockPrice(
                    symbol: symbol,
                    closePrice: quote.previousClose,
                    closePriceDate: quote.previousCloseDate,
                    rsiValue: rsiData?.rsi,
                    rsiRecommend: rsiData?.recommend,
                    rsiChange: rsiData?.rsiChange
                )
                context.insert(newPrice)
            }

            try context.save()
        } catch {
            print("Failed to update price for \(symbol): \(error)")
        }
    }

    @MainActor
    private func createStockSummary(for stock: Stock, context: ModelContext) async -> StockSummary? {
        // 시세 조회
        let stockSymbol = stock.symbol
        let priceDescriptor = FetchDescriptor<StockPrice>(
            predicate: #Predicate { $0.symbol == stockSymbol }
        )
        let currentPrice = (try? context.fetch(priceDescriptor).first?.closePrice) ?? 0
        let closePriceDate = try? context.fetch(priceDescriptor).first?.closePriceDate
        let rsiValue = try? context.fetch(priceDescriptor).first?.rsiValue

        // 미정산 거래 조회
        let trades = stock.trades.filter { !$0.isSettlement }

        var totalQuantity = 0
        var totalBuyAmount = 0.0
        var totalSellAmount = 0.0
        var totalBuyFee = 0.0
        var totalSellFee = 0.0

        for trade in trades {
            if trade.isBuy {
                totalQuantity += trade.quantity
                totalBuyAmount += trade.amount
                totalBuyFee += trade.fee
            } else {
                totalQuantity -= trade.quantity
                totalSellAmount += trade.amount
                totalSellFee += trade.fee
            }
        }

        // 보유분 매입금 계산
        let soldQuantity = trades.filter { !$0.isBuy }.reduce(0) { $0 + $1.quantity }
        let avgPrice = totalBuyAmount > 0 && (totalQuantity + soldQuantity) > 0
            ? totalBuyAmount / Double(totalQuantity + soldQuantity)
            : 0
        let holdingBuyAmount = avgPrice * Double(totalQuantity)

        // 실현 손익
        let realizedProfit = totalSellAmount - (avgPrice * Double(soldQuantity)) - totalSellFee

        return StockSummary(
            id: stock.persistentModelID,
            stock: stock,
            currentPrice: currentPrice,
            closePriceDate: closePriceDate,
            rsiValue: rsiValue,
            totalQuantity: totalQuantity,
            totalBuyAmount: totalBuyAmount,
            holdingBuyAmount: holdingBuyAmount,
            realizedProfit: realizedProfit
        )
    }
}
