import SwiftUI
import SwiftData

struct PostdromErfassungView: View {
    let anfall: MigraeneEintrag
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var ausgewaehlte: Set<String> = []
    @State private var gespeichert = false

    private let optionen = [
        "Erschöpfung", "Konzentrationsprobleme", "Stimmungstief",
        "Kopfhaut empfindlich", "Schwindel", "Helligkeitsempfindlichkeit", "Hunger"
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 6) {
                        Image(systemName: "arrow.clockwise.circle.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(.teal)
                        Text("Postdromsymptome")
                            .font(.title2.bold())
                        Text("Wie geht es dir nach dem Migräne-Anfall?")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 8)

                    if gespeichert {
                        VStack(spacing: 12) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 52))
                                .foregroundStyle(.teal)
                            Text("Gespeichert!")
                                .font(.headline)
                        }
                        .padding(.vertical, 20)
                        .transition(.scale.combined(with: .opacity))
                    } else {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Symptome wählen")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)
                            FlowLayout(optionen) { opt in
                                ChipButton(
                                    titel: opt,
                                    ausgewaehlt: ausgewaehlte.contains(opt),
                                    farbe: .teal
                                ) {
                                    if ausgewaehlte.contains(opt) {
                                        ausgewaehlte.remove(opt)
                                    } else {
                                        ausgewaehlte.insert(opt)
                                    }
                                }
                            }
                        }
                        .padding()
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
                    }

                    Spacer(minLength: 0)
                }
                .padding()
            }
            .navigationTitle("Nachklang erfassen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Später") { dismiss() }
                }
                if !gespeichert {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Speichern") { speichern() }
                            .disabled(ausgewaehlte.isEmpty)
                    }
                }
            }
            .onAppear {
                if !anfall.postdrom.isEmpty {
                    ausgewaehlte = Set(anfall.postdrom.components(separatedBy: ", ").filter { !$0.isEmpty })
                }
            }
        }
    }

    private func speichern() {
        anfall.postdrom = ausgewaehlte.sorted().joined(separator: ", ")
        try? modelContext.save()
        withAnimation(.spring(response: 0.4)) {
            gespeichert = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            dismiss()
        }
    }
}
