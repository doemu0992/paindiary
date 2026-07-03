# PainDiary – Design & Code Standard

This document is the binding standard for all UI work in this project.
Every new screen, module, and edit must follow these rules.

---

## Module-Tint Colors

| Modul | Primärfarbe | `progressTint` |
|---|---|---|
| Schmerz | `.red` | `.red` |
| Rheuma | `.teal` | `.teal` |
| Migräne | `.purple` | `.purple` |
| Haut | `.orange` | `.orange` |
| Diabetes | `.blue` | `.blue` |
| Wellness | `.mint` (Charts/Daten: Multi-Color) | `.mint` |

**Neues Modul:** einfach nächste freie Farbe aus SwiftUI-Palette wählen (z.B. `.indigo`, `.cyan`, `.pink`). Farbe in diese Tabelle eintragen. Niemals eine bereits vergebene Farbe wiederverwenden.

### Farbkonsistenz-Regel (bindend)

> **Alle Views eines Moduls verwenden exakt dieselbe Modul-Tintfarbe.**

Das gilt ausnahmslos für:
- Dashboard-Kachel (Icon, Text, Chart, Plus-Button)
- Modul-Hauptseite (Header-Label, Analyse-Button)
- AnalyseView (Karten-Titel, Chart-Farbe, Anpassen-Icon)
- Alle Sub-Views des Moduls (HAQ, FACIT, Kortison, Biologika, …)
- Wizard/Form `progressTint`

**Semantische Ausnahmen** (erlaubt, weil inhaltlich begründet):
- `.red` / `.orange` / `.green` für Statuswerte (Hypo, Hyper, gut/schlecht)
- `.indigo` für HAQ-Score (etablierter medizinischer Kontext)
- `.orange` für Morgensteifigkeit > 30 Min. (Warnfarbe)
- `.red` für Schübe / Gefahrenwerte

Bei einem neuen Modul: **zuerst Farbe in Tabelle eintragen**, dann konsequent durch alle Views ziehen — Kachel, Hauptseite, Analyse, Sub-Views.

### ProfilView-Konsistenz (bindend)

> **Erkrankungen-Section und Meine-Module-Toggles verwenden exakt die Modul-Tintfarbe als Icon-Farbe.**

```swift
// Erkrankungen-Section
NavigationLink(destination: RheumaView()) {
    Label { Text("Rheuma & Gelenke") } icon: {
        Image(systemName: "figure.arms.open").foregroundStyle(.teal)   // Rheuma-Tint
    }
}

// Meine-Module-Toggles
Toggle(isOn: $rheumaModulAktiv) {
    Label { VStack { ... } } icon: {
        Image(systemName: "figure.arms.open").foregroundStyle(.teal)   // Rheuma-Tint
    }
}
```

Bei jedem neuen Modul: Icon-Farbe in beiden Stellen (Erkrankungen-NavigationLink + Toggle) = Modul-Tint.

---

## Dashboard-Kacheln (Übersicht)

Jedes Modul bekommt eine `*Kachel`-View im `Dashboard/`-Ordner. Alle Kacheln folgen **exakt** diesem Template:

```swift
struct MeinModulKachel: View {
    let eintraege: [MeinEintrag]        // Daten von aussen übergeben
    @State private var zeigeForm = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 1. Header: Titel + Plus-Button
            HStack {
                Label("Modulname", systemImage: "symbol")
                    .font(.headline).foregroundStyle(.modulTint)
                Spacer()
                Button { zeigeForm = true } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3).foregroundStyle(.modulTint)
                }
                .buttonStyle(.plain)
            }

            // 2. Drei Stat-Boxes (immer 3, ggf. "–" als Platzhalt)
            HStack(spacing: 0) {
                statBox(wert: "...", label: "Label1", farbe: .someColor)
                Divider().frame(height: 32)
                statBox(wert: "...", label: "Label2", farbe: .secondary)
                Divider().frame(height: 32)
                statBox(wert: "...", label: "Label3", farbe: .secondary)
            }

            // 3. Mini-Chart 14 Tage (immer anzeigen, Platzhalt wenn leer)
            Chart(chartDaten, id: \.datum) { punkt in
                BarMark(x: .value("Tag", punkt.datum, unit: .day),
                        y: .value("Wert", hatDaten ? punkt.wert : 1.0))
                .foregroundStyle(hatDaten
                    ? Color.modulTint.opacity(punkt.wert > 0 ? 0.75 : 0.1)
                    : Color.modulTint.opacity(0.07))
                .cornerRadius(3)
            }
            .chartXAxis(.hidden).chartYAxis(.hidden)
            .frame(height: 44)
            .overlay(alignment: .center) {
                if !hatDaten {
                    Text("Noch keine Einträge").font(.caption2).foregroundStyle(.secondary)
                }
            }

            Divider()

            // 4. NavigationLink zum Modul
            NavigationLink(destination: MeinModulView()) {
                HStack {
                    Text("Modul öffnen").font(.caption.bold()).foregroundStyle(.modulTint)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption2.bold()).foregroundStyle(Color.modulTint.opacity(0.6))
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .sheet(isPresented: $zeigeForm) { MeinModulForm() }
    }
}
```

**Regeln:**
- Immer **genau 3** `statBox`-Spalten — leere zeigen `"–"` mit `farbe: .secondary`
- Mini-Chart **immer sichtbar** (nie in `if`-Block verstecken) — Platzhalt-Balken wenn keine Daten
- Kachelfarbe = Modul-Tint aus der Farbtabelle oben — gilt für Icon, Text, Chart, Plus-Button
- `statBox`-Helper ist **lokal** in jeder Kachel (kein globales Component nötig)
- **Mini-Chart ist immer tappbar** (siehe unten)

### Klickbare Mini-Chart-Balken (bindend für alle Kacheln)

> **Jeder Mini-Chart in einer Dashboard-Kachel muss tappbar sein und beim Antippen den Tageswert als Tooltip-Zeile einblenden.**

