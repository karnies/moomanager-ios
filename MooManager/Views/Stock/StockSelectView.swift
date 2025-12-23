import SwiftUI
import SwiftData

struct StockSelectView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var searchText = ""
    @State private var selectedSymbol: String?
    @State private var prices: [String: Double] = [:]
    @State private var isLoading = true

    private var filteredSymbols: [String] {
        if searchText.isEmpty {
            return InfiniteBuyingCalculations.supportedSymbols
        }
        return InfiniteBuyingCalculations.supportedSymbols.filter {
            $0.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("시세 조회 중...")
                } else {
                    List(filteredSymbols, id: \.self) { symbol in
                        Button {
                            selectedSymbol = symbol
                        } label: {
                            HStack {
                                Text(symbol)
                                    .font(.headline)

                                Spacer()

                                if let price = prices[symbol] {
                                    Text(Formatters.price(price))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .searchable(text: $searchText, prompt: "종목 검색")
                }
            }
            .navigationTitle("종목 선택")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("취소") {
                        dismiss()
                    }
                }
            }
            .sheet(item: $selectedSymbol) { symbol in
                StockAddView(symbol: symbol, currentPrice: prices[symbol] ?? 0)
            }
        }
        .task {
            await loadPrices()
        }
    }

    private func loadPrices() async {
        isLoading = true

        do {
            let quotes = try await YahooFinanceService.shared.getQuotes(
                symbols: InfiniteBuyingCalculations.supportedSymbols
            )

            var newPrices: [String: Double] = [:]
            for quote in quotes {
                newPrices[quote.symbol] = quote.previousClose
            }

            await MainActor.run {
                prices = newPrices
                isLoading = false
            }
        } catch {
            await MainActor.run {
                isLoading = false
            }
        }
    }
}

// MARK: - Identifiable for Sheet
extension String: @retroactive Identifiable {
    public var id: String { self }
}

#Preview {
    StockSelectView()
        .modelContainer(for: [Stock.self, Trade.self, Settlement.self, StockPrice.self], inMemory: true)
}
