# Changelog

## [2.0 Build 33] – 2026-07-03

### Neu
- **Ovulationstest steuert Eisprung-Vorhersage**: Ein positiver LH-Test setzt den Eisprung auf den Folgetag des ersten positiven Tests (Eisprung erfolgt ca. 24–36 h nach LH-Anstieg). Der Test hat Vorrang vor Zervixschleim und Kalender-Berechnung — im aktuellen Zyklus, in abgeschlossenen Zyklen und beim Lernen des persönlichen Ovulations-Musters. Mehrere positive Tage zählen als ein LH-Anstieg (erster Tag zählt).
- **Erfassungszeit fliesst in Eisprung-Berechnung ein**: Abendtests (ab 18 Uhr) verschieben den erwarteten Eisprung auf den übernächsten Tag (24–36 h ab Abend landet dort). Die Ovulationstest-Karte in der Zyklus-Analyse zeigt jetzt die Erfassungszeit unter dem Datum.
- **Negative Tests verschieben die Eisprung-Vorhersage**: Fällt der Ovulationstest am oder nach dem Vortag des erwarteten Eisprungs negativ aus (und kein positiver Test liegt vor), verschiebt sich die Vorhersage auf den Tag nach dem letzten negativen Test. Frühe negative Tests im Zyklus ändern nichts; verschoben wird nur nach hinten, nie abgesagt.
- **Mehrere Ovulationstests pro Tag**: Im Zyklus-Formular lassen sich jetzt mehrere Tests mit Uhrzeit erfassen (z.B. morgens und abends), um den kurzen LH-Anstieg nicht zu verpassen. Format abwärtskompatibel im bestehenden Feld (`ergebnis@HH:mm|…`). Analyse-Karte, Detail-View und PDF-Export zeigen alle Tests einzeln.
- **Basaltemperatur fliesst in die Eisprung-Erkennung ein**: 3-über-6-Regel (Sensiplan) — drei aufeinanderfolgende Messwerte über dem Maximum der sechs vorherigen (dritter ≥ 0,2 °C darüber) bestätigen den Eisprung retrospektiv am Tag vor dem ersten erhöhten Wert. Priorität: LH-Test > Temperaturanstieg > Schleim-Peak > Kalender. Wirkt auch rückwirkend auf bereits erfasste Daten.
- **Periodenvorhersage folgt dem Eisprung**: Die Lutealphase ist konstant (~12–16 Tage, aus den eigenen Daten gelernt) — verschiebt sich der Eisprung (negative Tests, später Schleim-Peak), verschiebt sich die vorhergesagte Periode mit. Bei bestätigtem Eisprung (LH/BBT) wird die Periode exakt datiert.
- **Zyklusstart-Erkennung robuster**: Blutungslücken bis 5 Tage (vergessene Erfassung) gehören zur selben Periode; Blutungen früher als 21 Tage nach Zyklusbeginn gelten als Zwischen-/Ovulationsblutung, nicht als neuer Zyklus. Periodendauer toleriert 1 Tag Erfassungslücke (max. 10 Tage).
- **Plausibilitätsgrenzen**: Nur Zykluslängen von 21–60 Tagen fliessen in Statistik, adaptive Vorhersage und Muster-Lernen ein — Tracking-Pausen verzerren die Vorhersage nicht mehr. Implausible Zyklen ohne gemessenes Signal (LH/BBT) werden im Kalender nicht mit Eisprung markiert.
- **Selbstkalibrierung des gelernten Eisprung-Musters**: Der gelernte Ovulations-Offset wird gegen die eigene Zykluslänge geprüft — die Lutealphase muss 10–16 Tage betragen. Ein durch spärlich erfassten Zervixschleim zu früh gelernter Eisprung (z.B. "Tag 10" bei 27-Tage-Zyklen) wird automatisch korrigiert. Der Tracker rekalibriert sich bei jeder Datenänderung neu.
- **Anzeige-Fix**: "Eisprung (gelernt)" in der Adaptiven Vorhersage zeigte den Zyklustag um 1 zu niedrig an (Offset statt Zyklustag).
- **Bestätigter Eisprung fliesst sofort ins Lernen ein**: Ein per LH-Test oder Temperaturanstieg belegter Eisprung im laufenden Zyklus wird unmittelbar ins Muster-Lernen aufgenommen — die Eisprung- und Fenster-Vorhersage des Folgezyklus profitiert sofort, nicht erst nach Zyklusende.
- **Bestätigter Eisprung passt den kompletten Zyklus an**: Die projizierte Länge des laufenden Zyklus (bestätigter Eisprung + Lutealphase) geht sofort als neuester, am stärksten gewichteter Datenpunkt in die adaptive Zykluslänge ein. Übernächste Periode, künftige fruchtbare Fenster, Phasenberechnung und die "Adaptive Vorhersage"-Karte rechnen unmittelbar mit dem angepassten Zyklus.

