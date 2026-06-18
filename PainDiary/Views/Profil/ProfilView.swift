import SwiftUI
import SwiftData
#if os(iOS)
import PhotosUI
#endif

struct ProfilView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profile: [Benutzerprofil]

    var body: some View {
        Group {
            if let profil = profile.first {
                ProfilInhaltView(profil: profil)
            } else {
                ProgressView("Lade Profil…")
                    .navigationTitle("Profil")
                    .navigationBarTitleDisplayMode(.large)
            }
        }
        .onAppear {
            if profile.isEmpty {
                modelContext.insert(Benutzerprofil())
            }
        }
    }
}

// MARK: - Content

private struct ProfilInhaltView: View {
    let profil: Benutzerprofil
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Diagnose.bezeichnung) private var alleDiagnosen: [Diagnose]
    @Query(sort: \Allergie.schwere) private var alleAllergien: [Allergie]
    @Query(sort: \Arztbesuch.datum, order: .reverse) private var alleArztbesuche: [Arztbesuch]
    @Query(sort: \Laborwert.datum, order: .reverse) private var alleLaborwerte: [Laborwert]
    @AppStorage("migraeneModulAktiv") private var migraeneModulAktiv = false
    @AppStorage("rheumaModulAktiv") private var rheumaModulAktiv = false
    @AppStorage("diabetesModulAktiv") private var diabetesModulAktiv = false
    @AppStorage("hautModulAktiv") private var hautAktiv = false
    @State private var stammdatenAnzeigen = false

    var body: some View {
        List {
            heroHeader
            gesundheitSektion
            erkrankungenSektion
            moduleSektion
            notfallSektion
            einstellungen
        }
        .navigationTitle("Profil")
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $stammdatenAnzeigen) {
            StammdatenSheet(profil: profil)
        }
        .onAppear {
            if profil.geschlecht == "Nicht angegeben" { profil.geschlecht = "" }
            if profil.blutgruppe == "Unbekannt" { profil.blutgruppe = "" }
        }
    }

    // MARK: - Hero Header

    private var heroHeader: some View {
        Section {
            Button { stammdatenAnzeigen = true } label: {
                HStack(spacing: 14) {
                    profilBildKlein
                    VStack(alignment: .leading, spacing: 5) {
                        let name = "\(profil.vorname) \(profil.nachname)".trimmingCharacters(in: .whitespaces)
                        Text(name.isEmpty ? "Profil einrichten" : name)
                            .font(.title3.bold())
                            .foregroundStyle(.primary)
                        HStack(spacing: 6) {
                            if let geb = profil.geburtsdatum {
                                let alter = Calendar.current.dateComponents([.year], from: geb, to: Date()).year ?? 0
                                infoBadge("\(alter) J.", symbol: "person.fill", farbe: .blue)
                            }
                            if !profil.blutgruppe.isEmpty {
                                infoBadge(profil.blutgruppe, symbol: "drop.fill", farbe: .red)
                            }
                            if let bmi = profil.bmi {
                                infoBadge(String(format: "BMI %.1f", bmi), symbol: nil, farbe: bmiTint(bmi))
                            }
                        }
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.bold())
                        .foregroundStyle(.tertiary)
                }
                .padding(.vertical, 10)
            }
            .buttonStyle(.plain)

            NavigationLink(destination: NotfallausweisView()) {
                notfallKurzInfo
            }
        }
    }

    private var notfallKurzInfo: some View {
        HStack(spacing: 12) {
            Image(systemName: "staroflife.fill")
                .font(.callout)
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(Color.red)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                Text("Notfallausweis")
                    .font(.subheadline.bold())

                let aktDiag = alleDiagnosen.filter { $0.aktiv }
                if alleAllergien.isEmpty && aktDiag.isEmpty {
                    Text("Tippe um medizinische Daten zu hinterlegen")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    HStack(spacing: 6) {
                        if !alleAllergien.isEmpty {
                            Label(
                                alleAllergien.count == 1
                                    ? alleAllergien[0].substanz
                                    : "\(alleAllergien.count) Allergien",
                                systemImage: "exclamationmark.triangle.fill"
                            )
                            .font(.caption2.bold())
                            .foregroundStyle(.orange)
                            .lineLimit(1)
                            .padding(.horizontal, 7).padding(.vertical, 3)
                            .background(Color.orange.opacity(0.12), in: Capsule())
                        }
                        if !aktDiag.isEmpty {
                            Text(
                                aktDiag.count == 1
                                    ? aktDiag[0].bezeichnung
                                    : "\(aktDiag.count) Diagnosen"
                            )
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .padding(.horizontal, 7).padding(.vertical, 3)
                            .background(Color.secondary.opacity(0.1), in: Capsule())
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var profilBildKlein: some View {
#if os(iOS)
        if let data = profil.fotoData, let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable().scaledToFill()
                .frame(width: 72, height: 72)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.secondary.opacity(0.3), lineWidth: 1))
        } else {
            ZStack {
                Circle().fill(Color.secondary.opacity(0.15)).frame(width: 72, height: 72)
                Image(systemName: "person.fill").font(.system(size: 34)).foregroundStyle(.secondary)
                Circle().fill(Color.accentColor).frame(width: 24, height: 24)
                    .overlay(Image(systemName: "pencil").font(.system(size: 11)).foregroundStyle(.white))
                    .offset(x: 24, y: 24)
            }
        }
#else
        Image(systemName: "person.circle.fill")
            .font(.system(size: 72))
            .foregroundStyle(.secondary)
#endif
    }

    private func infoBadge(_ text: String, symbol: String?, farbe: Color) -> some View {
        HStack(spacing: 4) {
            if let sym = symbol {
                Image(systemName: sym).font(.caption2.bold())
            }
            Text(text).font(.caption.bold())
        }
        .foregroundStyle(farbe)
        .padding(.horizontal, 10).padding(.vertical, 4)
        .background(farbe.opacity(0.12), in: Capsule())
    }

    private func bmiTint(_ bmi: Double) -> Color {
        switch bmi {
        case ..<18.5: return .blue
        case 18.5..<25: return .green
        case 25..<30: return .orange
        default: return .red
        }
    }

    // MARK: - Gesundheit

    private var gesundheitSektion: some View {
        Section("Gesundheit") {
            NavigationLink(destination: DiagnoseView()) {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Diagnosen")
                        let aktive = alleDiagnosen.filter { $0.aktiv }
                        if !aktive.isEmpty {
                            Text(aktive.map(\.bezeichnung).prefix(2).joined(separator: ", "))
                                .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        }
                    }
                } icon: {
                    Image(systemName: "cross.case.fill").foregroundStyle(.red)
                }
            }
            NavigationLink(destination: AllergienView()) {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Allergien & Unverträglichkeiten")
                        if !alleAllergien.isEmpty {
                            Text(alleAllergien.map(\.substanz).prefix(2).joined(separator: ", "))
                                .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        }
                    }
                } icon: {
                    Image(systemName: "allergens").foregroundStyle(.orange)
                }
            }
            NavigationLink(destination: MedikamenteView()) {
                Label("Medikamente", systemImage: "pill.fill")
            }
            NavigationLink(destination: ImpfpassView()) {
                Label("Impfpass", systemImage: "syringe.fill")
            }
            NavigationLink(destination: ArztbesuchView()) {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Arztbesuche")
                        if let naechster = alleArztbesuche.compactMap(\.naechsterTermin).filter({ $0 > Date() }).min() {
                            Text("Nächster: \(naechster.formatted(date: .abbreviated, time: .omitted))")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                } icon: {
                    Image(systemName: "stethoscope").foregroundStyle(.teal)
                }
            }
            NavigationLink(destination: LaborwerteView()) {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Laborwerte")
                        if let letzter = alleLaborwerte.first {
                            Text("\(letzter.typ): \(String(format: "%.1f", letzter.wert)) \(letzter.einheit)")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                } icon: {
                    Image(systemName: "testtube.2").foregroundStyle(.blue)
                }
            }
            NavigationLink(destination: PhysioView()) {
                Label("Physiotherapie", systemImage: "figure.walk.motion")
            }
            NavigationLink(destination: ZyklusView()) {
                Label("Zyklus-Tracking", systemImage: "drop.fill")
            }
        }
    }

    // MARK: - Erkrankungen

    private var erkrankungenSektion: some View {
        Section("Erkrankungen") {
            NavigationLink(destination: RheumaView()) {
                Label { Text("Rheuma & Gelenke") } icon: {
                    Image(systemName: "figure.arms.open").foregroundStyle(.teal)
                }
            }
            NavigationLink(destination: MigraeneView()) {
                Label { Text("Migräne") } icon: {
                    Image(systemName: "brain.head.profile").foregroundStyle(.purple)
                }
            }
            NavigationLink(destination: HautView()) {
                Label { Text("Hautveränderungen") } icon: {
                    Image(systemName: "bandage.fill").foregroundStyle(.orange)
                }
            }
            NavigationLink(destination: DiabetesView()) {
                Label { Text("Diabetes") } icon: {
                    Image(systemName: "drop.fill").foregroundStyle(.blue)
                }
            }
        }
    }

    // MARK: - Module

    private var moduleSektion: some View {
        Section {
            Toggle(isOn: $migraeneModulAktiv) {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Migräne")
                        Text("Anfälle separat erfassen & im Verlauf anzeigen")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "brain.head.profile").foregroundStyle(.purple)
                }
            }
            Toggle(isOn: $rheumaModulAktiv) {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Rheuma & Gelenke")
                        Text("Gelenkstatus & Scores beim Eintrag")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "figure.arms.open").foregroundStyle(.teal)
                }
            }
            Toggle(isOn: $hautAktiv) {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Hautveränderungen")
                        Text("Foto, Art & Verlauf").font(.caption).foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "bandage.fill").foregroundStyle(.orange)
                }
            }
            Toggle(isOn: $diabetesModulAktiv) {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Diabetes")
                        Text("Blutzucker & HbA1c tracken")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "drop.fill").foregroundStyle(.blue)
                }
            }
        } header: {
            Text("Meine Module")
        } footer: {
            Text("Aktivierte Module erscheinen bei der Eintragserfassung als Auswahlmöglichkeit.")
        }
    }

    // MARK: - Kontakte

    private var notfallSektion: some View {
        Section("Kontakte") {
            NavigationLink(destination: AerzteView(profil: profil)) {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Ärzte")
                        let aerzteListe = profil.aerzte ?? []
                        if !aerzteListe.isEmpty {
                            Text(aerzteListe.prefix(2).map { $0.name.isEmpty ? $0.praxis : $0.name }.joined(separator: ", "))
                                .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        }
                    }
                } icon: {
                    Image(systemName: "stethoscope").foregroundStyle(.blue)
                }
            }
            NavigationLink(destination: NotfallkontakteView(profil: profil)) {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Notfallkontakte")
                        let kontaktListe = profil.notfallkontakte ?? []
                        if !kontaktListe.isEmpty {
                            Text(kontaktListe.prefix(2).map(\.name).joined(separator: ", "))
                                .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        }
                    }
                } icon: {
                    Image(systemName: "phone.fill").foregroundStyle(.green)
                }
            }
        }
    }

    // MARK: - Einstellungen

    private var einstellungen: some View {
        Section("Einstellungen") {
            NavigationLink(destination: EinstellungenView()) {
                Label("App-Einstellungen", systemImage: "gearshape")
            }
        }
    }
}