```swift
// 1. State in der Kachel
@State private var ausgewaehltTag: Date? = nil
@State private var versteckTask: Task<Void, Never>? = nil

// 2. chartOverlay auf dem Chart
.chartOverlay { proxy in
    GeometryReader { _ in
        Rectangle().fill(.clear).contentShape(Rectangle())
            .onTapGesture { location in balkenTippen(proxy: proxy, location: location) }
    }
}

// 3. Tooltip-Zeile direkt unter dem Chart (mit .animation)
if let tag = ausgewaehltTag,
   let punkt = chartDaten.first(where: { Calendar.current.isDate($0.datum, inSameDayAs: tag) }) {
    HStack(spacing: 6) {
        Text(tag, format: .dateTime.weekday(.abbreviated).day().month())
            .font(.caption2.bold()).foregroundStyle(.secondary)
        Text("Ø \(String(format: "%.1f", punkt.wert))")
            .font(.caption2).foregroundStyle(wertFarbe(punkt.wert))
        Spacer()
    }
    .transition(.opacity)
}

// 4. VStack-Modifier (animiert die Tooltip ein/aus)
.animation(.easeInOut(duration: 0.2), value: ausgewaehltTag)

// 5. balkenTippen()-Helper (lokal in jeder Kachel)
private func balkenTippen(proxy: ChartProxy, location: CGPoint) {
    guard let date: Date = proxy.value(atX: location.x, as: Date.self) else { return }
    let snapped = chartDaten.min(by: {
        abs($0.datum.timeIntervalSince(date)) < abs($1.datum.timeIntervalSince(date))
    })?.datum
    guard let snapped else { return }
    withAnimation { ausgewaehltTag = snapped }
    versteckTask?.cancel()
    versteckTask = Task {
        try? await Task.sleep(for: .seconds(5))
        guard !Task.isCancelled else { return }
        await MainActor.run { withAnimation { ausgewaehltTag = nil } }
    }
}
```

**Tooltip-Inhalt:** Datum (Wochentag + Tag + Monat) + Wert mit Einheit. Wenn kein Eintrag: "Kein Eintrag". Auto-Hide nach 5 Sekunden. Beides muss mit `.transition(.opacity)` animiert sein.

---

```swift
content()
    .padding(16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color(.secondarySystemGroupedBackground))
    .clipShape(RoundedRectangle(cornerRadius: 16))
```

- **Hintergrund**: immer `Color(.secondarySystemGroupedBackground)` — nie `.secondarySystemBackground`
- **Eckenradius**: 16 pt
- **Padding**: 16 pt innen
- **Screen-Hintergrund**: `Color(.systemGroupedBackground)`

---

## Wohlbefinden-Schritt (Wizards)

Alle Wizards (Schmerz, Rheuma, Haut, Migräne) nutzen **`WohlbefindenStepView`** für den Wohlbefinden-Schritt.
Niemals inline reimplementieren.

```swift
// In schrittInhalt default-case:
ScrollView {
    WohlbefindenStepView(
        stimmung: $stimmung,
        schlafStunden: $schlafStunden,
        stressLevel: $stressLevel,
        notizen: $notizen,
        fatigue: $fatigue           // optional, nur wenn relevant
    )
    .padding(.vertical, 24)
}
.scrollDismissesKeyboard(.interactively)
.background(Color(.systemGroupedBackground))
```

### WohlbefindenStepView – interne Standards

| Element | Implementierung |
|---|---|
| Stimmung | 5 Herz-Buttons, **Einzelauswahl** (nur aktiver Button farbig), Hintergrundkarte pro Button (`farbe.opacity(0.12)` aktiv / `secondary.opacity(0.06)` inaktiv), Label darunter, gewähltes Label als Caption-Zeile unter Grid |
| Stress | 5 dünne vertikale Balken (`width: 6`, Höhe = `stufe * 5 + 8`) in Hintergrundkarte, Farben: green/mint/yellow/orange/red, Labels: Entspannt/Ruhig/Mittel/Gestresst/Sehr hoch |
| Energie | Optional (`energielevel: Binding<Int>? = nil`), 5 Batterie-Icons (`battery.0/25/50/75/100`) in Hintergrundkarte, Labels: Erschöpft/Müde/Okay/Gut/Top, Farben: red/orange/yellow/mint/green |
| Schlaf | Slider 0–12 h, Schritt 0.5, Tint `.indigo` |
| Fatigue | **Nur Rheuma** (`fatigue: Binding<Int>? = nil`), Slider 0–10, Schritt 1, dynamischer Tint (green/orange/red) |
| Morgensteifigkeit | Optional (`morgensteifigkeit: Binding<Int>? = nil`), Button-Grid –/15'/30'/60'/90'+, Tint `.orange` |

**Button-Karte-Muster (bindend für Stimmung, Stress, Energie):**

```swift
Button { wert = stufe } label: {
    VStack(spacing: 5) {
        // Icon (heart.fill / thin bar / battery.X)
        Text(label(stufe))
            .font(.caption2)
            .foregroundStyle(aktiv ? .primary : .secondary)
            .lineLimit(1).minimumScaleFactor(0.7)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 10)
    .background(
        aktiv ? farbe.opacity(0.12) : Color.secondary.opacity(0.06),
        in: RoundedRectangle(cornerRadius: 10)
    )
    .animation(.easeInOut(duration: 0.15), value: aktiv)
}
.buttonStyle(.plain)
```

**Gewähltes Label unter dem Grid:**
```swift
if wert > 0 {
    Text(label(wert))
        .font(.caption).foregroundStyle(farbe(wert))
        .frame(maxWidth: .infinity, alignment: .center)
        .transition(.opacity)
}
```
`.animation(.easeInOut(duration: 0.15), value: wert)` auf der umgebenden `VStack`.

**Parameter von `WohlbefindenStepView` (alle optionalen Bindings sind `nil` by default):**

```swift
struct WohlbefindenStepView: View {
    @Binding var stimmung: Int
    @Binding var schlafStunden: Double
    @Binding var stressLevel: Int
    @Binding var notizen: String
    var morgensteifigkeit: Binding<Int>? = nil
    var fatigue: Binding<Int>? = nil
    var energielevel: Binding<Int>? = nil
    var healthSchlafVorschlag: Double? = nil
}
```

**Neues Modul mit Wohlbefinden-Schritt:** `energielevel` immer übergeben. Dafür muss das SwiftData-Modell `var energielevel: Int = 0` als Feld haben (lightweight migration, Default 0).

### Fatigue vs. Energie — Unterschied und Verwendung (bindend)

> **`fatigue` (Erschöpfung, 0–10) wird ausschliesslich im Rheuma-Wizard übergeben.**

| | Fatigue | Energie & Vitalität |
|---|---|---|
| Skala | 0–10 (medizinisch, höher = schlechter) | 1–5 (allgemein, höher = besser) |
| Bedeutung | Krankheitsbedingtes Erschöpfungsgefühl (Symptom) | Allgemeines Energiegefühl (Wohlbefinden) |
| Klinische Basis | FACIT-Fatigue Score, Rheuma/Autoimmun | Allgemeiner Wellness-Indikator |
| Wizard-Binding | **Nur `RheumaSchnellForm`** | Alle Module |
| Detail-View | Nur Rheuma-Einträge (Symptome-Karte) | Alle Einträge (Wohlbefinden-Karte) |

**Regel:** Schmerz, Migräne, Haut — kein `fatigue: $fatigue` übergeben. Rheuma — `fatigue: $fatigue` übergeben.

### Schlafstunden-Vorbelegung (bindend)

