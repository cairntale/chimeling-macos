import AppKit
import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            Tab("Triangle", systemImage: "triangle") {
                Form {
                    Text("Triangle placeholder")
                }
            }
            Tab("Square", systemImage: "square") {
                Form {
                    Text("Square placeholder")
                }
            }
            Tab("Pentagon", systemImage: "pentagon") {
                Form {
                    Text("Pentagon placeholder")
                }
            }
        }
        .scenePadding()
        .frame(minWidth: 450, minHeight: 280)
        .onAppear {
            NSApp.activate()
        }
    }
}

#Preview {
    SettingsView()
}