// MARK: - Stammdaten Sheet

private struct StammdatenSheet: View {
    @Environment(\.dismiss) private var dismiss
    let profil: Benutzerprofil
#if os(iOS)
    @State private var photoItem: PhotosPickerItem? = nil
    @State private var zuschneidenBild: IdentifiableImage? = nil
#endif

    var body: some View {
        NavigationStack {
            Form {
#if os(iOS)
                Section {
                    HStack {
                        Spacer()
                        PhotosPicker(selection: $photoItem, matching: .images) {
                            profilBild
                        }
                        .buttonStyle(.plain)
                        Spacer()
                    }
                }
                .listRowBackground(Color.clear)
#endif
                Section("Persönlich") {
                    LabeledContent("Vorname") {
                        TextField("Vorname", text: Bindable(profil).vorname)
                            .multilineTextAlignment(.trailing)
                    }
                    LabeledContent("Nachname") {
                        TextField("Nachname", text: Bindable(profil).nachname)
                            .multilineTextAlignment(.trailing)
                    }
                    DatePicker("Geburtsdatum",
                        selection: Binding(
                            get: { profil.geburtsdatum ?? Date() },
                            set: { profil.geburtsdatum = $0 }
                        ),
                        displayedComponents: .date
                    )
                    Picker("Geschlecht", selection: Bindable(profil).geschlecht) {
                        Text("Weiblich").tag("Weiblich")
                        Text("Männlich").tag("Männlich")
                        Text("Divers").tag("Divers")
                        Text("Keine Angabe").tag("")
                    }
                    LabeledContent("Wohnort") {
                        TextField("Wohnort", text: Bindable(profil).wohnort)
                            .multilineTextAlignment(.trailing)
                    }
                }
                Section("Medizinisch") {
                    LabeledContent("Versicherung") {
                        TextField("Krankenversicherung", text: Bindable(profil).versicherung)
                            .multilineTextAlignment(.trailing)
                    }
                    LabeledContent("Versicherungs-Nr.") {
                        TextField("Nummer", text: Bindable(profil).versicherungsNummer)
                            .multilineTextAlignment(.trailing)
                    }
                    Picker("Blutgruppe", selection: Bindable(profil).blutgruppe) {
                        ForEach(["", "A+", "A-", "B+", "B-", "AB+", "AB-", "0+", "0-"], id: \.self) {
                            Text($0.isEmpty ? "Unbekannt" : $0).tag($0)
                        }
                    }
                    LabeledContent("Gewicht (kg)") {
                        TextField("z.B. 70", value: Bindable(profil).gewichtKg, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    LabeledContent("Grösse (cm)") {
                        TextField("z.B. 170", value: Bindable(profil).groesseCm, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    if let bmi = profil.bmi {
                        LabeledContent("BMI", value: String(format: "%.1f – %@", bmi, profil.bmiKategorie ?? ""))
                    }
                }
            }
            .navigationTitle("Stammdaten")
            .navigationBarTitleDisplayMode(.inline)
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
#if os(iOS)
            .onChange(of: photoItem) { _, item in
                Task {
                    if let data = try? await item?.loadTransferable(type: Data.self),
                       let uiImage = UIImage(data: data) {
                        zuschneidenBild = IdentifiableImage(image: uiImage)
                    }
                }
            }
            .sheet(item: $zuschneidenBild) { wrapper in
                FotoZuschneidenView(uiImage: wrapper.image) { data in
                    profil.fotoData = data
                }
            }
#endif
        }
    }

#if os(iOS)
    @ViewBuilder
    private var profilBild: some View {
        if let data = profil.fotoData, let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable().scaledToFill()
                .frame(width: 88, height: 88)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.secondary.opacity(0.3), lineWidth: 1))
        } else {
            ZStack {
                Circle().fill(Color.secondary.opacity(0.15)).frame(width: 88, height: 88)
                Image(systemName: "person.fill").font(.system(size: 40)).foregroundStyle(.secondary)
                Circle().fill(Color.accentColor).frame(width: 26, height: 26)
                    .overlay(Image(systemName: "camera.fill").font(.system(size: 12)).foregroundStyle(.white))
                    .offset(x: 28, y: 28)
            }
        }
    }
#endif
}

// MARK: - Foto Zuschneiden

#if os(iOS)
private struct IdentifiableImage: Identifiable {
    let id = UUID()
    let image: UIImage
}

private struct FotoZuschneidenView: View {
    let uiImage: UIImage
    let onSave: (Data) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @GestureState private var dragDelta: CGSize = .zero
    @GestureState private var pinchDelta: CGFloat = 1.0

