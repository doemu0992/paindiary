import SwiftUI

struct ContentView: View {
    @State private var ausgewaehlterTab = 0
    @State private var neuerEintragAnzeigen = false

#if os(macOS)
    var body: some View {
        NavigationSplitView {
            PainEntryListView()
        } detail: {
            Text("Eintrag auswählen").foregroundStyle(.secondary)
        }
    }
#else
    var body: some View {
        TabView(selection: $ausgewaehlterTab) {
            NavigationStack { DashboardView() }
                .tabItem { Label("Übersicht", systemImage: "chart.line.uptrend.xyaxis") }
                .tag(0)

            NavigationStack { PainEntryListView() }
                .tabItem { Label("Tagebuch", systemImage: "book.pages") }
                .tag(1)

            Color.clear
                .tabItem { Label("Neu", systemImage: "plus.circle.fill") }
                .tag(2)

            NavigationStack { ProfilView() }
                .tabItem { Label("Profil", systemImage: "person.circle") }
                .tag(3)
        }
        .onChange(of: ausgewaehlterTab) { _, neu in
            if neu == 2 {
                neuerEintragAnzeigen = true
                ausgewaehlterTab = 1
            }
        }
        .sheet(isPresented: $neuerEintragAnzeigen) {
            AddEntryView()
        }
    }
#endif
}
