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
| Wellness | Multi-Color (kein einzelner Tint) | — |

---

## Card / Section Style

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
- [ ] Modul-Tint aus obiger Tabelle verwendet
- [ ] Card-Hintergrund `secondarySystemGroupedBackground`
- [ ] Wohlbefinden-Schritt via `WohlbefindenStepView` (kein Inline-Code)
- [ ] Wizard-Navigationsmuster identisch zu bestehenden Wizards
- [ ] Keine doppelten `fatigueFarbe`, `stressLabel`, `stimmungFarben` etc.
- [ ] Modul-Hauptseite als `List` mit Stats-Header