> **Jedes Formular/Wizard, das `schlafStunden` enthält, muss beim Öffnen den heutigen Wert aus der Datenbank vorausfüllen.**

In der `laden()`-Funktion (oder `onAppear`) des Wizards, **nur bei neuen Einträgen** (`eintrag == nil`):

```swift
private func laden() {
    // ... Wetter etc. ...

    // Schlafstunden vom heutigen letzten Eintrag übernehmen
    let heute = Calendar.current.startOfDay(for: Date())
    let heuteDesc = FetchDescriptor<PainEntry>(
        predicate: #Predicate { $0.datum >= heute },
        sortBy: [SortDescriptor(\.datum, order: .reverse)]
    )
    if let letzterHeute = try? modelContext.fetch(heuteDesc).first {
        schlafStunden = letzterHeute.schlafStunden
    }
}
```

**Gilt für:** SchmerzForm ✅, HautForm ✅, RheumaSchnellForm ✅
**Modelle ohne PainEntry** (z.B. MigraeneEintrag, ZyklusEintrag): dasselbe Muster mit dem entsprechenden Modell-Typ in `FetchDescriptor<T>`.

---

## Wizard-Navigationsmuster

Alle Wizards nutzen dieselbe Struktur:

```swift
VStack(spacing: 0) {
    progressBar        // Capsule-Fortschrittsbalken, 3 pt hoch, Modul-Tint
        .padding(.horizontal)
        .padding(.top, 10)
    
    schrittInhalt      // .frame(maxHeight: .infinity)
    
    navigationsLeiste  // Zurück / Überspringen / Weiter › / ✓ Speichern
}
```

- `maxSchritt` = Anzahl Schritte minus 1
- `pflichtSchritte: Set<Int>` = Schritte ohne „Überspringen"-Button
- Animierter Übergang: `.asymmetric(insertion: .move(edge: vorwaerts ? .trailing : .leading))`

---

## Formular-Wizard Standard (bindend für alle CRUD-Formulare)

> **Jedes Formular zum Hinzufügen / Bearbeiten verwendet den Wizard-Stil — kein `Form {}` mehr.**

### Entscheidung: Steps oder Styled Sheet

| Felder | Format |
|---|---|
| 1–4 Felder | 1-Schritt-Wizard (Styled Sheet, kein Fortschrittsbalken) |
| 5+ Felder | Echter Wizard, 2–3 Schritte |

### Struktur (für 2–3 Schritte)

```swift
struct MeinFormView: View {
    @State private var schritt = 0
    private let maxSchritt = 2          // Anzahl Schritte minus 1
    private let pflichtSchritte: Set<Int> = [0, 1]  // kein Überspringen

    private var kannWeiter: Bool {
        switch schritt {
        case 0: return !pflichtFeld.isEmpty
        default: return true
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Fortschrittsbalken (nur wenn maxSchritt > 0)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.modulTint.opacity(0.15)).frame(height: 3)
                        Capsule().fill(Color.modulTint)
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
            .navigationTitle("Neuer Eintrag")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
            }
        }
    }
}
```

### Schritt-Inhalt (ScrollView-Card-Stil)

```swift
private var schritt0: some View {
    ScrollView {
        VStack(spacing: 20) {
            schrittHeader(symbol: "sf.symbol", titel: "Titel", untertitel: "Kurze Beschreibung")

            // Eingabefelder als Cards (kein Form{})
            VStack(spacing: 0) {
                TextField("Placeholder", text: $feld1).font(.subheadline).padding(16)
                Divider().padding(.leading, 16)
                TextField("Placeholder2", text: $feld2).font(.subheadline).padding(16)
            }
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))

            // Auswahl als Button-Grid (statt Picker)
            VStack(alignment: .leading, spacing: 10) {
                Text("Kategorie").font(.caption).foregroundStyle(.secondary).padding(.horizontal, 4)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                    ForEach(optionen, id: \.self) { opt in
                        let sel = auswahl == opt
                        Button { auswahl = opt } label: {
                            Text(opt).font(.caption.bold()).frame(maxWidth: .infinity).padding(.vertical, 10)
                                .background(sel ? Color.modulTint : Color(.secondarySystemGroupedBackground))
                                .foregroundStyle(sel ? .white : .primary)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .animation(.easeInOut(duration: 0.15), value: sel)
                        }.buttonStyle(.plain)
                    }
                }
            }

            // Toggles / DatePicker in Card
            VStack(spacing: 0) {
                Toggle("Option", isOn: $toggle).font(.subheadline).padding(16)
                if toggle {
                    Divider().padding(.leading, 16)
                    DatePicker("Datum", selection: $datum, displayedComponents: .date)
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
```

### Navigationsleiste (identisch in allen Formularen)

```swift
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
            Button { guard kannWeiter else { return }; withAnimation { schritt += 1 } } label: {
                Text("Weiter ›").font(.subheadline.bold()).foregroundStyle(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(kannWeiter ? Color.modulTint : Color.secondary, in: RoundedRectangle(cornerRadius: 12))
            }.buttonStyle(.plain).disabled(!kannWeiter)
        } else {
            Button { speichern() } label: {
                Label("Speichern", systemImage: "checkmark").font(.subheadline.bold()).foregroundStyle(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(Color.modulTint, in: RoundedRectangle(cornerRadius: 12))
            }.buttonStyle(.plain).disabled(!kannSpeichern)
        }
    }
    .padding()
    .background(.ultraThinMaterial)
}
```

### schrittHeader Helper (jedes Formular lokal)

```swift
private func schrittHeader(symbol: String, titel: String, untertitel: String) -> some View {
    VStack(spacing: 8) {
        Image(systemName: symbol).font(.system(size: 32)).foregroundStyle(.modulTint)
        Text(titel).font(.title3.bold())
        Text(untertitel).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
    }
    .frame(maxWidth: .infinity).padding(.bottom, 4)
}
```

### Regeln (bindend)

- **Kein `Form {}`** — immer `ScrollView` + `VStack` + Card-Rows
- **Picker → Button-Grid** wenn ≤ 9 Optionen (3×3 oder 2-spaltig)
- **Picker bleibt Picker** wenn > 9 Optionen oder lange Texte
- **`.ultraThinMaterial`** Hintergrund der Navigationsleiste
- **Modulfarbe** im Fortschrittsbalken und Speichern-Button
- **1-Schritt-Wizards** (einfache Formulare): kein Fortschrittsbalken, kein Schritt-Header, nur Card-Rows + Speichern-Button

---

## Modul-Hauptseiten (Profil-Tabs)

| Element | Standard |
|---|---|
| Layout | `List` (nicht `ScrollView+VStack`) |
| Statistik-Header | Erste Section: Rheuma-Style (3 `statPill`-Spalten + optionaler Analyse-Button) |
| Action | Toolbar `.primaryAction` Button (kein FAB) |
| Titel | `.navigationTitle("...")` + `.navigationBarTitleDisplayMode(.large)` |

