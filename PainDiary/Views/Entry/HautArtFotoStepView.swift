import SwiftUI
import PhotosUI

struct HautArtFotoStepView: View {
    @Binding var hautArt: String
    @Binding var fotoDateiname: String

    @State private var ausgewaehlt: Set<String> = []
    @State private var freitext = ""
    @State private var photoItem: PhotosPickerItem? = nil
    @State private var geladensBild: UIImage? = nil

    private let artVorschlaege = [
        "Ausschlag", "Schuppenflechte", "Ekzem", "Rötung", "Schwellung",
        "Hämatom", "Wunde", "Juckreiz", "Trockene Haut", "Verbrennung", "Bläschen"
    ]

    var body: some View {
        VStack(spacing: 24) {
            // Step header
            VStack(spacing: 6) {
                Image(systemName: "bandage")
                    .font(.system(size: 32))
                    .foregroundStyle(.orange)
                Text("Was zeigt sich?")
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)
            }

            // Card 1: Art der Hautveränderung
            VStack(alignment: .leading, spacing: 12) {
                Text("Art der Veränderung (mehrere möglich)")
                    .font(.headline)
                FlowLayout(artVorschlaege) { art in
                    ChipButton(label: art, ausgewaehlt: ausgewaehlt.contains(art)) {
                        if ausgewaehlt.contains(art) { ausgewaehlt.remove(art) }
                        else { ausgewaehlt.insert(art) }
                        aktualisiereBinding()
                    }
                }
                HStack(spacing: 8) {
                    TextField("Eigene Beschreibung…", text: $freitext)
                        .textFieldStyle(.roundedBorder)
                    if !freitext.isEmpty {
                        Button {
                            ausgewaehlt.insert(freitext.trimmingCharacters(in: .whitespaces))
                            freitext = ""
                            aktualisiereBinding()
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(Color.accentColor)
                                .font(.title2)
                        }
                    }
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))

            // Card 2: Foto
            VStack(alignment: .leading, spacing: 12) {
                Text("Foto (optional)")
                    .font(.headline)

                if let bild = geladensBild {
                    ZStack(alignment: .topTrailing) {
                        Image(uiImage: bild)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 220)
                            .clipShape(RoundedRectangle(cornerRadius: 12))

                        Button {
                            FotoManager.loeschen(dateiname: fotoDateiname)
                            fotoDateiname = ""
                            geladensBild = nil
                            photoItem = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.white)
                                .background(Color.black.opacity(0.5), in: Circle())
                        }
                        .buttonStyle(.plain)
                        .padding(8)
                    }
                } else {
                    PhotosPicker(selection: $photoItem, matching: .images) {
                        HStack(spacing: 8) {
                            Image(systemName: "camera.fill")
                            Text("Foto hinzufügen")
                        }
                        .font(.subheadline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                        .foregroundStyle(.orange)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
        }
        .padding(.horizontal)
        .onAppear {
            ladeWerte()
            if let bild = FotoManager.laden(dateiname: fotoDateiname) {
                geladensBild = bild
            }
        }
        .onChange(of: photoItem) { _, newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self),
                   let bild = UIImage(data: data) {
                    // Delete old foto if exists
                    if !fotoDateiname.isEmpty {
                        FotoManager.loeschen(dateiname: fotoDateiname)
                    }
                    fotoDateiname = FotoManager.speichern(bild)
                    geladensBild = bild
                }
            }
        }
    }

    private func aktualisiereBinding() {
        hautArt = ausgewaehlt.sorted().joined(separator: ", ")
    }

    private func ladeWerte() {
        let teile = hautArt.components(separatedBy: ", ").map { $0.trimmingCharacters(in: .whitespaces) }
        ausgewaehlt = Set(teile.filter { !$0.isEmpty })
    }
}
