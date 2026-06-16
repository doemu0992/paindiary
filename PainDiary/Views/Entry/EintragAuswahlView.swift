import SwiftUI

private enum AuswahlTyp: String, Hashable, CaseIterable {
    case schmerz, migraene, rheuma, diabetes

    var label: String {
        switch self {
        case .schmerz:  return "Schmerz"
        case .migraene: return "Migräne"
        case .rheuma:   return "Rheuma & Gelenke"
        case .diabetes: return "Diabetes"
        }
    }

    var untertitel: String {
        switch self {
        case .schmerz:  return "Schmerzstärke, Ort & Verlauf"
        case .migraene: return "Anfall, Aura & Medikament"
        case .rheuma:   return "Gelenke, Schub & Fatigue"
        case .diabetes: return "Blutzucker & Insulindosis"
        }
    }

    var symbol: String {
        switch self {
        case .schmerz:  return "waveform.path.ecg"
        case .migraene: return "brain.head.profile"
        case .rheuma:   return "figure.arms.open"
        case .diabetes: return "drop.fill"
        }
    }

    var farbe: Color {
        switch self {
        case .schmerz:  return .indigo
        case .migraene: return .purple
        case .rheuma:   return .teal
        case .diabetes: return .orange
        }
    }
}

struct EintragAuswahlView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("migraeneModulAktiv") private var migraeneAktiv = false
    @AppStorage("rheumaModulAktiv")   private var rheumaAktiv   = false
    @AppStorage("diabetesModulAktiv") private var diabetesAktiv = false

    @State private var auswahl: Set<AuswahlTyp> = []

    // Sheet-Flags (in Ablauf-Reihenfolge)
    @State private var zeigeMigraene = false
    @State private var zeigeSchmerz  = false
    @State private var zeigeRheuma   = false
    @State private var zeigeDiabetes = false

    // Saved-Flags: unterscheiden Speichern vs. Abbrechen
    @State private var migraeneFertig = false
    @State private var schmerzFertig  = false
    @State private var rheumaFertig   = false
    @State private var diabetesFertig = false

    // Ablauf: Migräne → Schmerz → Rheuma → Diabetes
    private var ablauf: [AuswahlTyp] {
        [.migraene, .schmerz, .rheuma, .diabetes].filter { auswahl.contains($0) }
    }

    private var verfuegbareTypen: [AuswahlTyp] {
        var typen: [AuswahlTyp] = [.schmerz]
        if migraeneAktiv { typen.append(.migraene) }
        if rheumaAktiv   { typen.append(.rheuma) }
        if diabetesAktiv { typen.append(.diabetes) }
        return typen
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(verfuegbareTypen, id: \.self) { typ in
                        auswahlZeile(typ)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 16)

                if ablauf.count > 1 {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.right.circle")
                            .font(.caption)
                        Text(ablauf.map(\.label).joined(separator: " → "))
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .transition(.opacity)
                }
            }
            .navigationTitle("Was erfassen?")
            .navigationBarTitleDisplayMode(.inline)
            .animation(.easeInOut(duration: 0.15), value: auswahl)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Weiter") { naechsterSchritt(nach: nil) }
                        .fontWeight(.semibold)
                        .disabled(auswahl.isEmpty)
                }
            }
        }
        .sheet(isPresented: $zeigeMigraene, onDismiss: {
            fertigHandler(typ: .migraene, fertig: &migraeneFertig)
        }) {
            MigraeneAnfallForm(onGespeichert: { migraeneFertig = true })
        }
        .sheet(isPresented: $zeigeSchmerz, onDismiss: {
            fertigHandler(typ: .schmerz, fertig: &schmerzFertig)
        }) {
            SchmerzForm(onGespeichert: { schmerzFertig = true })
        }
        .sheet(isPresented: $zeigeRheuma, onDismiss: {
            fertigHandler(typ: .rheuma, fertig: &rheumaFertig)
        }) {
            RheumaSchnellForm(onGespeichert: { rheumaFertig = true })
        }
        .sheet(isPresented: $zeigeDiabetes, onDismiss: {
            fertigHandler(typ: .diabetes, fertig: &diabetesFertig)
        }) {
            BlutzuckerForm(onGespeichert: { diabetesFertig = true })
        }
    }

    // MARK: - Row

    private func auswahlZeile(_ typ: AuswahlTyp) -> some View {
        let gewaehlt = auswahl.contains(typ)
        return Button {
            if gewaehlt { auswahl.remove(typ) } else { auswahl.insert(typ) }
        } label: {
            HStack(spacing: 16) {
                Image(systemName: typ.symbol)
                    .font(.title3)
                    .foregroundStyle(typ.farbe)
                    .frame(width: 36, height: 36)
                    .background(typ.farbe.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 3) {
                    Text(typ.label)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(typ.untertitel)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                ZStack {
                    Circle()
                        .stroke(gewaehlt ? typ.farbe : Color.secondary.opacity(0.4), lineWidth: 1.5)
                        .frame(width: 24, height: 24)
                    if gewaehlt {
                        Circle()
                            .fill(typ.farbe)
                            .frame(width: 16, height: 16)
                    }
                }
                .animation(.spring(duration: 0.2), value: gewaehlt)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 18)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Flow

    private func naechsterSchritt(nach letzter: AuswahlTyp?) {
        let naechster: AuswahlTyp?
        if let letzter {
            let idx = ablauf.firstIndex(of: letzter)
            naechster = idx.map { ablauf.index(after: $0) }.flatMap {
                $0 < ablauf.endIndex ? ablauf[$0] : nil
            }
        } else {
            naechster = ablauf.first
        }

        guard let typ = naechster else {
            dismiss()
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + (letzter == nil ? 0 : 0.35)) {
            switch typ {
            case .migraene: zeigeMigraene = true
            case .schmerz:  zeigeSchmerz  = true
            case .rheuma:   zeigeRheuma   = true
            case .diabetes: zeigeDiabetes = true
            }
        }
    }

    private func fertigHandler(typ: AuswahlTyp, fertig: inout Bool) {
        guard fertig else { fertig = false; return }
        fertig = false
        naechsterSchritt(nach: typ)
    }
}
