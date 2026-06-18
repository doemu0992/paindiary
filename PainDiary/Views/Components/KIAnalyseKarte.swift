import SwiftUI

/// Reusable Apple Intelligence analysis card.
/// Wrap with `.id(prompt)` in callers — SwiftUI resets state when prompt changes.
struct KIAnalyseKarte: View {
    let prompt: String
    let modulTint: Color

    var body: some View {
        if #available(iOS 26, *) {
            KIInsightContent(prompt: prompt, modulTint: modulTint)
                .id(prompt)
        }
        // Older iOS: card hidden (no fallback needed — feature simply unavailable)
    }
}

@available(iOS 26, *)
private struct KIInsightContent: View {
    let prompt: String
    let modulTint: Color

    @State private var session: LanguageModelSession? = nil
    @State private var antwort = ""
    @State private var isGenerating = false
    @State private var hatGeneriert = false
    @State private var fehler: String? = nil

    private let systemPrompt =
        "Du bist ein medizinischer Analyse-Assistent in PainDiary. " +
        "Analysiere die angegebenen Gesundheitsdaten prägnant auf Deutsch (3–4 Sätze). " +
        "Stelle keine Diagnosen. Identifiziere nur beobachtbare Muster in den Daten " +
        "und formuliere einen hilfreichen Hinweis an den Nutzer."

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Label("KI-Einblick", systemImage: "sparkles")
                    .font(.headline).foregroundStyle(modulTint)
                Spacer()
                if isGenerating {
                    ProgressView().scaleEffect(0.75)
                } else if hatGeneriert {
                    Button { Task { await generieren() } } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.caption.bold())
                            .foregroundStyle(modulTint)
                    }
                    .buttonStyle(.plain)
                }
            }
            Divider()

            if hatGeneriert || isGenerating {
                Text(antwort.isEmpty ? " " : antwort)
                    .font(.subheadline)
                    .lineSpacing(4)
                    .foregroundStyle(.primary)
                    .animation(.easeIn, value: antwort)
            } else if let f = fehler {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                    Text(f).font(.caption).foregroundStyle(.secondary)
                }
                Button("Erneut versuchen") { Task { await generieren() } }
                    .font(.caption.bold()).foregroundStyle(modulTint)
            } else {
                Text("Apple Intelligence analysiert deine Daten und zeigt dir persönliche Einblicke.")
                    .font(.caption).foregroundStyle(.secondary)
                    .padding(.bottom, 4)
                Button { Task { await generieren() } } label: {
                    Label("Analyse starten", systemImage: "sparkles")
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(modulTint, in: RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                .disabled(isGenerating)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.primary.opacity(0.06), radius: 10, x: 0, y: 2)
    }

    private func generieren() async {
        if session == nil {
            session = LanguageModelSession(instructions: systemPrompt)
        }
        guard let session else { return }
        isGenerating = true
        hatGeneriert = true
        antwort = ""
        fehler = nil
        do {
            let stream = session.streamResponse(to: prompt)
            for try await partial in stream {
                antwort = partial.content
            }
        } catch {
            fehler = "Apple Intelligence nicht verfügbar. Stelle sicher, dass es in den Einstellungen aktiviert ist."
            hatGeneriert = false
        }
        isGenerating = false
    }
}
