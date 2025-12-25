import SwiftUI
import SwiftData

struct StockEditView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Bindable var stock: Stock

    @State private var nickname: String
    @State private var version: String
    @State private var divisions: Double
    @State private var sellTargetPercent: Double
    @State private var compoundRate: Double
    @State private var currentBuyAmount: String
    @State private var startDate: Date

    private let versions = ["v2.2", "v3.0"]

    init(stock: Stock) {
        self.stock = stock
        _nickname = State(initialValue: stock.nickname ?? "")
        _version = State(initialValue: stock.version)
        _divisions = State(initialValue: Double(stock.divisions))
        _sellTargetPercent = State(initialValue: stock.sellTargetPercent)
        _compoundRate = State(initialValue: stock.compoundRate)
        _currentBuyAmount = State(initialValue: String(format: "%.0f", stock.currentBuyAmount))
        _startDate = State(initialValue: stock.startDate)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("기본 정보") {
                    HStack {
                        Text("종목")
                        Spacer()
                        Text(stock.symbol)
                            .foregroundStyle(.secondary)
                    }

                    TextField("별칭", text: $nickname)

                    Picker("버전", selection: $version) {
                        ForEach(versions, id: \.self) { v in
                            Text(v).tag(v)
                        }
                    }
                    .onChange(of: version) { _, newVersion in
                        applyVersionDefaults(newVersion)
                    }

                    DatePicker("시작일", selection: $startDate, displayedComponents: .date)
                }

                Section("투자 설정") {
                    VStack(alignment: .leading) {
                        HStack {
                            Text("분할수")
                            Spacer()
                            Text("\(Int(divisions))")
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: $divisions, in: 10...50, step: 1)
                    }

                    VStack(alignment: .leading) {
                        HStack {
                            Text("매도목표%")
                            Spacer()
                            Text(Formatters.percentNoSign(sellTargetPercent))
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: $sellTargetPercent, in: 5...30, step: 1)
                    }

                    if version == "v3.0" {
                        VStack(alignment: .leading) {
                            HStack {
                                Text("반복리 비율")
                                Spacer()
                                Text(Formatters.percentNoSign(compoundRate))
                                    .foregroundStyle(.secondary)
                            }
                            Slider(value: $compoundRate, in: 0...100, step: 10)
                        }
                    }

                    HStack {
                        Text("1회 매수금")
                        Spacer()
                        TextField("$", text: $currentBuyAmount)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                    }
                }

                Section {
                    Button("기본값으로 초기화") {
                        resetToDefaults()
                    }
                    .foregroundStyle(.orange)
                }
            }
            .navigationTitle("설정 수정")
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
                }
            }
        }
    }

    private func resetToDefaults() {
        applyVersionDefaults(version)
    }

    private func applyVersionDefaults(_ newVersion: String) {
        let defaults = Stock.defaultSettings(for: stock.symbol, version: newVersion)
        divisions = Double(defaults.divisions)
        sellTargetPercent = defaults.sellTargetPercent
        compoundRate = defaults.compoundRate
        currentBuyAmount = String(format: "%.0f", stock.seedMoney / Double(defaults.divisions))
    }

    private func saveChanges() {
        stock.nickname = nickname.isEmpty ? nil : nickname
        stock.version = version
        stock.divisions = Int(divisions)
        stock.sellTargetPercent = sellTargetPercent
        stock.compoundRate = compoundRate
        stock.startDate = startDate

        if let amount = Double(currentBuyAmount), amount > 0 {
            stock.currentBuyAmount = amount
        }

        try? modelContext.save()
        dismiss()
    }
}

#Preview {
    StockEditView(stock: Stock(symbol: "TQQQ", seedMoney: 10000))
        .modelContainer(for: [Stock.self, Trade.self, Settlement.self, StockPrice.self], inMemory: true)
}
