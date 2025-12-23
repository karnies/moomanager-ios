import SwiftUI
import SwiftData

struct TradeAddView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(filter: #Predicate<Stock> { $0.isActive }, sort: \Stock.symbol) private var stocks: [Stock]

    var preselectedStock: Stock?

    @State private var selectedStock: Stock?
    @State private var tradeType: TradeType = .buy
    @State private var orderType: OrderType = .loc
    @State private var tradeDate = Date()
    @State private var priceText = ""
    @State private var quantityText = ""
    @State private var feeText = "0"

    @State private var showingAlert = false
    @State private var alertMessage = ""

    private var amount: Double {
        let price = Double(priceText) ?? 0
        let quantity = Int(quantityText) ?? 0
        return price * Double(quantity)
    }

    var body: some View {
        NavigationStack {
            Form {
                // 종목 선택
                Section("종목") {
                    if let preselected = preselectedStock {
                        LabeledContent("종목", value: preselected.displayName)
                    } else {
                        Picker("종목", selection: $selectedStock) {
                            Text("선택").tag(nil as Stock?)
                            ForEach(stocks) { stock in
                                Text(stock.displayName).tag(stock as Stock?)
                            }
                        }
                    }
                }

                // 거래 유형
                Section("거래 유형") {
                    Picker("매매구분", selection: $tradeType) {
                        ForEach(TradeType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)

                    Picker("주문유형", selection: $orderType) {
                        ForEach(OrderType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                // 거래 정보
                Section("거래 정보") {
                    DatePicker("거래일", selection: $tradeDate, displayedComponents: .date)

                    HStack {
                        Text("가격")
                        Spacer()
                        TextField("$0.00", text: $priceText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                    }

                    HStack {
                        Text("수량")
                        Spacer()
                        TextField("0", text: $quantityText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                    }

                    HStack {
                        Text("수수료")
                        Spacer()
                        TextField("$0", text: $feeText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                    }
                }

                // 계산된 값
                Section("거래 금액") {
                    HStack {
                        Text("거래금액")
                        Spacer()
                        Text(Formatters.currency(amount))
                            .fontWeight(.semibold)
                    }

                    if let fee = Double(feeText), fee > 0 {
                        HStack {
                            Text(tradeType == .buy ? "총 지출" : "총 수령")
                            Spacer()
                            Text(Formatters.currency(tradeType == .buy ? amount + fee : amount - fee))
                                .foregroundStyle(tradeType == .buy ? .red : .green)
                        }
                    }
                }
            }
            .navigationTitle("매매 기록")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("취소") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("저장") {
                        saveTrade()
                    }
                    .fontWeight(.semibold)
                    .disabled(!isValid)
                }
            }
            .alert("오류", isPresented: $showingAlert) {
                Button("확인", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
        }
        .onAppear {
            if let preselected = preselectedStock {
                selectedStock = preselected
            }
        }
    }

    private var isValid: Bool {
        let stock = preselectedStock ?? selectedStock
        guard stock != nil else { return false }
        guard let price = Double(priceText), price > 0 else { return false }
        guard let quantity = Int(quantityText), quantity > 0 else { return false }
        return true
    }

    private func saveTrade() {
        guard let stock = preselectedStock ?? selectedStock else {
            alertMessage = "종목을 선택해주세요"
            showingAlert = true
            return
        }

        guard let price = Double(priceText), price > 0 else {
            alertMessage = "가격을 입력해주세요"
            showingAlert = true
            return
        }

        guard let quantity = Int(quantityText), quantity > 0 else {
            alertMessage = "수량을 입력해주세요"
            showingAlert = true
            return
        }

        let fee = Double(feeText) ?? 0

        let trade = Trade(
            stock: stock,
            tradeDate: tradeDate,
            tradeType: tradeType,
            orderType: orderType,
            price: price,
            quantity: quantity,
            fee: fee
        )

        modelContext.insert(trade)

        do {
            try modelContext.save()
            dismiss()
        } catch {
            alertMessage = "저장 실패: \(error.localizedDescription)"
            showingAlert = true
        }
    }
}

#Preview {
    TradeAddView()
        .modelContainer(for: [Stock.self, Trade.self, Settlement.self, StockPrice.self], inMemory: true)
}
