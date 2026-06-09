import SwiftUI

struct BodyScanSetupView: View {
    @StateObject private var scanService = BodyScanService.shared
    @Environment(\.dismiss) private var dismiss
    @State private var groesse: Double = 175

    var body: some View {
        NavigationStack {
            VStack(spacing: 28) {
                Spacer()

                Image(systemName: "figure.stand")
                    .font(.system(size: 80))
                    .foregroundStyle(.blue)

                Text("Körperproportionen")
                    .font(.title2.bold())

                Text("Gib deine Körpergrösse ein, damit das 3D-Modell besser zu dir passt.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                VStack(spacing: 12) {
                    HStack {
                        Text("Körpergrösse")
                            .font(.headline)
                        Spacer()
                        Text("\(Int(groesse)) cm")
                            .font(.headline)
                            .foregroundStyle(.blue)
                    }
                    Slider(value: $groesse, in: 140...220, step: 1)
                        .tint(.blue)
                    HStack {
                        Text("140 cm").font(.caption2).foregroundStyle(.secondary)
                        Spacer()
                        Text("220 cm").font(.caption2).foregroundStyle(.secondary)
                    }
                }
                .padding()
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)

                Spacer()

                Button {
                    scanService.scanErgebnisSpeichern(BodyProportionen.fuerGroesse(groesse))
                    dismiss()
                } label: {
                    Text("Übernehmen")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.blue, in: RoundedRectangle(cornerRadius: 14))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
            .navigationTitle(scanService.hatScan ? "Neu scannen" : "Körper scannen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
            }
            .onAppear {
                groesse = scanService.proportionen.geschaetzteGroesseCM
            }
        }
    }
}
