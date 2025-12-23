import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = PortfolioViewModel()
    @State private var showingAddStock = false

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.portfolioSummary == nil {
                    ProgressView("불러오는 중...")
                } else if let portfolio = viewModel.portfolioSummary {
                    ScrollView {
                        VStack(spacing: 16) {
                            // 포트폴리오 요약
                            PortfolioSummaryCard(portfolio: portfolio)
                                .padding(.horizontal)

                            // 종목 카드 목록
                            LazyVStack(spacing: 12) {
                                ForEach(portfolio.stocks) { summary in
                                    NavigationLink(value: summary) {
                                        StockCard(summary: summary)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal)
                        }
                        .padding(.vertical)
                    }
                    .refreshable {
                        await viewModel.refreshPrices()
                    }
                } else {
                    ContentUnavailableView {
                        Label("종목이 없습니다", systemImage: "chart.line.uptrend.xyaxis")
                    } description: {
                        Text("새 종목을 추가해주세요")
                    } actions: {
                        Button("종목 추가") {
                            showingAddStock = true
                        }
                    }
                }
            }
            .navigationTitle("포트폴리오")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddStock = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .navigationDestination(for: StockSummary.self) { summary in
                StockDetailView(stock: summary.stock)
            }
            .sheet(isPresented: $showingAddStock) {
                StockSelectView()
            }
        }
        .task {
            viewModel.setModelContext(modelContext)
            await viewModel.loadPortfolio()
        }
    }
}

// MARK: - Portfolio Summary Card
struct PortfolioSummaryCard: View {
    let portfolio: PortfolioSummary

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("총 평가금")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(Formatters.currency(portfolio.totalValuation))
                    .font(.title2)
                    .fontWeight(.bold)
            }

            Divider()

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("총 투자금")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(Formatters.currency(portfolio.totalInvestment))
                        .font(.subheadline)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("평가손익")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 4) {
                        Text(Formatters.profitCurrency(portfolio.totalUnrealizedProfit))
                        Text("(\(Formatters.percent(portfolio.totalProfitRate)))")
                    }
                    .font(.subheadline)
                    .foregroundStyle(portfolio.totalUnrealizedProfit >= 0 ? .green : .red)
                }
            }

            if portfolio.totalRealizedProfit != 0 {
                HStack {
                    Text("실현손익")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(Formatters.profitCurrency(portfolio.totalRealizedProfit))
                        .font(.subheadline)
                        .foregroundStyle(portfolio.totalRealizedProfit >= 0 ? .green : .red)
                }
            }

            HStack {
                Spacer()
                Text("업데이트: \(Formatters.fullDate(portfolio.updatedAt))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Stock Card
struct StockCard: View {
    let summary: StockSummary

    var body: some View {
        VStack(spacing: 12) {
            // 헤더
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(summary.stock.displayName)
                        .font(.headline)
                    Text(summary.stock.version)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(Formatters.price(summary.currentPrice))
                        .font(.headline)
                    if let date = summary.closePriceDate {
                        Text(Formatters.shortDate(date))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            Divider()

            // 보유 정보
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("보유")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(Formatters.quantity(summary.totalQuantity))
                        .font(.subheadline)
                }

                Spacer()

                VStack(alignment: .center, spacing: 4) {
                    Text("평단")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(Formatters.price(summary.averagePrice))
                        .font(.subheadline)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("평가손익")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    VStack(alignment: .trailing, spacing: 0) {
                        Text(Formatters.profitCurrency(summary.unrealizedProfit))
                        Text(Formatters.percent(summary.unrealizedProfitRate))
                    }
                    .font(.subheadline)
                    .foregroundStyle(summary.unrealizedProfit >= 0 ? .green : .red)
                }
            }

            Divider()

            // T값 및 별%
            HStack {
                Label(Formatters.tValue(summary.tValue), systemImage: "t.square")
                    .font(.subheadline)

                Spacer()

                Label(Formatters.percent(summary.starPercent), systemImage: "star.fill")
                    .font(.subheadline)
                    .foregroundStyle(summary.starPercent >= 0 ? .orange : .purple)

                Spacer()

                Text(summary.isFirstHalf ? "전반전" : "후반전")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(summary.isFirstHalf ? Color.blue.opacity(0.2) : Color.orange.opacity(0.2))
                    .clipShape(Capsule())
            }

            // RSI
            if let rsi = summary.rsiValue {
                HStack {
                    Text("RSI")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(String(format: "%.1f", rsi))
                        .font(.subheadline)
                        .foregroundStyle(rsi <= 30 ? .green : (rsi >= 70 ? .red : .primary))
                    Spacer()
                }
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    HomeView()
        .modelContainer(for: [Stock.self, Trade.self, Settlement.self, StockPrice.self], inMemory: true)
}