### Header-Muster (Rheuma-Style)

```swift
private var statistikSektion: some View {
    Section {
        VStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 12) {
                Label("30-Tage-Überblick", systemImage: "chart.bar.fill")
                    .font(.headline).foregroundStyle(.modulTint)
                Divider()
                HStack(spacing: 0) {
                    statPill("Wert1", label: "Label1", farbe: .someColor)
                    Divider().frame(height: 40)
                    statPill("Wert2", label: "Label2", farbe: .someColor)
                    Divider().frame(height: 40)
                    statPill("Wert3", label: "Label3", farbe: .someColor)
                }
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
            .shadow(color: Color.primary.opacity(0.06), radius: 10, x: 0, y: 2)

            // Nur wenn AnalyseView existiert:
            if !eintraege.isEmpty {
                Button { zeigeAnalyse = true } label: {
                    Label("Modul-Analyse öffnen", systemImage: "chart.bar.xaxis.ascending")
                        .font(.subheadline.bold()).foregroundStyle(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                        .background(Color.modulTint, in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }
    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
    .listRowBackground(Color.clear)
}

private func statPill(_ wert: String, label: String, farbe: Color) -> some View {
    VStack(spacing: 4) {
        Text(wert).font(.title2.bold()).foregroundStyle(farbe)
        Text(label).font(.caption2).foregroundStyle(.secondary).multilineTextAlignment(.center)
    }
    .frame(maxWidth: .infinity)
}
```

- Genau **3 statPills** mit `Divider().frame(height: 40)` zwischen ihnen
- Analyse-Button nur wenn ein `AnalyseView` für dieses Modul existiert
- Section bekommt `.listRowInsets` + `.listRowBackground(Color.clear)`

---

## Farben (Wohlbefinden)

```swift
// Stimmung (5 Stufen)
[.red, .orange, .yellow, .green, .teal]  // Stufe 1–5

// Stress (5 Stufen)
[.green, .mint, .yellow, .orange, .red]  // Stufe 1–5

// Fatigue
0 → .secondary  |  1–3 → .green  |  4–6 → .orange  |  7+ → .red

// Schlaf
.indigo
```

---

## InfoButton-Standard (bindend für alle AnalyseViews)

> **Jede Chart-Karte in einer AnalyseView hat einen `InfoButton` rechts im Karten-Header.**

```swift
// Karten-Header mit InfoButton (immer diese Struktur):
HStack {
    Label("Kartenname", systemImage: "symbol")
        .font(.headline).foregroundStyle(.modulTint)
    Spacer()
    InfoButton(
        titel: "Kartenname",
        text: "Was zeigt dieser Chart. Wie Werte interpretieren. Relevante Grenzwerte/Normbereiche."
    )
}
```

**Shared Component:** `Views/Components/InfoButton.swift` — nie duplizieren, nie inline reimplementieren.
- Icon: `info.circle`, Farbe: `.teal.opacity(0.8)` (neutral, modulunabhängig)
- Öffnet als Sheet (`.medium` Detent) mit Titel + erklärendem Text
- **Text-Pflicht:** Was der Chart misst, wie man ihn liest, relevante medizinische Grenzwerte/Empfehlungen

**Gilt für alle Sektionen in:** SchmerzAnalyseView, RheumaAnalyseView, MigraeneAnalyseView, HautAnalyseView, DiabetesAnalyseView, WohlbefindenAnalyseView, ZyklusAnalyseView, KorrelationsView

---

## AnalyseView Toolbar-Standard (bindend)

Jede AnalyseView, die als Sheet geöffnet wird, hat **exakt zwei Toolbar-Buttons** in fester Reihenfolge:

```swift
.toolbar {
    ToolbarItem(placement: .navigationBarLeading) {   // LINKS: immer Reihenfolge/Anpassen
        Button { zeigeAnpassen = true } label: {
            Label("Reihenfolge", systemImage: "slider.horizontal.3")
        }
    }
    ToolbarItem(placement: .confirmationAction) {      // RECHTS: immer Fertig
        Button("Fertig") { dismiss() }
    }
}
```

**Regel (bindend):**
- **Links** (`.navigationBarLeading`): Reihenfolge/Anpassen-Button — öffnet die AnpassenView als Sheet
- **Rechts** (`.confirmationAction`): „Fertig"-Button — dismissed die AnalyseView
- Niemals `.cancellationAction` für Fertig verwenden (landet links, ist falsch)
- Niemals `.primaryAction` für Anpassen verwenden (landet rechts, ist falsch)

**Jede AnalyseView benötigt ein Sektionen-System:**
```swift
// 1. Enum (global, vor dem View)
enum MeinAnalyseSektion: String, CaseIterable, Codable, Identifiable { ... }

// 2. Persistenz-Funktionen (global)
private let kSektionenKey = "meinModulAnalyseSektionen"
private func sektionenLaden() -> [MeinAnalyseSektion] { ... }
private func sektionenSpeichern(_ s: [MeinAnalyseSektion]) { ... }

// 3. State im View
@State private var sektionen: [MeinAnalyseSektion] = sektionenLaden()
@State private var zeigeAnpassen = false

// 4. ForEach statt fester Karten-Liste
VStack(spacing: 16) {
    ForEach(sektionen) { sektion in
        sektionView(sektion)
    }
}

// 5. onChange speichert
.onChange(of: sektionen) { _, new in sektionenSpeichern(new) }
```

**AnpassenView-Template** (als `private struct` am Ende jeder AnalyseView-Datei):
```swift
private struct MeinAnalyseAnpassenView: View {
    @Binding var sektionen: [MeinAnalyseSektion]
    @Environment(\.dismiss) private var dismiss
    @State private var editMode: EditMode = .active

    var body: some View {
        NavigationStack {
            List {
                ForEach(sektionen) { sektion in
                    HStack(spacing: 12) {
                        Image(systemName: sektion.symbol).foregroundStyle(.modulTint).frame(width: 24)
                        Text(sektion.rawValue).font(.subheadline)
                    }
                }
                .onMove { from, to in
                    sektionen.move(fromOffsets: from, toOffset: to)
                    sektionenSpeichern(sektionen)
                }
            }
            .environment(\.editMode, $editMode)
            .navigationTitle("Reihenfolge anpassen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Fertig") { dismiss() } }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
```

---

## Apple Intelligence Integration (Standard)

Jede AnalyseView und ArztbriefView enthält einen **KI-Einblick** via `FoundationModels` (iOS 26+).

### AnalyseViews

Jede AnalyseView hat eine `.kiInsicht`-Section in der Sektions-Enum + einen `kiPrompt: String`:

