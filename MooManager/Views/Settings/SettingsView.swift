import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct SettingsView: View {
    @AppStorage("isDarkMode") private var isDarkMode = false
    @AppStorage("useSystemTheme") private var useSystemTheme = true
    @AppStorage("includeFee") private var includeFee = false
    @AppStorage("hapticFeedback") private var hapticFeedback = true

    @Environment(\.modelContext) private var modelContext
    @State private var showingAlert = false
    @State private var showingImportPicker = false
    @State private var showingExportSheet = false
    @State private var showingResetConfirm = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var isLoading = false
    @State private var exportData: Data?

    var body: some View {
        NavigationStack {
            List {
                // 테마 설정
                Section("테마") {
                    Toggle("시스템 설정 사용", isOn: $useSystemTheme)

                    if !useSystemTheme {
                        Toggle("다크 모드", isOn: $isDarkMode)
                    }
                }

                // 표시 설정
                Section("표시") {
                    Toggle("수수료 포함", isOn: $includeFee)
                    Toggle("햅틱 피드백", isOn: $hapticFeedback)
                }

                // 데이터 관리
                Section("데이터") {
                    Button {
                        Task {
                            await exportJSON()
                        }
                    } label: {
                        HStack {
                            Text("데이터 백업")
                            if isLoading {
                                Spacer()
                                ProgressView()
                            }
                        }
                    }
                    .disabled(isLoading)

                    Button("데이터 복원") {
                        showingImportPicker = true
                    }
                    .disabled(isLoading)

                    Button("데이터 초기화", role: .destructive) {
                        showingResetConfirm = true
                    }
                    .disabled(isLoading)
                }

                // 휴장일 데이터 경고
                if !USMarketHolidays.hasHolidaysForNextYear() {
                    Section {
                        HStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("휴장일 데이터 업데이트 필요")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Text("다음 연도 미국 휴장일 정보가 없습니다. 앱 업데이트가 필요합니다.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                // 앱 정보
                Section("정보") {
                    HStack {
                        Text("버전")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")
                            .foregroundStyle(.secondary)
                    }

                    Link("개발자 GitHub", destination: URL(string: "https://github.com/karnies")!)

                    Link("문의하기", destination: URL(string: "mailto:karnies@me.com")!)
                }

                // 지원 종목
                Section("지원 종목") {
                    Text(InfiniteBuyingCalculations.supportedSymbols.joined(separator: ", "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("설정")
            .alert(alertTitle, isPresented: $showingAlert) {
                Button("확인", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
            .alert("데이터 초기화", isPresented: $showingResetConfirm) {
                Button("취소", role: .cancel) { }
                Button("초기화", role: .destructive) {
                    resetAllData()
                }
            } message: {
                Text("모든 종목, 매매이력, 정산이력이 삭제됩니다.\n이 작업은 되돌릴 수 없습니다.")
            }
            .fileImporter(
                isPresented: $showingImportPicker,
                allowedContentTypes: [.json],
                allowsMultipleSelection: false
            ) { result in
                Task {
                    await handleImport(result)
                }
            }
            .fileExporter(
                isPresented: $showingExportSheet,
                document: JSONDocument(data: exportData ?? Data()),
                contentType: .json,
                defaultFilename: "moomanager_backup_\(dateString()).json"
            ) { result in
                switch result {
                case .success(let url):
                    alertTitle = "백업 완료"
                    alertMessage = "백업 파일이 저장되었습니다"
                    showingAlert = true
                case .failure(let error):
                    alertTitle = "백업 실패"
                    alertMessage = error.localizedDescription
                    showingAlert = true
                }
            }
        }
    }

    private func exportJSON() async {
        isLoading = true

        do {
            let backupService = BackupService(modelContext: modelContext)
            let data = try await backupService.exportToJSON()
            exportData = data
            showingExportSheet = true
        } catch {
            alertTitle = "백업 실패"
            alertMessage = error.localizedDescription
            showingAlert = true
        }

        isLoading = false
    }

    private func handleImport(_ result: Result<[URL], Error>) async {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }

            isLoading = true

            // 파일 접근 권한 획득
            guard url.startAccessingSecurityScopedResource() else {
                alertTitle = "오류"
                alertMessage = "파일에 접근할 수 없습니다"
                showingAlert = true
                isLoading = false
                return
            }

            defer {
                url.stopAccessingSecurityScopedResource()
            }

            do {
                let backupService = BackupService(modelContext: modelContext)
                let result = try await backupService.importFromJSON(url: url)

                alertTitle = "복원 완료"
                alertMessage = "종목 \(result.stocks)개, 매매 \(result.trades)건, 정산 \(result.settlements)건이 복원되었습니다"
                showingAlert = true
            } catch {
                alertTitle = "복원 실패"
                alertMessage = error.localizedDescription
                showingAlert = true
            }

            isLoading = false

        case .failure(let error):
            alertTitle = "오류"
            alertMessage = "파일을 열 수 없습니다: \(error.localizedDescription)"
            showingAlert = true
        }
    }

    private func dateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return formatter.string(from: Date())
    }

    private func resetAllData() {
        do {
            // 관계가 있는 모델은 개별 삭제해야 함
            // 1. 모든 Trade 개별 삭제
            let trades = try modelContext.fetch(FetchDescriptor<Trade>())
            for trade in trades {
                modelContext.delete(trade)
            }

            // 2. 모든 Settlement 개별 삭제
            let settlements = try modelContext.fetch(FetchDescriptor<Settlement>())
            for settlement in settlements {
                modelContext.delete(settlement)
            }

            // 3. 모든 StockPrice 삭제
            let prices = try modelContext.fetch(FetchDescriptor<StockPrice>())
            for price in prices {
                modelContext.delete(price)
            }

            // 4. 모든 Stock 삭제
            let stocks = try modelContext.fetch(FetchDescriptor<Stock>())
            for stock in stocks {
                modelContext.delete(stock)
            }

            try modelContext.save()

            alertTitle = "초기화 완료"
            alertMessage = "모든 데이터가 삭제되었습니다"
            showingAlert = true
        } catch {
            alertTitle = "초기화 실패"
            alertMessage = error.localizedDescription
            showingAlert = true
        }
    }
}

// MARK: - JSON Document for Export

struct JSONDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: [Stock.self, Trade.self, Settlement.self, StockPrice.self], inMemory: true)
}
