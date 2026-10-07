import Foundation

/// Guardrails für den Apple-Intelligence-Einblick im Zyklus-Modul (reine Logik, testbar).
/// - System-Prompt: Mustererkennung ja, Diagnosen / Verhütungsaussagen nein.
/// - Datenlage: sagt dem Modell, wie belastbar die Daten sind (verhindert „Muster“ aus 1–2 Zyklen).
/// - Prüfung: fängt unzulässige Aussagen in der fertigen Antwort ab.
nonisolated enum ZyklusKISicherheit {

    static let systemPrompt = """
    Du bist ein Analyse-Assistent für ein Zyklus- und Schmerztagebuch. Du beschreibst ausschließlich Muster in den \
    gelieferten Daten (Zusammenhänge zwischen Zyklusphase und Symptomen) und formulierst sie vorsichtig \
    („tendenziell“, „in deinen Daten“).
    Strikte Regeln:
    1. Keine Diagnosen und keine Krankheitsnamen als Befund (z. B. PCOS, Endometriose, Schilddrüsenerkrankung). \
    Bei auffälligen Mustern nur empfehlen, sie ärztlich abklären zu lassen.
    2. Keine Aussagen zu Verhütung, Fruchtbarkeit oder Schwangerschaft („sicher“, „unfruchtbar“, „kein Risiko“). \
    Prognosen sind Schätzungen.
    3. Behaupte kein Muster, wenn die Datenlage als „dünn“ gekennzeichnet ist; sage dann, dass noch zu wenige \
    Daten vorliegen. Nenne nie Zahlen, die nicht im Prompt stehen.
    4. Unterscheide Beleg und Schätzung: Ein „geschätzter“ Eisprung ist keine Messung.
    5. Keine Medikamentenempfehlungen oder Dosisänderungen.
    Antworte auf Deutsch in 3–4 kurzen Sätzen.
    """

    /// Eine Zeile für den Prompt, die die Belastbarkeit der Daten beschreibt.
    static func datenlage(gueltigeZyklen: Int, datenQualitaet: String, regelmaessig: Bool, eisprungBestaetigt: Bool) -> String {
        let dünn = gueltigeZyklen < 3
        return "- Datenlage: \(dünn ? "DÜNN (weniger als 3 vollständige Zyklen – keine Muster behaupten)" : "ausreichend"); "
            + "Datenqualität: \(datenQualitaet); Zyklus \(regelmaessig ? "regelmäßig" : "unregelmäßig oder unklar"); "
            + "Eisprung \(eisprungBestaetigt ? "durch Messung bestätigt" : "nur geschätzt")"
    }

    /// Begriffe, die in einer Antwort nicht vorkommen dürfen (Diagnosen, Sicherheitsversprechen).
    private static let verboten: [String] = [
        "pcos", "polyzyst", "endometriose", "myom", "schilddrüsenunter", "schilddrüsenüber",
        "unfruchtbar", "infertil", "sicher keine schwangerschaft", "kein schwangerschaftsrisiko",
        "kein risiko", "verhütung ist nicht nötig", "du bist schwanger", "du hast eine",
        "diagnose lautet", "leidest an", "anovulation liegt", "dosis erhöhen", "dosis reduzieren"
    ]

    static let ersatztext = "Aus deinen Daten lässt sich dazu keine verlässliche Aussage ableiten. "
        + "Bei Auffälligkeiten besprich die Verläufe bitte mit deiner Ärztin oder deinem Arzt."

    static let hinweis = "\n\nMuster aus deinen Einträgen – keine Diagnose, keine Verhütungsaussage."

    /// Entfernt unzulässige Antworten und hängt den Hinweis an.
    static func pruefe(_ antwort: String) -> String {
        let text = antwort.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return antwort }
        let klein = text.lowercased()
        if verboten.contains(where: { klein.contains($0) }) { return ersatztext + hinweis }
        return text + hinweis
    }
}
