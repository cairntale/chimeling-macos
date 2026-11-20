import ServiceManagement
import SwiftUI

struct OpenAtLoginSection: View {
    @State private var status = SMAppService.mainApp.status
    @State private var isShowingError = false
    @State private var errorMessage = ""

    var body: some View {
        Section {
            Toggle("Open at Login", isOn: Binding(
                get: { status == .enabled },
                set: { update($0) }
            ))
            if status == .requiresApproval {
                Button("Open Login Items Settings…") {
                    SMAppService.openSystemSettingsLoginItems()
                }
            }
        } header: {
            Text("Startup")
        } footer: {
            if status == .requiresApproval {
                Text("macOS is blocking this login item. Allow Chimeling in Login Items settings.")
            }
        }
        .onAppear(perform: refresh)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            refresh()
        }
        .alert("Unable to Change Open at Login", isPresented: $isShowingError) {
        } message: {
            Text(errorMessage)
        }
    }

    private func refresh() {
        status = SMAppService.mainApp.status
    }

    private func update(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            errorMessage = error.localizedDescription
            isShowingError = true
        }
        refresh()
    }
}
