import SwiftUI

struct OnboardingView: View {
    @AppStorage("onboardingAbgeschlossen") private var onboardingAbgeschlossen = false
    @State private var seite = 0

    private let seiten: [OnboardingSeite] = [
        OnboardingSeite(
            symbol: "waveform.path.ecg.rectangle.fill",
            farbe: .red,
            titel: "Willkommen bei PainDiary",
            beschreibung: "Dein persönliches Schmerztagebuch. Erfasse, verstehe und teile deine Schmerzmuster — einfach und schnell."
        ),
        OnboardingSeite(
            symbol: "figure.walk.motion",
            farbe: .orange,
            titel: "Schmerz erfassen in Sekunden",
            beschreibung: "Der geführte Wizard fragt dich Schritt für Schritt nach Körperstelle, Intensität, Auslösern und Massnahmen. Wetter und Schlaf werden automatisch übernommen."
        ),
        OnboardingSeite(
            symbol: "chart.line.uptrend.xyaxis",
            farbe: .blue,
            titel: "Muster erkennen",
            beschreibung: "Das Dashboard zeigt dir deinen Schmerzverlauf, Durchschnittswerte und die häufigsten Auslöser — auf einen Blick."
        ),
        OnboardingSeite(
            symbol: "cross.case.fill",
            farbe: .green,
            titel: "Alles an einem Ort",
            beschreibung: "Medikamente, Diagnosen, Ärzte, Notfallkontakte und der MIDAS-Fragebogen für deinen Arzttermin — alles sicher in iCloud gespeichert."
        )
    ]

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $seite) {
                ForEach(seiten.indices, id: \.self) { i in
                    OnboardingSeiteView(seite: seiten[i])
                        .tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            VStack(spacing: 12) {
                if seite < seiten.count - 1 {
                    Button {
                        withAnimation { seite += 1 }
                    } label: {
                        Text("Weiter")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(seiten[seite].farbe)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    Button("Überspringen") {
                        onboardingAbgeschlossen = true
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                } else {
                    Button {
                        onboardingAbgeschlossen = true
                    } label: {
                        Text("Los geht's!")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(seiten[seite].farbe)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
            .padding(.top, 16)
        }
        .background(Color(.systemGroupedBackground))
    }
}

private struct OnboardingSeite {
    let symbol: String
    let farbe: Color
    let titel: String
    let beschreibung: String
}

private struct OnboardingSeiteView: View {
    let seite: OnboardingSeite

    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            ZStack {
                Circle()
                    .fill(seite.farbe.opacity(0.15))
                    .frame(width: 140, height: 140)
                Image(systemName: seite.symbol)
                    .font(.system(size: 60))
                    .foregroundStyle(seite.farbe)
            }
            VStack(spacing: 16) {
                Text(seite.titel)
                    .font(.title.bold())
                    .multilineTextAlignment(.center)
                Text(seite.beschreibung)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }
            Spacer()
            Spacer()
        }
        .padding(.horizontal, 24)
    }
}
