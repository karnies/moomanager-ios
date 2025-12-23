import SwiftUI
import SwiftData

struct SettingsView: View {
    @AppStorage("isDarkMode") private var isDarkMode = false
    @AppStorage("useSystemTheme") private var useSystemTheme = true
    @AppStorage("includeFee") private var includeFee = false
    @AppStorage("hapticFeedback") private var hapticFeedback = true

    @Environment(\.modelContext) private var modelContext
    @State private var showingExportAlert = false
    @State private var showingImportPicker = false
    @State private var alertMessage = ""

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
                    Button("데이터 백업") {
                        exportData()
                    }

                    Button("데이터 복원") {
                        showingImportPicker = true
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
            .alert("알림", isPresented: $showingExportAlert) {
                Button("확인", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
            .fileImporter(
                isPresented: $showingImportPicker,
                allowedContentTypes: [.json],
                allowsMultipleSelection: false
            ) { result in
                handleImport(result)
            }
        }
    }

    private func exportData() {
        // TODO: Implement JSON export
        alertMessage = "백업 기능은 추후 지원 예정입니다"
        showingExportAlert = true
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            // TODO: Implement JSON import
            alertMessage = "복원 기능은 추후 지원 예정입니다"
            showingExportAlert = true
        case .failure(let error):
            alertMessage = "파일을 열 수 없습니다: \(error.localizedDescription)"
            showingExportAlert = true
        }
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: [Stock.self, Trade.self, Settlement.self, StockPrice.self], inMemory: true)
}