---

## [2.0 Build 32] – 2026-07-03

### Fehlerbehebungen
- **Zyklus – Erfassungszeit**: Heutige Zyklus-Einträge speichern jetzt die tatsächliche Uhrzeit der Erfassung (statt sinnlosem 00:00). Wird mittags eine Blutung nachgetragen, zeigt der Eintrag die Mittagszeit. Rückwirkende Einträge zeigen keine Uhrzeit.

---

## [2.0 Build 31] – 2026-07-03

### Neu
- **Zyklus-Detail-View**: Zyklus-Einträge öffnen jetzt eine Übersichtsseite (wie Schmerz/Rheuma/Haut) mit Hero-Karte, Periode, Symptome, Weitere Daten und Notizen. Bearbeiten-Button in der Toolbar.
- **Schlaf-Modul**: Neues Modul mit Schmerz-Schlaf-Korrelation, Schlafgeräusch-Aufnahmen und Folgetag-Analyse.
- **App Group**: Shared Container für spätere Verknüpfung mit SleepBuddy eingerichtet.

### Verbesserungen
- **Tagebuch – Kalenderleiste**: Tage sind jetzt tappbar und filtern die Einträge auf den gewählten Tag.
- **Einheitlicher Zeilen-Stil**: Alle Module (Schmerz, Rheuma, Haut, Migräne, Zyklus, Diabetes) verwenden jetzt denselben Zeilen-Stil wie das Tagebuch, mit farbigen Modulkreisen.
- **Datumsgruppierung**: Einträge in allen Modulen (Schmerz, Rheuma, Migräne, Haut) sind nach Datum gruppiert mit "Heute / Gestern / Mo. 2. Jun." als Sektionsüberschriften.
- **Rheuma-Menüreihenfolge**: Scores & Verlauf und Medikamente & Therapie erscheinen jetzt vor den Einträgen, damit die Menüs immer erreichbar sind.
- **Gesamtanalyse – KI-Einblick**: KI-Prompt berücksichtigt jetzt medizinische Diagnosen, aktive Module, Dauermedikamente, Biologika, Kortison und Laborwerte aus dem Profil.
- **Gesamtanalyse – Gender-Filter**: Zyklus-Inhalte werden bei männlichen Patienten ausgeblendet.
- **Postdrom-Erfassung**: Chip-Design an den Migräne-Standard angepasst (lila, LazyVGrid).

### Fehlerbehebungen
- Zyklus-Einträge im Tagebuch öffneten direkt das Bearbeitungsformular statt einer Übersicht — behoben.
- RheumaView hatte keine Einträgsektion — hinzugefügt.

---

## [2.0 Build 30] – 2026-06-XX

### Neu
- KI-Analyse (Apple Intelligence) in allen AnalyseViews
- GesamtAnalyseView mit modulübergreifender Auswertung
- Zyklus-Modul mit Kalender, Fruchtbarkeitsvorhersage und Analyse
- Diabetes-Modul mit Blutzucker-Verlauf und HbA1c-Tracking
- Wellness-Modul mit Wasser-, Koffein- und Stimmungs-Tracking
- Körperheatmap (3D SceneKit) in Schmerz-, Rheuma- und Haut-Analyse
- Biologika-Modul mit Injektions-Tracking und Erinnerungen
- FACIT-Erschöpfungsfragebogen für Rheuma
- HAQ & DAS28 Scoring
- Remissionsphasen-Tracking
- Kortison-Tagebuch
- Arztbrief-Generator
