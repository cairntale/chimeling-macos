import SwiftUI

struct SettingsTabForm: ViewModifier {
    func body(content: Content) -> some View {
        content
            .formStyle(.grouped)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

extension View {
    func settingsTabForm() -> some View {
        modifier(SettingsTabForm())
    }
}
