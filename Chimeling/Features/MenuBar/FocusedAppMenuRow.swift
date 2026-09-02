import AppKit
import SwiftUI

struct FocusedAppMenuRow: View {
    @Bindable var service: PresenceService
    @State private var openedAt = Date.now

    var body: some View {
        Group {
            if let activity = service.livePresence.current.activity {
                Section(RelativeSince.string(for: activity.startedAt, relativeTo: openedAt)) {
                    if let icon = menuIcon(service.icons.nsImage(for: activity.identifier)) {
                        Button(action: noop) {
                            Label {
                                Text(activity.name)
                            } icon: {
                                Image(nsImage: icon)
                            }
                        }
                    } else {
                        Button(activity.name, action: noop)
                    }
                }
            } else {
                Button("No app", action: noop)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSMenu.didBeginTrackingNotification)) { _ in
            captureOpen()
        }
    }

    private func captureOpen() {
        openedAt = .now
    }

    private func noop() {}

    private func menuIcon(_ image: NSImage?) -> NSImage? {
        guard let image else { return nil }
        let icon = image.copy() as? NSImage ?? image
        icon.size = NSSize(width: 16, height: 16)
        return icon
    }
}
