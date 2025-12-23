import SwiftUI
import SwiftData

struct SettlementView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Settlement.createdAt, order: .reverse) private var settlements: [Settlement]

    private var totalProfit: Double {
        settlements.reduce(0) { $0 + $1.profit }
    }

    private var totalFee: Double {
        settlements.reduce(0) { $0 + $1.totalFee }
    }

    var body: some View {
        NavigationStack {
            Group {
                if settlements.isEmpty {
                    ContentUnavailableView {
                        Label("정산 내역 없음", systemImage: "banknote")
                    } description: {
                        Text("아직 정산된 종목이 없습니다")
                    }
                } else {
                    List {
                        // 요약 섹션
                        Section("요약") {
                            HStack {
                                Text("총 정산 손익")
                                Spacer()
                                Text(Formatters.profitCurrency(totalProfit))
                                    .foregroundStyle(totalProfit >= 0 ? .green : .red)
                                    .fontWeight(.semibold)
                            }

                            HStack {
                                Text("총 수수료")
                                Spacer()
                                Text(Formatters.currency(totalFee))
                                    .foregroundStyle(.secondary)
                            }

                            HStack {
                                Text("정산 횟수")
                                Spacer()
                                Text("\(settlements.count)회")
                                    .foregroundStyle(.secondary)
                            }
                        }

                        // 정산 내역
                        Section("정산 내역") {
                            ForEach(settlements) { settlement in
                                SettlementRow(settlement: settlement)
                            }
                        }
                    }
                }
            }
            .navigationTitle("정산")
        }
    }
}

// MARK: - Settlement Row
struct SettlementRow: View {
    let settlement: Settlement

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(settlement.displayName)
                    .font(.headline)
                Text(settlement.version)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(Formatters.profitCurrency(settlement.profit))
                    .font(.headline)
                    .foregroundStyle(settlement.profit >= 0 ? .green : .red)
            }

            HStack {
                Text(Formatters.dateRange(start: settlement.startDate, end: settlement.endDate))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(settlement.tradingDays)일")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("매입")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Text(Formatters.currency(settlement.totalBuyAmount))
                        .font(.caption)
                }

                Spacer()

                VStack(alignment: .center, spacing: 2) {
                    Text("매도")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Text(Formatters.currency(settlement.totalSellAmount))
                        .font(.caption)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("수익률")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Text(Formatters.percent(settlement.profitRate))
                        .font(.caption)
                        .foregroundStyle(settlement.profitRate >= 0 ? .green : .red)
                }
            }

            HStack {
                Text("매수 \(settlement.buyCount)회 / 매도 \(settlement.sellCount)회")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Spacer()
                Text("수수료 \(Formatters.currency(settlement.totalFee))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    SettlementView()
        .modelContainer(for: [Stock.self, Trade.self, Settlement.self, StockPrice.self], inMemory: true)
}
