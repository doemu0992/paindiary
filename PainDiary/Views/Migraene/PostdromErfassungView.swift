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
                            .foregroundStyle(.purple)
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
                                .foregroundStyle(.purple)
                            Text("Gespeichert!")
                                .font(.headline)
                        }
                        .padding(.vertical, 20)
                        .transition(.scale.combined(with: .opacity))
                    } else {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Symptome wählen")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 4)
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                                ForEach(optionen, id: \.self) { opt in
                                    let sel = ausgewaehlte.contains(opt)
                                    Button {
                                        if sel { ausgewaehlte.remove(opt) } else { ausgewaehlte.insert(opt) }
                                    } label: {
                                        HStack(spacing: 6) {
                                            Image(systemName: sel ? "checkmark.circle.fill" : "circle")
                                                .foregroundStyle(sel ? .purple : .secondary)
                                                .font(.caption)
                                            Text(opt).font(.caption).lineLimit(2)
                                            Spacer()
                                        }
                                        .padding(.horizontal, 10).padding(.vertical, 8)
                                        .background(
                                            sel ? Color.purple.opacity(0.12) : Color(.secondarySystemGroupedBackground),
                                            in: RoundedRectangle(cornerRadius: 10)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                    .animation(.easeInOut(duration: 0.15), value: sel)
                                }
                            }
                        }
                        .padding()
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
                    }

                    Spacer(minLength: 0)
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
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
