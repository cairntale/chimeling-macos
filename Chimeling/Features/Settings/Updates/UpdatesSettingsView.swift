import Combine
import Sparkle
import SwiftUI

struct UpdatesSettingsView: View {
    private let updater: SPUUpdater

    @State private var automaticallyChecksForUpdates: Bool
    @State private var automaticallyDownloadsUpdates: Bool
    @State private var updateCheckInterval: TimeInterval
    @State private var lastUpdateCheckDate: Date?

    init(updater: SPUUpdater) {
        self.updater = updater
        automaticallyChecksForUpdates = updater.automaticallyChecksForUpdates
        automaticallyDownloadsUpdates = updater.automaticallyDownloadsUpdates
        updateCheckInterval = updater.updateCheckInterval
        lastUpdateCheckDate = updater.lastUpdateCheckDate
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section {
                    Toggle("Automatically check for updates", isOn: $automaticallyChecksForUpdates)
                        .onChange(of: automaticallyChecksForUpdates) { _, newValue in
                            guard newValue != updater.automaticallyChecksForUpdates else { return }
                            updater.automaticallyChecksForUpdates = newValue
                        }

                    Picker("Check for updates", selection: $updateCheckInterval) {
                        Text("Hourly").tag(TimeInterval(3600))
                        Text("Every 12 Hours").tag(TimeInterval(43_200))
                        Text("Daily").tag(TimeInterval(86_400))
                        Text("Every 3 Days").tag(TimeInterval(259_200))
                        Text("Weekly").tag(TimeInterval(604_800))
                    }
                    .pickerStyle(.menu)
                    .disabled(!automaticallyChecksForUpdates)
                    .onChange(of: updateCheckInterval) { _, newValue in
                        guard newValue != updater.updateCheckInterval else { return }
                        updater.updateCheckInterval = newValue
                    }

                    Toggle("Automatically download updates", isOn: $automaticallyDownloadsUpdates)
                        .disabled(!automaticallyChecksForUpdates)
                        .onChange(of: automaticallyDownloadsUpdates) { _, newValue in
                            guard newValue != updater.automaticallyDownloadsUpdates else { return }
                            updater.automaticallyDownloadsUpdates = newValue
                        }
                }
            }
            .formStyle(.grouped)
            .fixedSize(horizontal: false, vertical: true)

            CheckForUpdatesView(updater: updater)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .scenePadding(.horizontal)

            Spacer(minLength: 0)

            Text(lastCheckedLabel)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.bottom, 42)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onReceive(updater.publisher(for: \.automaticallyChecksForUpdates)) { automaticallyChecksForUpdates = $0 }
        .onReceive(updater.publisher(for: \.automaticallyDownloadsUpdates)) { automaticallyDownloadsUpdates = $0 }
        .onReceive(updater.publisher(for: \.updateCheckInterval)) { updateCheckInterval = $0 }
        .onReceive(updater.publisher(for: \.lastUpdateCheckDate)) { lastUpdateCheckDate = $0 }
    }

    private var lastCheckedLabel: String {
        guard let lastUpdateCheckDate else {
            return "Never checked"
        }
        let checked = lastUpdateCheckDate.formatted(date: .abbreviated, time: .shortened)
        return "Last checked \(checked)"
    }
}
