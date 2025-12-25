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
    @State private var profitText = ""
    @State private var manualProfitMode = false

    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var showingStockPicker = false
    @State private var showingDatePicker = false
    @FocusState private var focusedField: Field?

    enum Field: Hashable {
        case price, quantity, fee, profit
    }

    // 종목별 데이터
    @State private var currentPrice: Double = 0
    @State private var averagePrice: Double = 0
    @State private var totalQuantity: Int = 0

    private var amount: Double {
        let price = Double(priceText) ?? 0
        let quantity = Int(quantityText) ?? 0
        return price * Double(quantity)
    }

    /// 평균단가 대비 예상 손익 계산
    private var calculatedProfit: Double {
        guard averagePrice > 0 else { return 0 }
        let sellPrice = Double(priceText) ?? 0
        let quantity = Int(quantityText) ?? 0
        let fee = Double(feeText) ?? 0
        return (sellPrice - averagePrice) * Double(quantity) - fee
    }

    /// 현재 손익 값 (수동 입력 모드면 수동 값, 아니면 자동 계산 값)
    private var currentProfit: Double {
        if manualProfitMode {
            return Double(profitText) ?? 0
        }
        return calculatedProfit
    }

    private var isSellMode: Bool {
        tradeType == .sell
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
            Form {
                // 종목 선택
                Section("종목") {
                    if let stock = preselectedStock ?? selectedStock {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(stock.symbol)
                                    .font(.headline)
                                if let nickname = stock.nickname {
                                    Text(nickname)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            if preselectedStock == nil && stocks.count > 1 {
                                Button("변경") {
                                    showingStockPicker = true
                                }
                            }
                        }
                    } else {
                        Button("종목 선택") {
                            showingStockPicker = true
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
                    .onChange(of: tradeType) { _, newValue in
                        if newValue == .sell {
                            loadStockSummary()
                        }
                        manualProfitMode = false
                    }

                    Picker("주문유형", selection: $orderType) {
                        ForEach(OrderType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                // 매도 모드일 때 평균단가 표시
                if isSellMode && averagePrice > 0 {
                    Section("현재 보유 정보") {
                        HStack {
                            Text("평균단가")
                            Spacer()
                            Text(Formatters.price(averagePrice))
                                .fontWeight(.semibold)
                        }
                        HStack {
                            Text("보유수량")
                            Spacer()
                            Text("\(totalQuantity)주")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // 거래 정보
                Section("거래 정보") {
                    Button {
                        showingDatePicker = true
                    } label: {
                        HStack {
                            Text("거래일")
                                .foregroundStyle(.primary)
                            Spacer()
                            Text(Formatters.fullDate(tradeDate))
                                .foregroundStyle(.secondary)
                        }
                    }

                    HStack {
                        Text(isSellMode ? "매도단가" : "매수단가")
                        Spacer()
                        TextField("$0.00", text: $priceText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                            .focused($focusedField, equals: .price)
                            .onChange(of: priceText) { _, _ in
                                updateAutoProfit()
                            }
                    }
                    .id(Field.price)

                    HStack {
                        Text("수량")
                        Spacer()
                        TextField("0", text: $quantityText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                            .focused($focusedField, equals: .quantity)
                            .onChange(of: quantityText) { _, _ in
                                updateAutoProfit()
                            }
                    }
                    .id(Field.quantity)

                    HStack {
                        Text("수수료")
                        Spacer()
                        TextField("$0", text: $feeText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                            .focused($focusedField, equals: .fee)
                            .onChange(of: feeText) { _, _ in
                                updateAutoProfit()
                            }
                    }
                    .id(Field.fee)
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

                // 매도 모드일 때 손익 표시
                if isSellMode {
                    Section {
                        HStack {
                            Text("예상 손익")
                                .fontWeight(.semibold)
                            Spacer()
                            Button(manualProfitMode ? "자동 계산" : "직접 입력") {
                                manualProfitMode.toggle()
                                if !manualProfitMode {
                                    updateAutoProfit()
                                }
                            }
                            .font(.caption)
                        }

                        if manualProfitMode {
                            HStack {
                                Text("손익 금액")
                                Spacer()
                                TextField("$0.00", text: $profitText)
                                    .keyboardType(.numbersAndPunctuation)
                                    .multilineTextAlignment(.trailing)
                                    .frame(width: 100)
                                    .focused($focusedField, equals: .profit)
                            }
                            .id(Field.profit)
                        }

                        HStack {
                            if !manualProfitMode {
                                Text("(매도단가 - 평균단가) × 수량 - 수수료")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("입력된 손익")
                            }
                            Spacer()
                            Text(Formatters.profitCurrency(currentProfit))
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundStyle(currentProfit >= 0 ? .green : .red)
                        }
                    } header: {
                        Text("손익")
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
                    Button(isSellMode ? "매도기록 추가" : "매수기록 추가") {
                        saveTrade()
                    }
                    .fontWeight(.semibold)
                    .disabled(!isValid)
                }

                ToolbarItemGroup(placement: .keyboard) {
                    Button {
                        // 이전 필드로
                        switch focusedField {
                        case .quantity: focusedField = .price
                        case .fee: focusedField = .quantity
                        case .profit: focusedField = .fee
                        default: break
                        }
                    } label: {
                        Image(systemName: "chevron.up")
                    }
                    .disabled(focusedField == .price)

                    Button {
                        // 다음 필드로
                        switch focusedField {
                        case .price: focusedField = .quantity
                        case .quantity: focusedField = .fee
                        case .fee: if manualProfitMode { focusedField = .profit }
                        default: break
                        }
                    } label: {
                        Image(systemName: "chevron.down")
                    }
                    .disabled(focusedField == .fee && !manualProfitMode || focusedField == .profit)

                    Spacer()

                    Button("완료") {
                        focusedField = nil
                    }
                    .fontWeight(.semibold)
                }
            }
            .alert("오류", isPresented: $showingAlert) {
                Button("확인", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
            .sheet(isPresented: $showingStockPicker) {
                stockPickerSheet
            }
            .sheet(isPresented: $showingDatePicker) {
                datePickerSheet
            }
            .onChange(of: focusedField) { _, newValue in
                if let field = newValue {
                    withAnimation {
                        proxy.scrollTo(field, anchor: .center)
                    }
                }
            }
            }
        }
        .onAppear {
            if let preselected = preselectedStock {
                selectedStock = preselected
                loadStockData(for: preselected)
            } else if let first = stocks.first {
                selectedStock = first
                loadStockData(for: first)
            }
        }
    }

    private var stockPickerSheet: some View {
        NavigationStack {
            List(stocks) { stock in
                Button {
                    selectedStock = stock
                    priceText = "" // 종목 변경 시 가격 초기화
                    loadStockData(for: stock)
                    showingStockPicker = false
                } label: {
                    HStack {
                        Text(stock.displayName)
                        Spacer()
                        if selectedStock?.id == stock.id {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.blue)
                        }
                    }
                }
                .foregroundStyle(.primary)
            }
            .navigationTitle("종목 선택")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("닫기") {
                        showingStockPicker = false
                    }
                }
            }
        }
    }

    private var datePickerSheet: some View {
        NavigationStack {
            DatePicker("", selection: $tradeDate, displayedComponents: .date)
                .datePickerStyle(.graphical)
                .padding()
                .onChange(of: tradeDate) { _, _ in
                    showingDatePicker = false
                }
                .navigationTitle("거래일 선택")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("닫기") {
                            showingDatePicker = false
                        }
                    }
                }
        }
        .presentationDetents([.medium])
    }

    private func loadStockData(for stock: Stock) {
        // 전일 종가 가져오기
        let stockSymbol = stock.symbol
        let priceDescriptor = FetchDescriptor<StockPrice>(
            predicate: #Predicate { $0.symbol == stockSymbol }
        )
        if let stockPrice = try? modelContext.fetch(priceDescriptor).first {
            currentPrice = stockPrice.closePrice
            // 가격이 비어있을 때만 기본값 설정
            if priceText.isEmpty && currentPrice > 0 {
                priceText = String(format: "%.2f", currentPrice)
            }
        }

        // 평균단가 및 보유수량 계산
        loadStockSummary()
    }

    private func loadStockSummary() {
        guard let stock = preselectedStock ?? selectedStock else { return }

        // 미정산 거래만 가져오기
        let trades = stock.trades.filter { !$0.isSettlement }

        var buyAmount: Double = 0
        var sellAmount: Double = 0
        var buyQty = 0
        var sellQty = 0

        for trade in trades {
            if trade.isBuy {
                buyAmount += trade.amount
                buyQty += trade.quantity
            } else {
                sellAmount += trade.amount
                sellQty += trade.quantity
            }
        }

        totalQuantity = buyQty - sellQty
        let holdingBuyAmount = buyQty > 0 && totalQuantity > 0 ? buyAmount * (Double(totalQuantity) / Double(buyQty)) : 0
        averagePrice = totalQuantity > 0 ? holdingBuyAmount / Double(totalQuantity) : 0
    }

    private func updateAutoProfit() {
        if !manualProfitMode {
            profitText = String(format: "%.2f", calculatedProfit)
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

        // 매도 시 수익이 있으면 반복리 적용
        if isSellMode && currentProfit > 0 {
            let compoundProfit = currentProfit * (stock.compoundRate / 100)
            let additionalBuyAmount = compoundProfit / Double(stock.divisions)
            stock.currentBuyAmount += additionalBuyAmount
            stock.accumulatedProfit += currentProfit
        }

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
