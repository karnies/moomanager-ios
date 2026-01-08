import SwiftUI
import SwiftData

struct StockDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Bindable var stock: Stock

    @State private var showingEditSheet = false
    @State private var showingAddTrade = false
    @State private var showingSettlementAlert = false
    @State private var showingDeleteAlert = false

    var body: some View {
        List {
            // 기본 정보
            Section("기본 정보") {
                LabeledContent("종목", value: stock.symbol)

                if let nickname = stock.nickname, !nickname.isEmpty {
                    LabeledContent("별칭", value: nickname)
                }

                LabeledContent("버전", value: stock.version)
                LabeledContent("시작일", value: Formatters.date(stock.startDate))
            }

            // 투자 설정
            Section("투자 설정") {
                LabeledContent("시드머니", value: Formatters.currency(stock.seedMoney))
                LabeledContent("분할수", value: "\(stock.divisions)")
                LabeledContent("매도목표%", value: Formatters.percentNoSign(stock.sellTargetPercent))

                if stock.version == "v3.0" {
                    LabeledContent("반복리 비율", value: Formatters.percentNoSign(stock.compoundRate))
                }

                LabeledContent("1회 매수금", value: Formatters.currency(stock.currentBuyAmount))
            }

            // 누적 수익
            Section("누적 수익") {
                LabeledContent("누적 수익") {
                    Text(Formatters.profitCurrency(stock.accumulatedProfit))
                        .foregroundStyle(stock.accumulatedProfit >= 0 ? .green : .red)
                }
            }

            // 최근 거래
            Section("최근 거래") {
                let recentTrades = stock.trades.filter { !$0.isSettlement }.suffix(5)

                if recentTrades.isEmpty {
                    Text("거래 내역이 없습니다")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(recentTrades)) { trade in
                        TradeRow(trade: trade)
                    }
                }

                Button("매매 기록 추가") {
                    showingAddTrade = true
                }
            }

            // 관리
            Section {
                Button("설정 수정") {
                    showingEditSheet = true
                }

                Button("정산하기") {
                    showingSettlementAlert = true
                }
                .foregroundStyle(.orange)

                Button("종목 삭제", role: .destructive) {
                    showingDeleteAlert = true
                }
            }
        }
        .navigationTitle(stock.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingEditSheet) {
            StockEditView(stock: stock)
        }
        .sheet(isPresented: $showingAddTrade) {
            TradeAddView(preselectedStock: stock)
        }
        .alert("정산 확인", isPresented: $showingSettlementAlert) {
            Button("취소", role: .cancel) { }
            Button("정산", role: .destructive) {
                performSettlement()
            }
        } message: {
            Text("이 종목을 정산하시겠습니까? 모든 미정산 거래가 정산 처리됩니다.")
        }
        .alert("삭제 확인", isPresented: $showingDeleteAlert) {
            Button("취소", role: .cancel) { }
            Button("삭제", role: .destructive) {
                deleteStock()
            }
        } message: {
            Text("이 종목을 삭제하시겠습니까? 모든 거래 내역도 함께 삭제됩니다.")
        }
    }

    private func performSettlement() {
        let unsettledTrades = stock.trades.filter { !$0.isSettlement }
        guard !unsettledTrades.isEmpty else { return }

        // 거래 데이터 계산
        let buyTrades = unsettledTrades.filter { $0.isBuy }
        let sellTrades = unsettledTrades.filter { !$0.isBuy }

        let totalBuyAmount = buyTrades.reduce(0) { $0 + $1.amount }
        let totalSellAmount = sellTrades.reduce(0) { $0 + $1.amount }
        let totalFee = unsettledTrades.reduce(0) { $0 + $1.fee }

        let startDate = unsettledTrades.map { $0.tradeDate }.min() ?? Date()
        let endDate = unsettledTrades.map { $0.tradeDate }.max() ?? Date()

        // 정산 생성
        let settlement = Settlement(
            stock: stock,
            startDate: startDate,
            endDate: endDate,
            totalBuyAmount: totalBuyAmount,
            totalSellAmount: totalSellAmount,
            totalFee: totalFee,
            buyCount: buyTrades.count,
            sellCount: sellTrades.count
        )

        modelContext.insert(settlement)

        // 거래 정산 표시
        for trade in unsettledTrades {
            trade.isSettlement = true
        }

        // 누적 수익 업데이트
        stock.accumulatedProfit += settlement.profit

        // 종목 비활성화 (포트폴리오에서 숨김)
        stock.isActive = false

        // 반복리 적용
        if stock.compoundRate > 0 {
            stock.currentBuyAmount = InfiniteBuyingCalculations.calculateNewBuyAmount(
                currentBuyAmount: stock.currentBuyAmount,
                profit: settlement.profit,
                compoundRate: stock.compoundRate,
                seedMoney: stock.seedMoney,
                divisions: stock.divisions
            )
        }

        try? modelContext.save()
        dismiss()
    }

    private func deleteStock() {
        modelContext.delete(stock)
        try? modelContext.save()
        dismiss()
    }
}

#Preview {
    NavigationStack {
        StockDetailView(stock: Stock(symbol: "TQQQ", seedMoney: 10000))
    }
    .modelContainer(for: [Stock.self, Trade.self, Settlement.self, StockPrice.self], inMemory: true)
}
