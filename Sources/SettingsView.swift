import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            Tab("General", systemImage: "gear") {
                placeholder("General")
            }

            Tab("Triangle", systemImage: "triangle.fill") {
                placeholder("Triangle")
            }

            Tab("Square", systemImage: "square.fill") {
                placeholder("Square")
            }

            Tab("Pentagon", systemImage: "pentagon.fill") {
                placeholder("Pentagon")
            }

            Tab("Hexagon", systemImage: "hexagon.fill") {
                placeholder("Hexagon")
            }
        }
        .scenePadding()
        .frame(minWidth: 480, minHeight: 320)
    }

    private func placeholder(_ title: String) -> some View {
        ContentUnavailableView {
            Label("\(title) Settings", systemImage: "gearshape.2")
        } description: {
            Text("Placeholder for the \(title.lowercased()) settings.")
        }
    }
}

#Preview {
    SettingsView()
}
