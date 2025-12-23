import SwiftUI

struct ContentView: View {
    @AppStorage("isDarkMode") private var isDarkMode = false
    @AppStorage("useSystemTheme") private var useSystemTheme = true

    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("포트폴리오", systemImage: "chart.pie.fill")
                }

            TodayOrdersView()
                .tabItem {
                    Label("오늘의 주문", systemImage: "list.clipboard.fill")
                }

            TradeHistoryView()
                .tabItem {
                    Label("매매이력", systemImage: "clock.fill")
                }

            SettlementView()
                .tabItem {
                    Label("정산", systemImage: "banknote.fill")
                }

            SettingsView()
                .tabItem {
                    Label("설정", systemImage: "gearshape.fill")
                }
        }
        .preferredColorScheme(useSystemTheme ? nil : (isDarkMode ? .dark : .light))
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Stock.self, Trade.self, Settlement.self, StockPrice.self, AppSetting.self], inMemory: true)
}
