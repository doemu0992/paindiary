# Changelog

## [2.0 Build 33] – 2026-07-03

### Neu
- **Ovulationstest steuert Eisprung-Vorhersage**: Ein positiver LH-Test setzt den Eisprung auf den Folgetag des ersten positiven Tests (Eisprung erfolgt ca. 24–36 h nach LH-Anstieg). Der Test hat Vorrang vor Zervixschleim und Kalender-Berechnung — im aktuellen Zyklus, in abgeschlossenen Zyklen und beim Lernen des persönlichen Ovulations-Musters. Mehrere positive Tage zählen als ein LH-Anstieg (erster Tag zählt).
- **Erfassungszeit fliesst in Eisprung-Berechnung ein**: Abendtests (ab 18 Uhr) verschieben den erwarteten Eisprung auf den übernächsten Tag (24–36 h ab Abend landet dort). Die Ovulationstest-Karte in der Zyklus-Analyse zeigt jetzt die Erfassungszeit unter dem Datum.

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
