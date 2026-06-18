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
| Statistik-Header | Erste Section: gerundete Chips / `scoreChip`-Pattern |
| Action | Toolbar `.primaryAction` Button (kein FAB) |
| Titel | `.navigationTitle("...")` + `.navigationBarTitleDisplayMode(.large)` |

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
