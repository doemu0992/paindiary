import SwiftUI
import Combine
import ARKit

struct BodyScanSetupView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var service = BodyScanService.shared

    @State private var schritt: Schritt = .intro
    @State private var phase: BodyScanPhase = .suchend
    @State private var erkennungsZeit: Date? = nil
    @State private var sekunden: Int = 0
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    enum Schritt { case intro, vorne, hinten, fertig }

    var body: some View {
        NavigationStack {
            Group {
                switch schritt {
                case .intro:   introView
                case .vorne:   scanView(vorne: true)
                case .hinten:  scanView(vorne: false)
                case .fertig:  fertigView
                }
            }
            .navigationTitle("Körper einrichten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Schließen") { dismiss() }
                }
            }
        }
    }

    // MARK: - Intro

    private var introView: some View {
        ScrollView {
            VStack(spacing: 28) {
                Image(systemName: "figure.stand")
                    .font(.system(size: 72))
                    .foregroundStyle(.blue)
                    .padding(.top, 20)

                VStack(spacing: 8) {
                    Text("Einmalige Einrichtung")
                        .font(.title2.bold())
                    Text("Deine persönliche Körpersilhouette wird einmal gescannt und dauerhaft im Körper-Picker verwendet.")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                }

                VStack(alignment: .leading, spacing: 14) {
                    hinweis("iPhone auf Tisch/Regal abstellen", icon: "iphone")
                    hinweis("Ca. 2 Meter zurücktreten", icon: "arrow.left.and.right")
                    hinweis("Ganzer Körper muss sichtbar sein", icon: "figure.stand")
                    hinweis("Helle Umgebung empfohlen", icon: "sun.max")
                    hinweis("Enganliegende Kleidung für beste Erkennung", icon: "tshirt")
                }
                .padding(16)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))

                if !service.arUnterstuetzt {
                    Label("ARKit Body Tracking wird von diesem Gerät nicht unterstützt.", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: 12) {
                    Button {
                        phase = .suchend
                        schritt = .vorne
                    } label: {
                        Label("Scan starten", systemImage: "camera.fill")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!service.arUnterstuetzt)

                    if service.hatScan {
                        Button("Bestehenden Scan löschen", role: .destructive) {
                            service.loeschen()
                        }
                        .font(.caption)
                    }
                }
            }
            .padding()
        }
    }

    // MARK: - Scan

    @ViewBuilder
    private func scanView(vorne: Bool) -> some View {
        ZStack {
            ARScanCameraView(phase: $phase) { silhouette, proportionen in
                service.speichern(bild: silhouette, vorne: vorne)
                if let p = proportionen {
                    service.speichernProportionen(p)
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    phase = .suchend
                    schritt = vorne ? .hinten : .fertig
                }
            }
            .ignoresSafeArea()

            VStack {
                // Top indicator
                HStack {
                    Image(systemName: vorne ? "figure.stand" : "figure.stand.dress")
                    Text(vorne ? "Vorderseite" : "Rückseite")
                        .font(.headline)
                }
                .foregroundStyle(.white)
                .padding(10)
                .background(.black.opacity(0.5), in: Capsule())
                .padding(.top, 16)

                Spacer()

                // Bottom status
                VStack(spacing: 10) {
                    statusChip

                    if !vorne {
                        Button("Überspringen") {
                            phase = .suchend
                            schritt = .fertig
                        }
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.75))
                    }
                }
                .padding(.bottom, 40)
            }
        }
        .onReceive(timer) { _ in
            if phase == .erkannt {
                sekunden = min(sekunden + 1, 2)
            } else {
                sekunden = 0
            }
        }
    }

    @ViewBuilder
    private var statusChip: some View {
        switch phase {
        case .suchend:
            pill("Stell dich frontal vor die Kamera", icon: "viewfinder", color: .white)
        case .erkannt:
            pill("Erkannt – halte still… (\(2 - sekunden)s)", icon: "checkmark.circle.fill", color: .green)
        case .verarbeiten:
            pill("Silhouette wird erstellt…", icon: "gearshape.fill", color: .blue)
        }
    }

    // MARK: - Fertig

    private var fertigView: some View {
        VStack(spacing: 28) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 72))
                .foregroundStyle(.green)

            VStack(spacing: 8) {
                Text("Einrichtung abgeschlossen!")
                    .font(.title2.bold())
                Text("Deine Silhouette wird ab jetzt im Körper-Picker verwendet.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
            }

            HStack(spacing: 20) {
                scanVorschau(bild: service.vorneBild, label: "Vorne")
                scanVorschau(bild: service.hintenBild, label: "Hinten")
            }

            Spacer()

            Button("Fertig") { dismiss() }
                .buttonStyle(.borderedProminent)
                .padding(.bottom)
        }
        .padding()
    }

    // MARK: - Helpers

    private func hinweis(_ text: String, icon: String) -> some View {
        Label(text, systemImage: icon)
            .font(.subheadline)
    }

    private func pill(_ text: String, icon: String, color: Color) -> some View {
        Label(text, systemImage: icon)
            .font(.subheadline.bold())
            .foregroundStyle(color)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(.black.opacity(0.55), in: Capsule())
    }

    @ViewBuilder
    private func scanVorschau(bild: UIImage?, label: String) -> some View {
        if let bild {
            VStack(spacing: 6) {
                Image(uiImage: bild)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 130)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
