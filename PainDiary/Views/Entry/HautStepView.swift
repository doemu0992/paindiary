import SwiftUI
import PhotosUI

struct HautStepView: View {
    @Binding var hautStellen: String
    @Binding var hautArt: String
    @Binding var fotoDateiname: String

    private let artVorschlaege = [
        "Ausschlag", "Schuppenflechte", "Ekzem", "Rötung", "Schwellung",
        "Hämatom", "Wunde", "Juckreiz", "Trockene Haut", "Verbrennung", "Bläschen"
    ]

    @State private var artAusgewaehlt: Set<String> = []
    @State private var eigenerText = ""
    @State private var photoItem: PhotosPickerItem? = nil
    @State private var fotoBild: UIImage? = nil

    var body: some View {
        VStack(spacing: 24) {
            Text("Hautveränderungen?")
                .font(.title2.bold())
                .multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: 10) {
                Text("Betroffene Stellen")
                    .font(.headline)
                KoerperPickerView(auswahl: $hautStellen, tintColor: .orange, frameHeight: 300)
            }
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))

            VStack(alignment: .leading, spacing: 12) {
                Text("Art der Veränderung")
                    .font(.headline)
                FlowLayout(artVorschlaege) { art in
                    ChipButton(label: art, ausgewaehlt: artAusgewaehlt.contains(art)) {
                        if artAusgewaehlt.contains(art) { artAusgewaehlt.remove(art) }
                        else { artAusgewaehlt.insert(art) }
                        hautArt = artAusgewaehlt.sorted().joined(separator: ", ")
                    }
                }
                HStack(spacing: 8) {
                    TextField("Weitere Art…", text: $eigenerText)
                        .textFieldStyle(.roundedBorder)
                    if !eigenerText.isEmpty {
                        Button {
                            let t = eigenerText.trimmingCharacters(in: .whitespaces)
                            artAusgewaehlt.insert(t); eigenerText = ""
                            hautArt = artAusgewaehlt.sorted().joined(separator: ", ")
                        } label: {
                            Image(systemName: "plus.circle.fill").foregroundStyle(Color.accentColor)
                        }
                    }
                }
            }
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))

            VStack(alignment: .leading, spacing: 12) {
                Text("Foto-Anhang")
                    .font(.headline)
                if let bild = fotoBild {
                    ZStack(alignment: .topTrailing) {
                        Image(uiImage: bild)
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity)
                            .frame(height: 180)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        Button {
                            FotoManager.loeschen(dateiname: fotoDateiname)
                            fotoDateiname = ""; fotoBild = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.white)
                                .shadow(radius: 2)
                        }
                        .padding(8)
                    }
                } else {
                    PhotosPicker(selection: $photoItem, matching: .images) {
                        Label("Foto hinzufügen", systemImage: "camera.fill")
                            .font(.subheadline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                            .foregroundStyle(.primary)
                    }
                }
            }
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))

            Text("Optional – du kannst diesen Schritt überspringen.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal)
        .onAppear {
            artAusgewaehlt = Set(hautArt.components(separatedBy: ", ").filter { !$0.isEmpty })
            fotoBild = FotoManager.laden(dateiname: fotoDateiname)
        }
        .onChange(of: photoItem) {
            Task {
                guard let data = try? await photoItem?.loadTransferable(type: Data.self),
                      let bild = UIImage(data: data) else { return }
                let alteDateiname = fotoDateiname
                fotoDateiname = FotoManager.speichern(bild)
                FotoManager.loeschen(dateiname: alteDateiname)
                fotoBild = bild
            }
        }
    }
}
