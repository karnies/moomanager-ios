import SwiftUI
import SwiftData

struct StockAddView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let symbol: String
    let currentPrice: Double

    // 같은 심볼로 활성화된 종목이 있는지 확인
    private var hasActiveStockWithSameSymbol: Bool {
        let targetSymbol = symbol
        let descriptor = FetchDescriptor<Stock>(
            predicate: #Predicate { $0.symbol == targetSymbol && $0.isActive }
        )
        return (try? modelContext.fetchCount(descriptor)) ?? 0 > 0
    }

    @State private var nickname = ""
    @State private var version = "v3.0"
    @State private var seedMoney = ""
    @State private var divisions: Double = 20
    @State private var sellTargetPercent: Double = 15
    @State private var compoundRate: Double = 50
    @State private var startDate = Date()

    @State private var showingAlert = false
    @State private var alertMessage = ""

    private var buyAmountPerTrade: Double {
        guard let seed = Double(seedMoney), seed > 0 else { return 0 }
        return seed / divisions
    }

    var body: some View {
        NavigationStack {
            Form {
                // 종목 정보
                Section("종목 정보") {
                    HStack {
                        Text("종목")
                        Spacer()
                        Text(symbol)
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("현재가")
                        Spacer()
                        Text(Formatters.price(currentPrice))
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        TextField(hasActiveStockWithSameSymbol ? "별칭 (필수)" : "별칭 (선택)", text: $nickname)
                        if hasActiveStockWithSameSymbol && nickname.isEmpty {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundStyle(.red)
                        }
                    }
                }

                // 버전 선택
                Section("무한매수법 버전") {
                    Picker("버전", selection: $version) {
                        Text("V3.0 (20분할)").tag("v3.0")
                        Text("V2.2 (40분할)").tag("v2.2")
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: version) { _, newValue in
                        applyVersionDefaults(newValue)
                    }
                }

                // 투자 설정
                Section("투자 설정") {
                    HStack {
                        Text("시드머니")
                        Spacer()
                        TextField("$", text: $seedMoney)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 120)
                    }

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

                    DatePicker("시작일", selection: $startDate, displayedComponents: .date)
                }

                // 계산된 값
                Section("1회 매수금") {
                    HStack {
                        Text("매수금액")
                        Spacer()
                        Text(Formatters.currency(buyAmountPerTrade))
                            .fontWeight(.semibold)
                    }

                    if currentPrice > 0 && buyAmountPerTrade > 0 {
                        HStack {
                            Text("예상 수량")
                            Spacer()
                            Text("\(Int(buyAmountPerTrade / currentPrice))주")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("종목 추가")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("취소") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("저장") {
                        saveStock()
                    }
                    .fontWeight(.semibold)
                    .disabled(seedMoney.isEmpty || (hasActiveStockWithSameSymbol && nickname.isEmpty))
                }
            }
            .alert("오류", isPresented: $showingAlert) {
                Button("확인", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
        }
        .onAppear {
            applyVersionDefaults(version)
        }
    }

    private func applyVersionDefaults(_ version: String) {
        let defaults = Stock.defaultSettings(for: symbol, version: version)
        divisions = Double(defaults.divisions)
        sellTargetPercent = defaults.sellTargetPercent
        compoundRate = defaults.compoundRate
    }

    private func saveStock() {
        guard let seed = Double(seedMoney), seed > 0 else {
            alertMessage = "시드머니를 입력해주세요"
            showingAlert = true
            return
        }

        if hasActiveStockWithSameSymbol && nickname.isEmpty {
            alertMessage = "같은 티커의 활성화된 종목이 있습니다. 별칭을 입력해주세요."
            showingAlert = true
            return
        }

        let stock = Stock(
            symbol: symbol,
            nickname: nickname.isEmpty ? nil : nickname,
            version: version,
            seedMoney: seed,
            divisions: Int(divisions),
            sellTargetPercent: sellTargetPercent,
            compoundRate: compoundRate,
            startDate: startDate
        )

        modelContext.insert(stock)

        do {
            try modelContext.save()
            dismiss()
            // 부모 뷰도 닫기
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                dismiss()
            }
        } catch {
            alertMessage = "저장 실패: \(error.localizedDescription)"
            showingAlert = true
        }
    }
}

#Preview {
    StockAddView(symbol: "TQQQ", currentPrice: 50.0)
        .modelContainer(for: [Stock.self, Trade.self, Settlement.self, StockPrice.self], inMemory: true)
}