```swift
// 1. Enum-Case hinzufügen
case kiInsicht = "KI-Einblick"
// + symbol: return "sparkles"

// 2. Dispatcher-Case
case .kiInsicht: KIAnalyseKarte(prompt: kiPrompt, modulTint: .modulTint)

// 3. Prompt-Property (kompakte Datenzusammenfassung auf Deutsch)
private var kiPrompt: String {
    """
    Modul-Analyse (Zeitraum):
    - Kennzahl 1: Wert
    - Kennzahl 2: Wert
    Identifiziere Muster und gib 3–4 kurze Einblicke.
    """
}
```

Für AnalyseViews ohne Sektions-Enum (z.B. ZyklusAnalyseView): `KIAnalyseKarte(prompt: kiPrompt, modulTint: .pink)` am Ende der Cards-VStack.

### ArztbriefView

`KIArztbriefKarte(rohdaten: erzeugeBrief(), patientenName: ...)` in einer eigenen Section.
Generiert einen formellen Arztbrief auf Basis der Rohdaten. Kopieren-Button im Header.

### KIAnalyseKarte (Shared Component)

`Views/Components/KIAnalyseKarte.swift` — nie duplizieren.
- iOS 26+ only, ältere iOS: unsichtbar (kein Fallback nötig)
- `.id(prompt)`: View wird bei Zeitraum-Änderung neu erstellt → Nutzer muss neu generieren
- Systemsprompt: medizinischer Assistent, 3–4 Sätze Deutsch, keine Diagnosen
- Streaming via `session.streamResponse(to:)`, Reload-Button nach Generierung

---

## Zeitraum-Filter Standard (bindend)

Alle AnalyseViews und der SchmerzVerlauf verwenden **"7 T" (7 Tage) als Standard-Zeitraum**.

### Pflicht-Enum-Muster für jede AnalyseView:

```swift
enum Zeitraum: String, CaseIterable {
    case woche       = "7 T"   // MUSS als erster Case und Default stehen
    case monat       = "30 T"
    case dreiMonate  = "3 M"
    case sechsMonate = "6 M"
    case jahr        = "1 J"
    case alle        = "Alle"

    var tage: Int? {
        switch self {
        case .woche:       return 7
        case .monat:       return 30
        // ...
        case .alle:        return nil
        }
    }
}

@State private var zeitraum: Zeitraum = .woche  // immer .woche als Default
```

**Zusatz-Properties je View:**
- `verlaufMonate: Int` (Migräne, Rheuma, Diabetes): `.woche → 1`
- `wochen: Int` (Haut): `.woche → 2`

**Gilt für:** SchmerzAnalyseView, MigraeneAnalyseView, RheumaAnalyseView, DiabetesAnalyseView, HautAnalyseView, KorrelationsView

**SchmerzAnalyseView zusätzlich:** Adaptive Chart-Granularität:
- 7 T → täglich (`chartKomponente = .day`)
- 30 T → wöchentlich (`chartKomponente = .weekOfYear`)
- 3 M+ → monatlich (`chartKomponente = .month`)

---

## Wellness/Wohlbefinden-Modul

**Tint:** `.mint` — gilt für Kachel-Icon, Plus-Button, Energielevel-Karte, Analyse-Button, ProfilView-Toggle-Icon.
**Ausnahmen (semantisch):** Wasser-Tracker bleibt `.teal`, Stimmungs-Chart multi-color (rot/orange/gelb/mint/grün), Schlaf `.indigo`, Streak `.orange`.

**SwiftData-Modell:** `WellnessEintrag` — speichert Tages-Daten (wasserMl, koffeinTassen, alkoholGlaeser, mahlzeiten, stimmung, stress, energielevel, schlafStunden, notizen). Datum = `startOfDay`.

**Kachel:** `WellnessKachel` in `Views/Dashboard/WellnessKachel.swift` — optional, nicht in `basisKacheln`.
**ProfilView:** Toggle unter "Meine Module" (NICHT unter Erkrankungen).
**AnalyseView:** `WohlbefindenAnalyseView` in `Views/Wellness/`.

---

## Körperheatmap in AnalyseViews (bindend)

In allen AnalyseViews, die **Körperlokalisation oder Gelenkdaten** erfassen, wird `KoerperHeatmapView` als primäre Visualisierung verwendet — ergänzt durch ein Top-5-Balken-Chart darunter.

### Gilt für

| Modul | AnalyseView | Datenfeld | IntensitätenProperty | UIColor |
|---|---|---|---|---|
| Schmerz | SchmerzAnalyseView | `koerperstelle` | `koerperstellenIntensitaeten` | `.systemRed` |
| Rheuma | RheumaAnalyseView | `gelenkStatus` (via GelenkStatusCoder → `gelenkZuNodeName`) | `gelenkIntensitaeten` | `.systemTeal` |
| Haut | HautAnalyseView | `hautStellen` | `hautstellenIntensitaeten` | `.systemOrange` |

**Gilt nicht für:** MigraeneAnalyseView, DiabetesAnalyseView, ZyklusAnalyseView, WohlbefindenAnalyseView (keine Körperlokalisation).

### Implementierungsmuster (bindend für neue Module mit Körperdaten)

```swift
import SceneKit

struct MeinModulAnalyseView: View {
    @StateObject private var scanService = BodyScanService.shared

    // Intensitäten normalisiert 0.0–1.0
    private var meinIntensitaeten: [String: Double] {
        var counts: [String: Int] = [:]
        for e in gefiltert where !e.koerperstelle.isEmpty {
            for ort in e.koerperstelle.components(separatedBy: ", ").filter({ !$0.isEmpty }) {
                counts[ort, default: 0] += 1
            }
        }
        let maxCount = counts.values.max() ?? 1
        return counts.mapValues { Double($0) / Double(maxCount) }
    }

    // In der Körperstellen-Karte:
    private var koerperstellenKarte: some View {
        karte(titel: "Körperstellen", symbol: "figure.stand", farbe: .modulTint) {
            VStack(spacing: 12) {
                KoerperHeatmapView(
                    intensitaeten: meinIntensitaeten,
                    tintColor: .systemXxx,           // UIColor der Modulfarbe
                    proportionen: scanService.proportionen
                )
                .frame(height: 260)
                .clipShape(RoundedRectangle(cornerRadius: 12))

                // Gradient-Legende
                HStack(spacing: 0) {
                    Spacer()
                    Text("Selten").font(.caption2).foregroundStyle(.secondary)
                    LinearGradient(
                        colors: [Color.modulTint.opacity(0.18), Color.modulTint.opacity(0.50), Color.modulTint.opacity(0.80)],
                        startPoint: .leading, endPoint: .trailing
                    )
                    .frame(width: 80, height: 8).clipShape(Capsule()).padding(.horizontal, 6)
                    Text("Häufig").font(.caption2).foregroundStyle(.secondary)
                    Spacer()
                }

                Divider()

                // Top-5 Balken-Chart
                VStack(spacing: 8) {
                    ForEach(topOrte.prefix(5)) { ort in ... }
                }

                Text("Tippe auf Körperregion — wische zum Drehen")
                    .font(.caption2).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }
}
```

