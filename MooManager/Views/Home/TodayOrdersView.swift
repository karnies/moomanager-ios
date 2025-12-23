import SwiftUI
import SwiftData

struct TodayOrdersView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = PortfolioViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.portfolioSummary == nil {
                    ProgressView("불러오는 중...")
                } else if let portfolio = viewModel.portfolioSummary, !portfolio.stocks.isEmpty {
                    List {
                        ForEach(portfolio.stocks.filter { $0.totalQuantity > 0 }) { summary in
                            Section(summary.stock.displayName) {
                                OrderGuideView(summary: summary)
                            }
                        }
                    }
                    .refreshable {
                        await viewModel.refreshPrices()
                    }
                } else {
                    ContentUnavailableView {
                        Label("주문 정보 없음", systemImage: "list.clipboard")
                    } description: {
                        Text("보유 중인 종목이 없습니다")
                    }
                }
            }
            .navigationTitle("오늘의 주문")
        }
        .task {
            viewModel.setModelContext(modelContext)
            await viewModel.loadPortfolio()
        }
    }
}

// MARK: - Order Guide View
struct OrderGuideView: View {
    let summary: StockSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 현재 상태
            HStack {
                Label(Formatters.tValue(summary.tValue), systemImage: "t.square")
                Spacer()
                Label(Formatters.percent(summary.starPercent), systemImage: "star.fill")
                    .foregroundStyle(summary.starPercent >= 0 ? .orange : .purple)
                Spacer()
                Text(summary.isQuarterMode ? "쿼터모드" : (summary.isFirstHalf ? "전반전" : "후반전"))
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(summary.isQuarterMode ? Color.red.opacity(0.2) : (summary.isFirstHalf ? Color.blue.opacity(0.2) : Color.orange.opacity(0.2)))
                    .clipShape(Capsule())
            }
            .font(.subheadline)

            Divider()

            // 매수 가이드
            if !summary.isQuarterMode {
                VStack(alignment: .leading, spacing: 8) {
                    Text("매수")
                        .font(.headline)
                        .foregroundStyle(.green)

                    if summary.isFirstHalf {
                        // 전반전: 1/2 별% + 1/2 평단
                        OrderRow(
                            type: "LOC",
                            label: "별% \(Formatters.percentNoSign(summary.starPercent))",
                            price: summary.starBuyPrice,
                            quantity: summary.starBuyQuantity
                        )
                        OrderRow(
                            type: "LOC",
                            label: "평단 0%",
                            price: summary.averageBuyPrice,
                            quantity: summary.averageBuyQuantity
                        )
                    } else {
                        // 후반전: 전체 별%
                        OrderRow(
                            type: "LOC",
                            label: "별% \(Formatters.percentNoSign(summary.starPercent))",
                            price: summary.starBuyPrice,
                            quantity: summary.starBuyQuantity
                        )
                    }
                }
            }

            Divider()

            // 매도 가이드
            VStack(alignment: .leading, spacing: 8) {
                Text("매도")
                    .font(.headline)
                    .foregroundStyle(.red)

                if summary.isQuarterMode {
                    // 쿼터모드: MOC 매도
                    OrderRow(
                        type: "MOC",
                        label: "1/4 수량",
                        price: nil,
                        quantity: summary.quarterSellQuantity
                    )
                } else {
                    // 일반: 별% LOC + 지정가
                    OrderRow(
                        type: "LOC",
                        label: "별% \(Formatters.percentNoSign(summary.starPercent))",
                        price: summary.starSellPrice,
                        quantity: summary.quarterSellQuantity
                    )
                }

                OrderRow(
                    type: "지정가",
                    label: "목표 \(Formatters.percentNoSign(summary.stock.sellTargetPercent))",
                    price: summary.limitSellPrice,
                    quantity: summary.remainingSellQuantity
                )
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Order Row
struct OrderRow: View {
    let type: String
    let label: String
    let price: Double?
    let quantity: Int

    var body: some View {
        HStack {
            Text(type)
                .font(.caption)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.secondary.opacity(0.2))
                .clipShape(Capsule())

            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            if let price = price {
                Text(Formatters.price(price))
                    .font(.subheadline)
                    .fontWeight(.medium)
            } else {
                Text("시장가")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Text("×")
                .foregroundStyle(.secondary)

            Text("\(quantity)주")
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }
}

#Preview {
    TodayOrdersView()
        .modelContainer(for: [Stock.self, Trade.self, Settlement.self, StockPrice.self], inMemory: true)
}
