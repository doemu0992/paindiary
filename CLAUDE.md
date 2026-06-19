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
| Wellness | Multi-Color (kein einzelner Tint) | — |

**Neues Modul:** einfach nächste freie Farbe aus SwiftUI-Palette wählen (z.B. `.indigo`, `.mint`, `.cyan`, `.pink`). Farbe in diese Tabelle eintragen. Niemals eine bereits vergebene Farbe wiederverwenden.

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
| Schlaf | Slider 0–12 h, Schritt 0.5, Tint `.indigo` |
| Stimmung | 5 Herz-Buttons, Farben: red/orange/yellow/green/teal |
| Stress | 5 farbige Balken-Buttons, Farben: green/mint/yellow/orange/red |
| Fatigue | Slider 0–10, Schritt 1, dynamischer Tint |

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
- [ ] Grep nach alter/falscher Farbe im Modul-Ordner vor Merge (`grep -r "\.wrongColor" Views/MeinModul/`)
