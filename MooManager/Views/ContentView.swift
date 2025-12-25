import SwiftUI

struct ContentView: View {
    @AppStorage("isDarkMode") private var isDarkMode = false
    @AppStorage("useSystemTheme") private var useSystemTheme = true
    @State private var selectedTab = 1  // 포트폴리오 탭 (인덱스 1)

    var body: some View {
        TabView(selection: $selectedTab) {
            TodayOrdersView()
                .tabItem {
                    Label("오늘의 주문", systemImage: "list.clipboard.fill")
                }
                .tag(0)

            HomeView()
                .tabItem {
                    Label("포트폴리오", systemImage: "chart.pie.fill")
                }
                .tag(1)

            TradeHistoryView()
                .tabItem {
                    Label("매매이력", systemImage: "clock.fill")
                }
                .tag(2)

            SettlementView()
                .tabItem {
                    Label("정산", systemImage: "banknote.fill")
                }
                .tag(3)

            SettingsView()
                .tabItem {
                    Label("설정", systemImage: "gearshape.fill")
                }
                .tag(4)
        }
        .preferredColorScheme(useSystemTheme ? nil : (isDarkMode ? .dark : .light))
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Stock.self, Trade.self, Settlement.self, StockPrice.self, AppSetting.self], inMemory: true)
}