### Rheuma-spezifisch: Gelenk-ID → Node-Name Mapping

```swift
// gelenkZuNodeName: maps GelenkStatusCoder IDs → BodySceneBuilder node names
// Finger/Hand: R_MCP1-5, R_PIP1-5, R_HG → "Hand rechts" (analog links)
// Arm: R_E → "Ellbogen rechts", R_S → "Schulter rechts"
// Wirbelsäule: HWS → "Hals", BWS → "Brust", LWS → "Bauch"
// Beine: R_HUE, L_HUE → "Hüfte", R_K → "Knie rechts", R_OSG → "Knöchel rechts"
// Kiefer: R_KFG, L_KFG → "Kopf"
```

---

## SubRegionen – Namenskonvention (bindend)

> **Alle Sub-Regionen bilateral symmetrischer Körperstellen müssen den Seitenbezeichner ` links` / ` rechts` enthalten.**

### Warum

Die Highlight-Logik in `KoerperKarte3DView` prüft:

```swift
let isSelected = ausgewaehlt.contains(name)
    || (SubRegionen.map[name]?.contains { ausgewaehlt.contains($0) } ?? false)
```

Enthält `SubRegionen.map["Unterschenkel links"]` und `SubRegionen.map["Unterschenkel rechts"]` beide denselben String `"Wade"`, leuchten beim Antippen von **einer** Seite **beide** Nodes auf — weil der String in beiden Listen gefunden wird.

### Regel (bindend für alle Einträge in `SubRegionen.swift`)

| Körperstelle | ✗ Falsch | ✓ Richtig |
|---|---|---|
| Unterschenkel links/rechts | `"Wade"`, `"Schienbein"` | `"Wade links"`, `"Wade rechts"` |
| Hand links/rechts | `"Daumen"`, `"Zeigefinger"` | `"Daumen links"`, `"Daumen rechts"` |
| Fuss links/rechts | `"Großzehe"`, `"Ferse"` | `"Großzehe links"`, `"Ferse rechts"` |
| Schulter links/rechts | `"Schultergelenk"`, `"Achselhöhle"` | `"Schultergelenk links"`, `"Achselhöhle rechts"` |

**Einzige Ausnahme:** Sub-Regionen, die bereits in ihrem Namen die Seite tragen (z.B. `"Hals links"`, `"Flanke rechts"`) brauchen keinen weiteren Suffix.

### Checkliste beim Hinzufügen neuer Sub-Regionen

- [ ] Neue Sub-Region gehört zu einer bilateral symmetrischen Node? → Suffix ` links` / ` rechts` zwingend
- [ ] Beide Seiten der Map aktualisiert (map **und** hautMap falls vorhanden)?
- [ ] Node-Namen in `BodySceneBuilder.addParts()` geprüft — dort sind die exakten Schlüssel-Namen der Map?

---

## Neue Features / Module – Checkliste

Vor dem Merge eines neuen Moduls prüfen:
- [ ] Neue Modul-Farbe gewählt (noch nicht vergeben) und in Farbtabelle eingetragen
- [ ] **Modul-Tintfarbe durch alle Views gezogen** (Kachel / Hauptseite / AnalyseView / alle Sub-Views)
- [ ] Card-Hintergrund `secondarySystemGroupedBackground`
- [ ] Wohlbefinden-Schritt via `WohlbefindenStepView` (kein Inline-Code)
- [ ] Wizard-Navigationsmuster identisch zu bestehenden Wizards
- [ ] Keine doppelten `fatigueFarbe`, `stressLabel`, `stimmungFarben` etc.
- [ ] Modul-Hauptseite als `List` mit Stats-Header + `.navigationBarTitleDisplayMode(.large)`
- [ ] Dashboard-Kachel nach Template (3 Stats / Mini-Chart / Nav-Link / Plus-Button)
- [ ] ProfilView `erkrankungenSektion`: NavigationLink-Icon mit Modul-Tint
- [ ] ProfilView `moduleSektion`: Toggle-Icon mit Modul-Tint
- [ ] AnalyseView: `.kiInsicht`-Section + `kiPrompt` + `KIAnalyseKarte` eingebunden
- [ ] AnalyseView: Falls Körperlokalisationsdaten → `KoerperHeatmapView` eingebunden (siehe Körperheatmap-Standard)
- [ ] Grep nach alter/falscher Farbe im Modul-Ordner vor Merge (`grep -r "\.wrongColor" Views/MeinModul/`)
- [ ] Jede Delete-Operation folgt dem Löschen-Standard (siehe unten)

---

## Custom-Chip-Persistenz (bindend)

> **Jedes Freitext-Eingabefeld neben einem Chip-Grid muss den eingegebenen Wert beim Bestätigen ("+"-Button) persistent speichern, sodass er beim nächsten Öffnen als auswählbarer Chip erscheint.**

### Implementierungsmuster

```swift
// 1. Custom-Einträge laden (onAppear oder in laden())
@State private var customAusloeser: [String] = []
// in onAppear / laden():
customAusloeser = ChipSpeicher.laden(schluessel: "modulCustomAusloeser")

// 2. Basis-Optionen + Custom-Einträge zusammenführen
private let ausloeserBasis = ["Stress", "Schlafmangel", ...]
private var ausloeserOptionen: [String] {
    ausloeserBasis + customAusloeser.filter { !ausloeserBasis.contains($0) }
}

// 3. Beim "+" speichern
ChipSpeicher.hinzufuegen(term, schluessel: "modulCustomAusloeser")
customAusloeser = ChipSpeicher.laden(schluessel: "modulCustomAusloeser")
```

### chipKarte-Helper (Standard für neue Formulare)

```swift
chipKarte(
    titel: "Auslöser (mehrere möglich)",
    optionen: ausloeserOptionen,
    ausgewaehlt: $ausgewaehlteAusloeser,
    freitext: $ausloeserFreitext,
    platzhalter: "Eigener Auslöser…",
    beiCustomEintrag: { term in
        ChipSpeicher.hinzufuegen(term, schluessel: "modulCustomAusloeser")
        customAusloeser = ChipSpeicher.laden(schluessel: "modulCustomAusloeser")
    }
)
```

### Schlüssel-Konvention

`"<modul>Custom<Kategorie>"` — z.B. `"migraeneCustomAusloeser"`, `"hautCustomArt"`, `"migraeneCustomBegleit"`

Für Schmerz-übergreifende Felder (Schmerzart, Auslöser) die bestehenden `@AppStorage`-Keys verwenden:
`"customCharakter"`, `"customAusloeser"`, `"customBegleit"`, `"customMassnahmen"`

