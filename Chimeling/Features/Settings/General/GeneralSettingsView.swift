import SwiftUI

struct GeneralSettingsView: View {
    var body: some View {
        Form {
            AccountSettingsSection()
        }
        .settingsTabForm()
    }
}
