import SwiftUI

struct WizardAnatomieKarteView: View {
    @Binding var koerperstelle: String
    @StateObject private var scanService = BodyScanService.shared
    @State private var scanSetupAnzeigen = false

    private var ausgewaehlt: Set<String> {
        Set(koerperstelle.components(separatedBy: ", ").filter { !$0.isEmpty })
    }

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                Text("Wo hast du Schmerzen?")
                    .font(.title2.bold())
                Spacer()
                Button { scanSetupAnzeigen = true } label: {
                    Label(scanService.hatScan ? "Neu scannen" : "Körper scannen",
                          systemImage: scanService.hatScan ? "arrow.triangle.2.circlepath" : "camera.viewfinder")
                        .font(.caption)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Color.accentColor.opacity(0.12))
                        .foregroundStyle(Color.accentColor)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            KoerperPickerView(auswahl: $koerperstelle)

            if ausgewaehlt.isEmpty {
                Text("Tippe auf eine Körperstelle")
                    .font(.subheadline).foregroundStyle(.secondary)
                    .frame(height: 30)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(ausgewaehlt.sorted(), id: \.self) { r in
                            Button {
                                var s = ausgewaehlt; s.remove(r)
                                koerperstelle = s.sorted().joined(separator: ", ")
                            } label: {
                                HStack(spacing: 3) {
                                    Image(systemName: "xmark").font(.system(size: 9, weight: .bold))
                                    Text(r).font(.caption)
                                }
                                .padding(.horizontal, 10).padding(.vertical, 5)
                                .background(Color.red.opacity(0.12))
                                .foregroundStyle(.red)
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }
                .frame(height: 30)
            }

            Label("Drehen zum Erkunden", systemImage: "hand.draw")
                .font(.caption2).foregroundStyle(.tertiary)
        }
        .sheet(isPresented: $scanSetupAnzeigen) { BodyScanSetupView() }
    }
}
