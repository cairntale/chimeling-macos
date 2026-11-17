import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct FilterSettingsView: View {
    @Environment(PresenceService.self) private var service

    @State private var selection = Set<String>()
    @State private var confirmingDelete = false

    private var filter: FilterStore { service.filter }

    var body: some View {
        Group {
            if filter.isUnreadable {
                unreadable
            } else {
                Form {
                    appsSection
                    whitelistSection
                }
                .settingsTabForm()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onChange(of: filter.identifiers) { _, identifiers in
            selection = selection.intersection(identifiers)
        }
        .onDeleteCommand(perform: removeSelection)
        .confirmationDialog(
            "Remove \(selection.count) apps?",
            isPresented: $confirmingDelete,
            titleVisibility: .visible
        ) {
            Button("Remove", role: .destructive) {
                filter.remove(selection)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(
                filter.whitelist
                    ? "After you remove them, your presence will not be reported when you use these apps, the same as when you use any other app."
                    : "After you remove them, your presence will be reported when you use these apps, the same as when you use any other app."
            )
        }
    }

    private var unreadable: some View {
        ContentUnavailableView {
            Label("Filter settings couldn't be read.", systemImage: "exclamationmark.triangle")
        } description: {
            Text("Nothing is being reported until you reset. Reset reports every app again.")
        } actions: {
            Button("Reset", role: .destructive, action: filter.reset)
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .controlSize(.large)
        }
    }

    private var appsSection: some View {
        Section {
            appGrid
            HStack {
                Button("Choose App…", action: chooseApps)
                Spacer()
                Button("Remove", action: removeSelection)
                    .tint(.red)
                    .disabled(selection.isEmpty)
            }
        } header: {
            VStack(alignment: .leading) {
                Text("Exclude")
                Text(summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .textCase(nil)
            }
        }
    }

    private var whitelistSection: some View {
        Section {
            Toggle(
                "Invert the exclude list",
                isOn: Binding(get: { filter.whitelist }, set: { filter.setWhitelist($0) })
            )
        }
    }

    private var summary: String {
        filter.whitelist
            ? "The exclude list is inverted, so your presence is reported only when you use these apps."
            : "When you use these apps, your presence will not be reported."
    }

    private var appGrid: some View {
        FilterAppGrid(
            identifiers: filter.identifiers,
            selection: $selection,
            onDrop: add,
            onRemoveSelection: removeSelection
        )
    }

    private func chooseApps() {
        let panel = NSOpenPanel()
        panel.directoryURL = URL(fileURLWithPath: "/Applications", isDirectory: true)
        panel.identifier = NSUserInterfaceItemIdentifier("filter.choose-app")
        panel.allowsMultipleSelection = true
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.application]
        panel.prompt = "Choose"
        let finish: (NSApplication.ModalResponse) -> Void = { response in
            guard response == .OK else { return }
            let urls = panel.urls
            Task { @MainActor in
                add(urls)
            }
        }
        if let window = NSApp.keyWindow {
            panel.beginSheetModal(for: window, completionHandler: finish)
        } else {
            finish(panel.runModal())
        }
    }

    private func add(_ urls: [URL]) {
        filter.add(urls.compactMap { AppBundle.identifier(at: $0) })
    }

    private func removeSelection() {
        if selection.count > 1 {
            confirmingDelete = true
        } else if !selection.isEmpty {
            filter.remove(selection)
        }
    }
}

