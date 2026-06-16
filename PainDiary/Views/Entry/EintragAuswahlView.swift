import SwiftUI

private enum AuswahlTyp: String, Hashable {
    case schmerz, migraene

    var label: String {
        switch self {
        case .schmerz:  return "Schmerz"
        case .migraene: return "Migräne"
        }
    }

    var symbol: String {
        switch self {
        case .schmerz:  return "waveform.path.ecg"
        case .migraene: return "brain.head.profile"
        }
    }

    var farbe: Color {
        switch self {
        case .schmerz:  return .indigo
        case .migraene: return .purple
        }
    }
}

struct EintragAuswahlView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("migraeneModulAktiv") private var migraeneAktiv = false

    @State private var auswahl: Set<AuswahlTyp> = [.schmerz]
    @State private var zeigeMigraene = false
    @State private var zeigeSchmerz = false
    @State private var migraeneFertig = false

    private var verfuegbareTypen: [AuswahlTyp] {
        var typen: [AuswahlTyp] = [.schmerz]
        if migraeneAktiv { typen.append(.migraene) }
        return typen
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Was möchtest du erfassen?")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(verfuegbareTypen, id: \.self) { typ in
                            auswahlKarte(typ)
                        }
                    }
                    .padding(.horizontal)

                    if auswahl.count > 1 {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.right.circle")
                                .font(.caption)
                            Text("Zuerst Migräne, dann Schmerz erfassen.")
                                .font(.caption)
                        }
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                        .transition(.opacity)
                    }
                }
                .padding(.top, 20)
                .animation(.easeInOut(duration: 0.2), value: auswahl.count)
            }
            .navigationTitle("Neuer Eintrag")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Weiter") { weiter() }
                        .fontWeight(.semibold)
                        .disabled(auswahl.isEmpty)
                }
            }
        }
        .sheet(isPresented: $zeigeMigraene, onDismiss: migraeneOnDismiss) {
            MigraeneAnfallForm(onGespeichert: { migraeneFertig = true })
        }
        .sheet(isPresented: $zeigeSchmerz, onDismiss: { dismiss() }) {
            AddEntryView()
        }
    }

    private func auswahlKarte(_ typ: AuswahlTyp) -> some View {
        let gewaehlt = auswahl.contains(typ)
        return Button {
            if gewaehlt {
                auswahl.remove(typ)
            } else {
                auswahl.insert(typ)
            }
        } label: {
            VStack(spacing: 12) {
                Image(systemName: typ.symbol)
                    .font(.system(size: 28))
                    .foregroundStyle(gewaehlt ? .white : typ.farbe)
                Text(typ.label)
                    .font(.subheadline.bold())
                    .foregroundStyle(gewaehlt ? .white : .primary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 28)
            .background(gewaehlt ? typ.farbe : Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(gewaehlt ? typ.farbe : Color.secondary.opacity(0.15),
                            lineWidth: gewaehlt ? 0 : 1)
            )
            .animation(.spring(duration: 0.2), value: gewaehlt)
        }
        .buttonStyle(.plain)
    }

    private func weiter() {
        if auswahl.contains(.migraene) {
            zeigeMigraene = true
        } else {
            zeigeSchmerz = true
        }
    }

    private func migraeneOnDismiss() {
        guard migraeneFertig else {
            migraeneFertig = false
            return
        }
        migraeneFertig = false
        if auswahl.contains(.schmerz) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                zeigeSchmerz = true
            }
        } else {
            dismiss()
        }
    }
}