### ChipSpeicher (bestehend, nie duplizieren)

`Models/ChipSpeicher.swift` — max. 15 Einträge, Duplikate werden ignoriert, neueste oben.

### Abdeckung

| View | Freitext-Feld | Schlüssel | Status |
|---|---|---|---|
| CharakterStepView | Eigene Beschreibung | `customCharakter` (`@AppStorage`) | ✅ |
| CharakterAusloeserStepView | Eigene Beschreibung / Auslöser | `customCharakter` / `customAusloeser` | ✅ |
| BegleitMassnahmenStepView | Eigene Angaben / Massnahme | `customBegleit` / `customMassnahmen` | ✅ |
| AusloeserStepView | Eigener Auslöser | `chipEigeneAusloeser` | ✅ |
| BegleitschmerzStepView | Eigene Angaben | `chipEigeneBegleiterscheinungen` | ✅ |
| MassnahmenStepView | Weitere Massnahme | `chipEigeneMassnahmen` | ✅ |
| HautStepView | Weitere Art | `hautCustomArt` | ✅ |
| HautArtFotoStepView | Eigene Beschreibung | `hautCustomArt` | ✅ |
| MigraeneAnfallForm | Eigenes Symptom / Auslöser | `migraeneCustomBegleit` / `migraeneCustomAusloeser` | ✅ |

---

## Löschen-Standard (bindend)

> **Vor jedem `modelContext.delete(entry)` müssen alle ausstehenden Benachrichtigungen für diesen Eintrag abgebrochen werden.**

SwiftData's `modelContext.delete()` löscht den Eintrag dauerhaft aus der Datenbank — `@Query` und alle Analysen reflektieren die Löschung sofort. Es darf kein manuelles `.save()` nötig sein (autosave ist aktiv).

### Muster (bindend für alle Delete-Operationen)

```swift
// FALSCH — Notification bleibt als Geist hängen:
modelContext.delete(eintrag)

// RICHTIG — immer in dieser Reihenfolge:
NotificationManager.shared.loescheXxxErinnerungen(fuer: eintrag)
modelContext.delete(eintrag)
```

### Bekannte Notification-IDs pro Modell

| Modell | Notification-ID | Cleanup-Funktion |
|---|---|---|
| `Dauermedikation` | `"\(med.notifID)-0"` etc. | `loescheErinnerungen(fuer: med)` |
| `MigraeneEintrag` | `"migraene-wirkung-\(ts)"`, `"migraene-postdrom-\(ts)"` | `loescheMigraeneErinnerungen(fuer: datum)` |
| `BiologikaInjektion` | `"biologika-\(ts)"` | `loescheBiologikaErinnerung(injektion:)` |
| `EinnahmeLog` | `"wirkung-\(ts)"` | `loescheWirkungsAbfrage(fuer: log)` |
| `ZyklusEintrag` | `"zyklus-periode"` etc. | Wird via `onChange` automatisch neu geplant |

### Neues Modell mit Notifications — Checkliste

Wenn ein neues Modell eigene Notifications plant:
1. Notification-ID als Konstante oder Funktion in `NotificationManager` definieren
2. `loescheXxx(fuer:)` Funktion in `NotificationManager` anlegen
3. **Alle** Delete-Stellen des Modells im gesamten Codebase suchen und Cleanup eintragen
4. Modell und Cleanup-Funktion in die Tabelle oben eintragen

---

## Schmerztagebuch – Standard (bindend)

### PainEntryListView – Aufbau

`Views/Tagebuch/PainEntryListView.swift` — **nie komplett neu implementieren**, bestehende Struktur erweitern.

```
List
├── Section: Sparkline-Header (letzte 7 Tage)
├── Section: Filter-Chips (horizontal scrollbar)
└── ForEach(gruppiertNachDatum) → Section pro Tag
    ├── Header: "Heute" / "Gestern" / "Mo. 2. Jun."
    └── NavigationLink / Button pro Eintrag → Zeilen-View
```

**Sparkline-Header (7 Tage) — tappbar (bindend):**
- 7 Spalten, je: Wochentag-Kürzel (narrow) + farbige Dots pro Modul + Tageszahl
- Heute: `Color.secondary.opacity(0.08)` Hintergrund, fetter Font
- Ausgewählt: `Color.accentColor.opacity(0.18)` Hintergrund — filtert Liste auf diesen Tag
- Nochmal tippen → hebt Filter auf
- Dots: je 1 pro Modultyp (dedupliziert), max. 3, Modul-Tintfarbe — `uniqueModulFarben(aus:)` nie duplizieren
- Aktiver Tag-Filter erscheint als `× [Datum]`-Chip in den Filter-Chips (links, `.accentColor`)

**Filter-Chips:**
- Alle `ModulFilter`-Cases als Capsule-Chips horizontal scrollbar
- Aktiv: `filter.farbe` Hintergrund, weißer Text
- Inaktiv: `Color.secondary.opacity(0.12)`, primärer Text
- Tag-Filter-Chip (wenn Tag ausgewählt): ganz links, `.accentColor`, `× Datum`

**Zeilen-Views pro Typ (alle in `PainEntryListView.swift`, nicht `private`):**

> **`SchmerzZeile`, `MigraeneZeile`, `ModulKreis` sind `internal` (kein `private`) und werden von allen Modul-Hauptseiten genutzt. Niemals modul-eigene Zeilen-Structs mit gleicher Funktionalität erstellen.**

| Typ | View | Linkes Icon | Titel | Untertitel | Rechts |
|---|---|---|---|---|---|
| Schmerz | `SchmerzZeile` | `ModulKreis(farbe: .red, zahl: schmerzstaerke)` | koerperstelle | schmerzart · Uhrzeit · Wetter-Icon | — |
| Rheuma | `SchmerzZeile` | `ModulKreis(farbe: .teal, zahl: schmerzstaerke)` | "Rheuma" | Uhrzeit · Wetter-Icon | Schub-Badge, Morgensteifigkeit |
| Haut | `SchmerzZeile` | `ModulKreis(farbe: .orange, symbol: "bandage.fill")` | hautStellen | Uhrzeit | — |
| Migräne | `MigraeneZeile` | `ModulKreis(farbe: .purple, zahl: staerke)` | kopfschmerzTyp | charakter · Uhrzeit | Aura-Badge, Dauer |
| Zyklus | `ZyklusTagesbuchZeile` | `ModulKreis(farbe: .pink, symbol: ...)` | "Periode" / "Zyklus-Eintrag" | Uhrzeit · Blutungsfluss/Symptome (Uhrzeit nur wenn ≠ 00:00 — heutige Einträge speichern die Erfassungszeit, rückwirkende bleiben `startOfDay`) | — |
| Diabetes | `DiabetesTagesbuchZeile` | `ModulKreis(farbe: wertFarbe, symbol: ...)` | Blutzucker-Wert | Uhrzeit · Messzeitpunkt | Insulin |

