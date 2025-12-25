import SwiftUI
import SwiftData

struct TradeEditView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Bindable var trade: Trade

    @State private var tradeType: TradeType
    @State private var orderType: OrderType
    @State private var tradeDate: Date
    @State private var priceText: String
    @State private var quantityText: String
    @State private var feeText: String

    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var showingDatePicker = false
    @FocusState private var focusedField: Field?

    enum Field: Hashable {
        case price, quantity, fee
    }

    init(trade: Trade) {
        self.trade = trade
        _tradeType = State(initialValue: trade.tradeTypeEnum)
        _orderType = State(initialValue: trade.orderTypeEnum)
        _tradeDate = State(initialValue: trade.tradeDate)
        _priceText = State(initialValue: String(format: "%.2f", trade.price))
        _quantityText = State(initialValue: String(trade.quantity))
        _feeText = State(initialValue: String(format: "%.2f", trade.fee))
    }

    private var amount: Double {
        let price = Double(priceText) ?? 0
        let quantity = Int(quantityText) ?? 0
        return price * Double(quantity)
    }

    private var isSellMode: Bool {
        tradeType == .sell
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
            Form {
                // 종목 정보 (읽기 전용)
                Section("종목") {
                    HStack {
                        Text(trade.stock?.symbol ?? "Unknown")
                            .font(.headline)
                        if let nickname = trade.stock?.nickname {
                            Text(nickname)
                                .font(.caption)
                                .foregroundStyle(.secondary)
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
            }
            .navigationTitle("매매 수정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("취소") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("저장") {
                        saveChanges()
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
                        default: break
                        }
                    } label: {
                        Image(systemName: "chevron.down")
                    }
                    .disabled(focusedField == .fee)

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

    private var isValid: Bool {
        guard let price = Double(priceText), price > 0 else { return false }
        guard let quantity = Int(quantityText), quantity > 0 else { return false }
        return true
    }

    private func saveChanges() {
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

        // 거래 정보 업데이트
        trade.tradeType = tradeType.rawValue
        trade.orderType = orderType.rawValue
        trade.tradeDate = Calendar.current.startOfDay(for: tradeDate)
        trade.price = price
        trade.quantity = quantity
        trade.fee = fee
        trade.amount = price * Double(quantity)

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
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Stock.self, Trade.self, configurations: config)
    let stock = Stock(symbol: "TQQQ", seedMoney: 10000)
    container.mainContext.insert(stock)
    let trade = Trade(stock: stock, tradeType: .buy, orderType: .loc, price: 50.0, quantity: 10, fee: 1.0)
    container.mainContext.insert(trade)

    return TradeEditView(trade: trade)
        .modelContainer(container)
}
