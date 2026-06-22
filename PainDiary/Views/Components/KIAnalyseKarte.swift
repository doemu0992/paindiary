import SwiftUI
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Reusable Apple Intelligence analysis card.
/// Requires iOS 26+ / Xcode 26 SDK. Hidden on older OS versions.
/// Pass `.id(prompt)` at call site — SwiftUI resets state when prompt changes.
struct KIAnalyseKarte: View {
    let prompt: String
    let modulTint: Color

    var body: some View {
#if canImport(FoundationModels)
        if #available(iOS 26, *) {
            KIInsightContent(prompt: prompt, modulTint: modulTint)
                .id(prompt)
        }
#endif
    }
}

#if canImport(FoundationModels)
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
        "Der Nutzer hat möglicherweise medizinische Diagnosen und aktive Tracking-Module angegeben — diese sind im Prompt als MEDIZINISCHE DIAGNOSEN und AKTIVE TRACKING-MODULE aufgeführt. " +
        "Beziehe diese Erkrankungen explizit in deine Analyse ein: Erkläre beobachtbare Muster im Kontext der genannten Diagnosen. " +
        "Beispiel: Wenn Rheuma und erhöhte Morgensteifigkeit vorliegen, benenne diesen Zusammenhang konkret. " +
        "Antworte in 3–4 prägnanten Sätzen auf Deutsch. Stelle keine eigenen Diagnosen. " +
        "Sei konkret und patientenbezogen — vermeide allgemeine Aussagen ohne Bezug zu den vorliegenden Daten."

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
                Group {
                    if let attributed = try? AttributedString(
                        markdown: antwort.isEmpty ? " " : antwort,
                        options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
                    ) {
                        Text(attributed)
                    } else {
                        Text(antwort.isEmpty ? " " : antwort)
                    }
                }
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
#endif