**`ModulKreis`-Komponente** (`struct`, nicht `private`, in PainEntryListView):
```swift
ZStack {
    Circle().fill(farbe.opacity(0.18)).frame(width: 40, height: 40)
    // entweder Zahl (schmerzstaerke) oder SF Symbol
}
```

**Modul-Hauptseiten-Standard (bindend):**
- `SchmerzView`, `HautView` → `SchmerzZeile(eintrag:)` in `NavigationLink → PainEntryDetailView`
- `MigraeneView` → `MigraeneZeile(anfall:)` in `NavigationLink → MigraeneAnfallDetailView`
- Eigene Zeilen-Structs pro Modul sind **verboten** wenn `SchmerzZeile`/`MigraeneZeile` passen

**Routing beim Tippen:**
- Schmerz/Rheuma/Haut → `NavigationLink → PainEntryDetailView(eintrag:)`
- Migräne → `NavigationLink → MigraeneAnfallDetailView(anfall:)`
- Zyklus → Button → Sheet `ZyklusEintragSheet`
- Diabetes → Button → Sheet `BlutzuckerForm`

**Swipe-to-Delete:**
- Immer `.swipeActions(edge: .trailing)` mit `.destructive` Button
- Vor `modelContext.delete()` immer Notifications abbrechen (siehe Löschen-Standard)

---

### PainEntryDetailView – Aufbau

`Views/Tagebuch/PainEntryDetailView.swift` — modul-aware, zeigt **alle** Felder des jeweiligen Wizards.

**Modul-Erkennung:**
```swift
if eintrag.koerperstelle == "Rheuma" → .rheuma (.teal)
else if eintrag.istHautEintrag       → .haut   (.orange)
else                                 → .schmerz (.red)
```

**Karten-Reihenfolge (für alle Module):**
```
1. heroKarte          (immer, Modul-Tint)
2. modulSpezifisch    (switch modulTyp)
3. wohlbefindenKarte  (immer, .pink)
4. wetterKarte        (wenn wetterCode != nil)
5. notizenKarte       (wenn notizen nicht leer)
```

**Hero-Karte (bindend):**
- Modul-Badge: Icon + Label in Capsule (Modul-Tint)
- Titel: displayTitle (koerperstelle / hautStellen / "Rheuma & Gelenke")
- Datum + Uhrzeit
- `istSchub`-Badge: rote Capsule "Rheumaschub 🔥" (nur wenn true)
- Schmerzstärke-Kreis (64pt, Modul-Tint) + Balken — **bei Haut ausblenden** (schmerzstaerke = 0)

**Modul-spezifische Karten:**

*Schmerz:*
- Schmerz-Karte: Körperstelle, Schmerzart, Dauer
- Auslöser-Karte (wenn nicht leer)
- Begleiterscheinungen-Karte (wenn nicht leer)
- Massnahmen-Karte (wenn nicht leer)

*Rheuma:*
- Gelenkstatus-Karte (wenn gelenkStatus nicht leer): TJC/SJC/Gesamt statPills + Chip-Grid der betroffenen Gelenke farbkodiert (rot=schmerzhaft, blau=geschwollen, lila=beides) + Legende
- Symptome-Karte (wenn morgensteifigkeit > 0 oder fatigue > 0): Morgensteifigkeit (orange wenn > 30 Min), Fatigue mit Batterie-Icon

*Haut:*
- Hautbild-Karte: betroffene Stellen als Chips (orange), Hautart als Chips, Verlauf-Badge (↑grün/=orange/↓rot), Foto als echtes Bild via `FotoManager.laden(dateiname:)`

**Wohlbefinden-Karte (alle Module, .pink):**

| Feld | Bedingung | Darstellung |
|---|---|---|
| Stimmung | stimmung > 0 | Text-Label + Herz-Icon, farbkodiert 1–5 |
| Stresslevel | stressLevel > 0 | Text-Label + 5 farbige Balken |
| Schlaf | schlafStunden > 0 | "X.X Stunden" |
| Fatigue | fatigue > 0 **und** modulTyp == .schmerz | Batterie-Icon + "X/10" |
| Morgensteifigkeit | morgensteifigkeit > 0 **und** modulTyp == .schmerz | Sunrise-Icon + "X Min" |

> Fatigue und Morgensteifigkeit für Rheuma-Einträge erscheinen **nicht** in der Wohlbefinden-Karte — sie werden in der separaten Symptome-Karte gezeigt.

**Bearbeiten-Button (Toolbar .primaryAction):**
```swift
if koerperstelle == "Rheuma" → RheumaSchnellForm(eintrag:)
else if istHautEintrag       → HautForm(eintrag:)
else                         → SchmerzForm(eintrag:)
```

**Karten-Stil (`.karte()` Extension):**
```swift
.padding()
.background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
.shadow(color: Color.primary.opacity(0.06), radius: 10, x: 0, y: 2)
```

---

### MigraeneAnfallDetailView – Pflichtfelder

`Views/Migraene/MigraeneAnfallDetailView.swift`

Karten-Reihenfolge:
```
heroKarte (staerke, kopfschmerzTyp, hatAura-Badge)
anfallKarte (seite, dauer, endZeit)
prodromsymptomeKarte (wenn nicht leer)
charakterKarte (hatAura + charakter)
begleitsymptomeKarte (wenn nicht leer)
auslöserKarte (wenn nicht leer)
akutmedikamentKarte (wenn nicht leer)
postdromKarte (immer — zeigt "Noch nicht erfasst" + Erfassen-Button wenn leer)
wohlbefindenKarte (stimmung, stressLevel, schlafStunden, fatigue — wenn mind. 1 Wert > 0)
wetterKarte (wenn wetterCode != nil)
zyklusKarte (wenn zyklusPhase nicht leer)
notizenKarte (wenn notizen nicht leer)
```

Wohlbefinden-Karte: identisch zu PainEntryDetailView, Tint `.pink`.

---

### Vollständigkeits-Checkliste für Detail-Views (bindend)

> Jedes Feld, das ein Wizard erfasst, **muss** in der zugehörigen DetailView sichtbar sein.

Vor dem Merge einer neuen DetailView oder Wizard-Änderung:
- [ ] Alle `@State`-Felder im Wizard gegen die DetailView abgeglichen
- [ ] Jedes Feld, das in `speichern()` geschrieben wird, hat eine entsprechende Anzeige
- [ ] Felder mit Wert 0 / leer werden korrekt ausgeblendet (keine leeren Karten)
- [ ] Modul-Tintfarbe korrekt (siehe Farbtabelle)
- [ ] Bearbeiten-Button routet zum richtigen Wizard