    private let frameSize: CGFloat = 280

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                VStack(spacing: 24) {
                    Spacer()
                    ZStack {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .scaleEffect(scale * pinchDelta)
                            .offset(
                                x: offset.width + dragDelta.width,
                                y: offset.height + dragDelta.height
                            )
                            .gesture(
                                DragGesture()
                                    .updating($dragDelta) { val, state, _ in state = val.translation }
                                    .onEnded { val in
                                        offset.width += val.translation.width
                                        offset.height += val.translation.height
                                    }
                            )
                            .simultaneousGesture(
                                MagnificationGesture()
                                    .updating($pinchDelta) { val, state, _ in state = val }
                                    .onEnded { val in
                                        scale = max(1.0, min(6.0, scale * val))
                                    }
                            )
                    }
                    .frame(width: frameSize, height: frameSize)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.6), lineWidth: 2))
                    Spacer()
                    Text("Verschieben und zoomen")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                        .padding(.bottom, 8)
                }
            }
            .navigationTitle("Foto anpassen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(.black, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }.foregroundStyle(.white)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Verwenden") {
                        if let data = renderCrop() { onSave(data) }
                        dismiss()
                    }.foregroundStyle(.white)
                }
            }
        }
    }

    private func renderCrop() -> Data? {
        let size = CGSize(width: frameSize, height: frameSize)
        let imgW = uiImage.size.width
        let imgH = uiImage.size.height
        let fillScale = max(frameSize / imgW, frameSize / imgH)
        let totalScale = fillScale * scale
        let drawW = imgW * totalScale
        let drawH = imgH * totalScale
        let x = (frameSize - drawW) / 2 + offset.width
        let y = (frameSize - drawH) / 2 + offset.height
        let renderer = UIGraphicsImageRenderer(size: size)
        let result = renderer.image { _ in
            UIBezierPath(ovalIn: CGRect(origin: .zero, size: size)).addClip()
            uiImage.draw(in: CGRect(x: x, y: y, width: drawW, height: drawH))
        }
        return result.jpegData(compressionQuality: 0.85)
    }
}
#endif
