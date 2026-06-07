import SwiftUI
import SwiftData

struct HautSchnellerfassungView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var datum = Date()
    @State private var hautStellen = ""
    @State private var hautArt = ""
    @State private var fotoDateiname = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    HStack {
                        DatePicker("", selection: $datum, displayedComponents: [.date, .hourAndMinute])
                            .labelsHidden()
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.top, 12)
                    .padding(.bottom, 8)

                    HautStepView(
                        hautStellen: $hautStellen,
                        hautArt: $hautArt,
                        fotoDateiname: $fotoDateiname
                    )
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("Hautveränderung")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") { speichern() }
                        .fontWeight(.semibold)
                        .disabled(hautStellen.isEmpty && hautArt.isEmpty)
                }
            }
        }
    }

    private func speichern() {
        let neu = PainEntry(
            datum: datum,
            schmerzstaerke: 0,
            hautStellen: hautStellen,
            hautArt: hautArt,
            fotoDateiname: fotoDateiname
        )
        modelContext.insert(neu)
        dismiss()
    }
}
