import SwiftUI
import SwiftData

struct ArztbesuchView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Arztbesuch.datum, order: .reverse) private var besuche: [Arztbesuch]

    @State private var zeigeForm = false
    @State private var bearbeitet: Arztbesuch? = nil
    @State private var zeigeGuide = false

    var body: some View {
        List {
            if augenarztErinnerungNoetig {
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: "eye.trianglebadge.exclamationmark.fill")
                            .font(.title2).foregroundStyle(.orange)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Augenarzt-Kontrolle empfohlen")
                                .font(.subheadline.bold())
                            Text(letzterAugenarztBesuch == nil
                                 ? "Noch kein Augenarzt-Besuch dokumentiert."
                                 : "Letzter Besuch vor über 12 Monaten.")
                                .font(.caption).foregroundStyle(.secondary)
                            Text("Rheumapatienten sollten jährlich zum Augenarzt (Uveitis-Screening).")
                                .font(.caption2).foregroundStyle(.tertiary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            if besuche.isEmpty {
                ContentUnavailableView(
                    "Keine Arztbesuche",
                    systemImage: "stethoscope",
                    description: Text("Tippe auf + um einen Arztbesuch zu dokumentieren.")
                )
                .listRowSeparator(.hidden)
            } else {
                // Next appointment reminder
                if let naechster = besuche.compactMap(\.naechsterTermin).filter({ $0 > Date() }).min() {
                    Section {
                        HStack(spacing: 12) {
                            Image(systemName: "calendar.badge.clock")
                                .font(.title2).foregroundStyle(.blue)
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Nächster Termin")
                                    .font(.subheadline.bold())
                                Text(naechster, style: .date)
                                    .font(.caption).foregroundStyle(.secondary)
                                Text(naechster, style: .relative)
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section("Verlauf") {
                    ForEach(besuche) { besuch in
                        Button { bearbeitet = besuch } label: {
                            ArztbesuchZeile(besuch: besuch)
                        }
                        .buttonStyle(.plain)
                    }
                    .onDelete(perform: loeschen)
                }
            }
        }
        .navigationTitle("Arztbesuche")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { zeigeForm = true } label: { Image(systemName: "plus") }
            }
            ToolbarItem(placement: .secondaryAction) {
                Button {
                    zeigeGuide = true
                } label: {
                    Label("Termin vorbereiten", systemImage: "doc.text.magnifyingglass")
                }
            }
        }
        .sheet(isPresented: $zeigeForm) { ArztbesuchForm() }
        .sheet(item: $bearbeitet) { ArztbesuchForm(besuch: $0) }
        .sheet(isPresented: $zeigeGuide) { KonsultationsGuideView() }
    }

    private var letzterAugenarztBesuch: Arztbesuch? {
        besuche.first {
            $0.fachgebiet.localizedCaseInsensitiveContains("augenarzt") ||
            $0.fachgebiet.localizedCaseInsensitiveContains("augenheilkunde")
        }
    }

    private var augenarztErinnerungNoetig: Bool {
        guard let letzter = letzterAugenarztBesuch else { return true }
        let monate = Calendar.current.dateComponents([.month], from: letzter.datum, to: Date()).month ?? 0
        return monate >= 12
    }

    private func loeschen(_ offsets: IndexSet) {
        offsets.map { besuche[$0] }.forEach { modelContext.delete($0) }
    }
}

private struct ArztbesuchZeile: View {
    let besuch: Arztbesuch

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(besuch.datum, style: .date)
                    .font(.subheadline.bold())
                if !besuch.fachgebiet.isEmpty {
                    Text("·").foregroundStyle(.secondary)
                    Text(besuch.fachgebiet)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            if !besuch.arzt.isEmpty {
                Text(besuch.arzt).font(.caption).foregroundStyle(.secondary)
            }
            if !besuch.befund.isEmpty {
                Text(besuch.befund)
                    .font(.caption)
                    .foregroundStyle(.primary.opacity(0.8))
                    .lineLimit(2)
            }
            if !besuch.therapieaenderung.isEmpty {
                Label(besuch.therapieaenderung, systemImage: "pills.fill")
                    .font(.caption)
                    .foregroundStyle(.teal)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Form

struct ArztbesuchForm: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var besuch: Arztbesuch? = nil

    @State private var datum = Date()
    @State private var arzt = ""
    @State private var fachgebiet = ""
    @State private var befund = ""
    @State private var therapieaenderung = ""
    @State private var hatNaechstenTermin = false
    @State private var naechsterTermin = Date()
    @State private var notizen = ""

    @State private var schritt = 0
    private let maxSchritt = 1
    private let pflichtSchritte: Set<Int> = [0]

    private let fachgebiete = ["Rheumatologie", "Allgemeinmedizin", "Orthopädie", "Neurologie",
                                "Augenheilkunde", "Dermatologie", "Kardiologie",
                                "Gastroenterologie", "Innere Medizin"]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.teal.opacity(0.15)).frame(height: 3)
                        Capsule().fill(Color.teal)
                            .frame(width: geo.size.width * CGFloat(schritt + 1) / CGFloat(maxSchritt + 1), height: 3)
                            .animation(.easeInOut(duration: 0.3), value: schritt)
                    }
                }
                .frame(height: 3).padding(.horizontal).padding(.top, 10)

                Group {
                    switch schritt {
                    case 0: schritt0
                    default: schritt1
                    }
                }
                .frame(maxHeight: .infinity)

                navigationsLeiste
            }
            .navigationTitle(besuch == nil ? "Neuer Besuch" : "Besuch bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
            }
        }
        .onAppear { laden() }
    }

    private var schritt0: some View {
        ScrollView {
            VStack(spacing: 20) {
                schrittHeader(symbol: "stethoscope.circle.fill", titel: "Arztbesuch", untertitel: "Datum, Arzt und Fachgebiet")

                VStack(spacing: 0) {
                    HStack {
                        Text("Datum").foregroundStyle(.secondary)
                        Spacer()
                        DatePicker("", selection: $datum, displayedComponents: [.date]).labelsHidden()
                    }
                    .font(.subheadline).padding(16)
                    Divider().padding(.leading, 16)
                    TextField("Arzt / Ärztin", text: $arzt)
                        .font(.subheadline).padding(16)
                    Divider().padding(.leading, 16)
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Fachgebiet").font(.subheadline).foregroundStyle(.secondary)
                            .padding(.horizontal, 16).padding(.top, 12)
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                            ForEach(fachgebiete, id: \.self) { fg in
                                let sel = fachgebiet == fg
                                Button { fachgebiet = fg } label: {
                                    Text(fg).font(.caption2).multilineTextAlignment(.center)
                                        .frame(maxWidth: .infinity).padding(.vertical, 10)
                                        .background(sel ? Color.teal : Color(.tertiarySystemGroupedBackground),
                                                    in: RoundedRectangle(cornerRadius: 10))
                                        .foregroundStyle(sel ? .white : .primary)
                                        .animation(.easeInOut(duration: 0.15), value: sel)
                                }.buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 16).padding(.bottom, 12)
                    }
                }
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal).padding(.vertical, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color(.systemGroupedBackground))
    }

    private var schritt1: some View {
        ScrollView {
            VStack(spacing: 20) {
                schrittHeader(symbol: "doc.text.fill", titel: "Details", untertitel: "Befund, Notizen und nächster Termin (optional)")

                VStack(spacing: 0) {
                    TextField("Befund / Diagnose", text: $befund, axis: .vertical)
                        .lineLimit(3...6).font(.subheadline).padding(16)
                    Divider().padding(.leading, 16)
                    TextField("Therapieänderung / Medikamente", text: $therapieaenderung, axis: .vertical)
                        .lineLimit(2...4).font(.subheadline).padding(16)
                    Divider().padding(.leading, 16)
                    TextField("Weitere Notizen…", text: $notizen, axis: .vertical)
                        .lineLimit(2...4).font(.subheadline).padding(16)
                    Divider().padding(.leading, 16)
                    HStack {
                        Text("Nächsten Termin eintragen").foregroundStyle(.secondary)
                        Spacer()
                        Toggle("", isOn: $hatNaechstenTermin).labelsHidden().tint(.teal)
                    }
                    .font(.subheadline).padding(16)
                    if hatNaechstenTermin {
                        Divider().padding(.leading, 16)
                        HStack {
                            Text("Nächster Termin").foregroundStyle(.secondary)
                            Spacer()
                            DatePicker("", selection: $naechsterTermin, in: Date()..., displayedComponents: [.date]).labelsHidden()
                        }
                        .font(.subheadline).padding(16)
                    }
                }
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal).padding(.vertical, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color(.systemGroupedBackground))
    }

    private var navigationsLeiste: some View {
        HStack(spacing: 12) {
            if schritt > 0 {
                Button { withAnimation { schritt -= 1 } } label: {
                    Text("Zurück").font(.subheadline.bold()).frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
                }.buttonStyle(.plain)
            }
            if !pflichtSchritte.contains(schritt) && schritt < maxSchritt {
                Button { withAnimation { schritt += 1 } } label: {
                    Text("Überspringen").font(.subheadline).foregroundStyle(.secondary)
                }
            }
            if schritt < maxSchritt {
                Button { withAnimation { schritt += 1 } } label: {
                    Text("Weiter ›").font(.subheadline.bold()).foregroundStyle(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(Color.teal, in: RoundedRectangle(cornerRadius: 12))
                }.buttonStyle(.plain)
            } else {
                Button { speichern() } label: {
                    Label("Speichern", systemImage: "checkmark").font(.subheadline.bold()).foregroundStyle(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(Color.teal, in: RoundedRectangle(cornerRadius: 12))
                }.buttonStyle(.plain)
            }
        }
        .padding().background(.ultraThinMaterial)
    }

    private func schrittHeader(symbol: String, titel: String, untertitel: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: symbol).font(.system(size: 32)).foregroundStyle(.teal)
            Text(titel).font(.title3.bold())
            Text(untertitel).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }.frame(maxWidth: .infinity).padding(.bottom, 4)
    }

    private func laden() {
        guard let b = besuch else { return }
        datum = b.datum; arzt = b.arzt; fachgebiet = b.fachgebiet
        befund = b.befund; therapieaenderung = b.therapieaenderung; notizen = b.notizen
        if let t = b.naechsterTermin { hatNaechstenTermin = true; naechsterTermin = t }
    }

    private func speichern() {
        if let b = besuch {
            b.datum = datum; b.arzt = arzt; b.fachgebiet = fachgebiet
            b.befund = befund; b.therapieaenderung = therapieaenderung
            b.naechsterTermin = hatNaechstenTermin ? naechsterTermin : nil
            b.notizen = notizen
        } else {
            let neu = Arztbesuch(datum: datum, arzt: arzt, fachgebiet: fachgebiet)
            neu.befund = befund; neu.therapieaenderung = therapieaenderung
            neu.naechsterTermin = hatNaechstenTermin ? naechsterTermin : nil
            neu.notizen = notizen
            modelContext.insert(neu)
        }
        dismiss()
    }
}
