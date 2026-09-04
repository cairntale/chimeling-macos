import AppKit
import SwiftUI

struct AboutVersionLabel: View {
    let identity: AboutIdentity
    @State private var didCopy = false
    @State private var copyResetTask: Task<Void, Never>?

    var body: some View {
        Button(action: copyVersion) {
            ZStack {
                Text(identity.versionLine)
                    .hidden()
                Text(didCopy ? "Copied" : identity.versionLine)
            }
            .font(.callout)
            .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .help("Copy Version")
        .contextMenu {
            Button("Copy Version", action: copyVersion)
        }
        .accessibilityLabel(identity.versionLine)
        .accessibilityHint("Copies the version to the clipboard")
        .accessibilityInputLabels(["Copy Version"])
        .onDisappear {
            copyResetTask?.cancel()
        }
    }

    private func copyVersion() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(identity.pasteboardString, forType: .string)
        didCopy = true
        copyResetTask?.cancel()
        copyResetTask = Task {
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled else { return }
            didCopy = false
        }
    }
}
