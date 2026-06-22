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
        VStack(spacing: 20) {
            // Art der Hautveränderung (direkt auf Hintergrund, kein Card-Wrapper)
            VStack(alignment: .leading, spacing: 10) {
                Text("Art der Veränderung (mehrere möglich)")
                    .font(.caption).foregroundStyle(.secondary).padding(.horizontal, 4)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(artVorschlaege, id: \.self) { art in
                        let sel = ausgewaehlt.contains(art)
                        Button {
                            if sel { ausgewaehlt.remove(art) } else { ausgewaehlt.insert(art) }
                            aktualisiereBinding()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: sel ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(sel ? Color.orange : .secondary)
                                    .font(.caption)
                                Text(art).font(.caption).lineLimit(1)
                                Spacer()
                            }
                            .padding(.horizontal, 10).padding(.vertical, 8)
                            .background(
                                sel ? Color.orange.opacity(0.12) : Color(.secondarySystemGroupedBackground),
                                in: RoundedRectangle(cornerRadius: 10)
                            )
                        }
                        .buttonStyle(.plain)
                        .animation(.easeInOut(duration: 0.15), value: sel)
                    }
                }
                HStack(spacing: 8) {
                    TextField("Eigene Beschreibung…", text: $freitext)
                        .font(.subheadline)
                        .padding(14)
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
                        .submitLabel(.done)
                    if !freitext.isEmpty {
                        Button {
                            ausgewaehlt.insert(freitext.trimmingCharacters(in: .whitespaces))
                            freitext = ""
                            aktualisiereBinding()
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(Color.orange)
                                .font(.title2)
                        }
                    }
                }
            }

            // Foto (als Card, da komplexeres UI)
            VStack(alignment: .leading, spacing: 12) {
                Text("Foto (optional)")
                    .font(.caption).foregroundStyle(.secondary).padding(.horizontal, 4)

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
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
        }
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
