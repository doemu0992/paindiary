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
- [ ] Grep nach alter/falscher Farbe im Modul-Ordner vor Merge (`grep -r "\.wrongColor" Views/MeinModul/`)
