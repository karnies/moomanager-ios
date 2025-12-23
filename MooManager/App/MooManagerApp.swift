import SwiftUI
import SwiftData

@main
struct MooManagerApp: App {
    let container: ModelContainer

    init() {
        do {
            let schema = Schema([
                Stock.self,
                Trade.self,
                Settlement.self,
                StockPrice.self,
                AppSetting.self
            ])
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(container)
    }
}
