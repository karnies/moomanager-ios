import Foundation
import SwiftData

@Model
final class AppSetting {
    @Attribute(.unique) var key: String
    var value: String

    init(key: String, value: String) {
        self.key = key
        self.value = value
    }
}

// MARK: - Setting Keys
extension AppSetting {
    static let themeModeKey = "themeMode"
    static let fontSizeKey = "fontSize"
    static let includeFeeKey = "includeFee"
    static let hapticFeedbackKey = "hapticFeedback"
}
