import SwiftUI
import SwiftData
import Charts

struct FACITView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FACITEintrag.datum, order: .reverse) private var eintraege: [FACITEintrag]

    @State private var zeigeForm = false

    var body: some View {
        List {
            if let letzter = eintraege.first {
                Section {
                    scoreKarte(letzter)
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .listRowBackground(Color.clear)
            }

            if eintraege.count >= 2 {
                Section("Verlauf") {
                    let daten = eintraege.sorted { $0.datum < $1.datum }
                    Chart(daten) { e in
                        LineMark(
                            x: .value("Datum", e.datum, unit: .day),
                            y: .value("FACIT", e.facitScore)
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(Color.teal)
                        PointMark(
                            x: .value("Datum", e.datum, unit: .day),
                            y: .value("FACIT", e.facitScore)
                        )
                        .foregroundStyle(Color.teal)
                    }
                    .chartYScale(domain: 0...52)
                    .chartYAxis {
                        AxisMarks(values: [0, 13, 26, 30, 39, 52]) { v in
                            AxisGridLine()
                            AxisValueLabel { if let i = v.as(Int.self) { Text("\(i)") } }
                        }
                    }
                    .frame(height: 140)
                    .padding(.vertical, 4)
                }
            }

            Section {
                infoBox
            }
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            .listRowBackground(Color.clear)

            Section(eintraege.isEmpty ? "" : "Einträge") {
                if eintraege.isEmpty {
                    ContentUnavailableView(
                        "Noch kein FACIT erfasst",
                        systemImage: "bolt.heart",
                        description: Text("Tippe auf + um den Fragebogen auszufüllen.")
                    )
                    .listRowSeparator(.hidden)
                } else {
                    ForEach(eintraege) { e in
                        FACITZeile(eintrag: e)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    modelContext.delete(e)
                                } label: {
                                    Label("Löschen", systemImage: "trash")
                                }
                            }
                    }
                }
            }
        }
        .navigationTitle("FACIT-Erschöpfung")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { zeigeForm = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $zeigeForm) { FACITFormView() }
    }

    @ViewBuilder
    private func scoreKarte(_ e: FACITEintrag) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Letzter FACIT-Score", systemImage: "bolt.heart.fill")
                .font(.headline).foregroundStyle(.teal)
            Divider()
            HStack(spacing: 16) {
                VStack(spacing: 4) {
                    Text("\(e.facitScore)")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(scoreFarbe(e.facitScore))
                    Text("von 52").font(.caption).foregroundStyle(.secondary)
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text(e.erschoepfungsgradText)
                        .font(.subheadline.bold())
                        .foregroundStyle(scoreFarbe(e.facitScore))
                    Text(e.datum, style: .date)
                        .font(.caption).foregroundStyle(.secondary)
                    HStack(spacing: 4) {
                        Image(systemName: "info.circle")
                            .font(.caption)
                        Text("Cutoff < 30 = relevante Erschöpfung")
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private func scoreFarbe(_ score: Int) -> Color {
        switch score {
        case 41...52: return .green
        case 31...40: return .yellow
        case 21...30: return .orange
        default:      return .red
        }
    }

    private var infoBox: some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 10) {
                Text("Die FACIT-Fatigue Scale misst Erschöpfung bei chronischen Erkrankungen. 13 Fragen werden mit 0–4 bewertet. Ein Score unter 30 gilt als klinisch relevante Erschöpfung.")
                    .font(.caption).foregroundStyle(.secondary)
                Divider()
                infoPill("41–52", label: "Keine relevante Erschöpfung", farbe: .green)
                infoPill("31–40", label: "Leichte Erschöpfung",         farbe: .yellow)
                infoPill("21–30", label: "Mässige Erschöpfung",         farbe: .orange)
                infoPill(" 0–20", label: "Schwere Erschöpfung",         farbe: .red)
            }
            .padding(.top, 6)
        } label: {
            Label("Was ist FACIT-Erschöpfung?", systemImage: "info.circle")
                .font(.subheadline).foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private func infoPill(_ wert: String, label: String, farbe: Color) -> some View {
        HStack(spacing: 8) {
            Circle().fill(farbe).frame(width: 8, height: 8)
            Text(wert).font(.caption.bold()).foregroundStyle(farbe).frame(width: 44, alignment: .leading)
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
    }
}

private struct FACITZeile: View {
    let eintrag: FACITEintrag

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(eintrag.datum, style: .date).font(.subheadline.bold())
                Text(eintrag.erschoepfungsgradText).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text("\(eintrag.facitScore)")
                    .font(.subheadline.bold()).foregroundStyle(scoreFarbe(eintrag.facitScore))
                Text("FACIT").font(.caption2).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func scoreFarbe(_ score: Int) -> Color {
        switch score {
        case 41...52: return .green
        case 31...40: return .yellow
        case 21...30: return .orange
        default:      return .red
        }
    }
}

// MARK: - Form

struct FACITFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var datum   = Date()
    @State private var item01  = 0
    @State private var item02  = 0
    @State private var item03  = 0
    @State private var item04  = 0
    @State private var item05  = 0
    @State private var item06  = 0
    @State private var item07  = 4
    @State private var item08  = 4
    @State private var item09  = 0
    @State private var item10  = 0
    @State private var item11  = 0
    @State private var item12  = 0
    @State private var item13  = 0
    @State private var notizen = ""

    private let labels = ["Gar nicht", "Wenig", "Mässig", "Ziemlich", "Sehr"]

    private var liveScore: Int {
        let belastung = item01 + item02 + item03 + item04 + item05 + item06
            + item09 + item10 + item11 + item12 + item13
        return item07 + item08 + (4 * 11 - belastung)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Datum") {
                    DatePicker("Datum", selection: $datum, displayedComponents: [.date])
                }

                Section {
                    ForEach(0..<13, id: \.self) { i in
                        fragenZeile(index: i, binding: itemBinding(i))
                    }
                } header: {
                    Text("Wie oft traf dies in den letzten 7 Tagen zu?")
                } footer: {
                    Text("Aktueller FACIT-Score: \(liveScore) / 52")
                        .font(.footnote.bold())
                        .foregroundStyle(scoreFarbe(liveScore))
                }

                Section("Notizen") {
                    TextField("Optionale Notizen", text: $notizen, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("FACIT-Fragebogen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Speichern") { speichern() } }
            }
        }
    }

    private func fragenZeile(index: Int, binding: Binding<Int>) -> some View {
        let frage    = FACITEintrag.fragen[index]
        let reversed = frage.reversed

        return VStack(alignment: .leading, spacing: 8) {
            Text(frage.text).font(.subheadline.bold())
            HStack(spacing: 4) {
                ForEach(0..<5, id: \.self) { stufe in
                    // Reversed items: 0 = schlecht (rot), 4 = gut (grün)
                    // Normal items: 0 = gut (grün), 4 = schlecht (rot)
                    let farbe = reversed ? stufenFarbeReversed(stufe) : stufenFarbe(stufe)
                    Button {
                        binding.wrappedValue = stufe
                    } label: {
                        VStack(spacing: 3) {
                            Text("\(stufe)")
                                .font(.headline.bold())
                            Text(labels[stufe])
                                .font(.system(size: 8, weight: .medium))
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(
                            binding.wrappedValue == stufe
                                ? farbe.opacity(0.18)
                                : Color(.tertiarySystemBackground),
                            in: RoundedRectangle(cornerRadius: 8)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(binding.wrappedValue == stufe ? farbe : Color.clear, lineWidth: 1.5)
                        )
                        .foregroundStyle(binding.wrappedValue == stufe ? farbe : .secondary)
                    }
                    .buttonStyle(.plain)
                    .animation(.spring(response: 0.2), value: binding.wrappedValue)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func stufenFarbe(_ i: Int) -> Color {
        switch i {
        case 0: return .green
        case 1: return .yellow
        case 2: return .orange
        case 3: return .red
        default: return .red
        }
    }

    // For reversed items: "Sehr" (4) means "lots of energy" → green
    private func stufenFarbeReversed(_ i: Int) -> Color {
        stufenFarbe(4 - i)
    }

    private func scoreFarbe(_ score: Int) -> Color {
        switch score {
        case 41...52: return .green
        case 31...40: return .yellow
        case 21...30: return .orange
        default:      return .red
        }
    }

    private func itemBinding(_ i: Int) -> Binding<Int> {
        switch i {
        case 0:  return $item01
        case 1:  return $item02
        case 2:  return $item03
        case 3:  return $item04
        case 4:  return $item05
        case 5:  return $item06
        case 6:  return $item07
        case 7:  return $item08
        case 8:  return $item09
        case 9:  return $item10
        case 10: return $item11
        case 11: return $item12
        case 12: return $item13
        default: return $item01
        }
    }

    private func speichern() {
        let neu = FACITEintrag(datum: datum)
        neu.item01 = item01; neu.item02 = item02; neu.item03 = item03
        neu.item04 = item04; neu.item05 = item05; neu.item06 = item06
        neu.item07 = item07; neu.item08 = item08; neu.item09 = item09
        neu.item10 = item10; neu.item11 = item11; neu.item12 = item12
        neu.item13 = item13; neu.notizen = notizen
        modelContext.insert(neu)
        dismiss()
    }
}
