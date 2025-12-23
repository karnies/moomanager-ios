import SwiftUI
import SwiftData

struct TradeHistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Trade.tradeDate, order: .reverse) private var allTrades: [Trade]

    @State private var selectedMonth: Date = Date()
    @State private var showingAddTrade = false

    private var filteredTrades: [Trade] {
        let calendar = Calendar.current
        return allTrades.filter { trade in
            calendar.isDate(trade.tradeDate, equalTo: selectedMonth, toGranularity: .month)
        }
    }

    private var groupedTrades: [(Date, [Trade])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: filteredTrades) { trade in
            calendar.startOfDay(for: trade.tradeDate)
        }
        return grouped.sorted { $0.key > $1.key }
    }

    private var monthlyBuyAmount: Double {
        filteredTrades.filter { $0.isBuy }.reduce(0) { $0 + $1.amount }
    }

    private var monthlySellAmount: Double {
        filteredTrades.filter { !$0.isBuy }.reduce(0) { $0 + $1.amount }
    }

    var body: some View {
        NavigationStack {
            Group {
                if allTrades.isEmpty {
                    ContentUnavailableView {
                        Label("매매 내역 없음", systemImage: "clock")
                    } description: {
                        Text("아직 기록된 매매가 없습니다")
                    }
                } else {
                    List {
                        // 월 선택
                        Section {
                            MonthPicker(selectedMonth: $selectedMonth)
                        }

                        // 월간 요약
                        if !filteredTrades.isEmpty {
                            Section("월간 요약") {
                                HStack {
                                    Text("총 매수")
                                    Spacer()
                                    Text(Formatters.currency(monthlyBuyAmount))
                                        .foregroundStyle(.green)
                                }

                                HStack {
                                    Text("총 매도")
                                    Spacer()
                                    Text(Formatters.currency(monthlySellAmount))
                                        .foregroundStyle(.red)
                                }

                                HStack {
                                    Text("거래 횟수")
                                    Spacer()
                                    Text("\(filteredTrades.count)회")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }

                        // 일별 거래
                        ForEach(groupedTrades, id: \.0) { date, trades in
                            Section(Formatters.fullDate(date)) {
                                ForEach(trades) { trade in
                                    TradeRow(trade: trade)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("매매이력")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddTrade = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddTrade) {
                TradeAddView()
            }
        }
    }
}

// MARK: - Month Picker
struct MonthPicker: View {
    @Binding var selectedMonth: Date

    private var monthYearString: String {
        Formatters.yearMonth(selectedMonth)
    }

    var body: some View {
        HStack {
            Button {
                moveMonth(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title3)
                    .fontWeight(.semibold)
            }
            .buttonStyle(.plain)

            Spacer()

            Text(monthYearString)
                .font(.headline)

            Spacer()

            Button {
                moveMonth(by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.title3)
                    .fontWeight(.semibold)
            }
            .buttonStyle(.plain)
            .disabled(isCurrentMonth)
        }
        .padding(.vertical, 4)
    }

    private var isCurrentMonth: Bool {
        Calendar.current.isDate(selectedMonth, equalTo: Date(), toGranularity: .month)
    }

    private func moveMonth(by value: Int) {
        if let newDate = Calendar.current.date(byAdding: .month, value: value, to: selectedMonth) {
            // 미래 월로 이동하지 않도록
            if newDate <= Date() || value < 0 {
                selectedMonth = newDate
            }
        }
    }
}

// MARK: - Trade Row
struct TradeRow: View {
    let trade: Trade

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(trade.stock?.symbol ?? "Unknown")
                        .font(.headline)

                    Text(trade.tradeTypeEnum.displayName)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(trade.isBuy ? Color.green.opacity(0.2) : Color.red.opacity(0.2))
                        .foregroundStyle(trade.isBuy ? .green : .red)
                        .clipShape(Capsule())

                    Text(trade.orderTypeEnum.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text("\(Formatters.price(trade.price)) × \(trade.quantity)주")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(Formatters.currency(trade.amount))
                    .font(.subheadline)
                    .fontWeight(.medium)

                if trade.fee > 0 {
                    Text("수수료 \(Formatters.currency(trade.fee))")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    TradeHistoryView()
        .modelContainer(for: [Stock.self, Trade.self, Settlement.self, StockPrice.self], inMemory: true)
}
