import SwiftUI
import SwiftData
import CloudKit

// MARK: - Besitzerseite: Teilen

/// Einladung zum Teilen des Zyklus (Einwilligung, Einladen, Beenden).
struct ZyklusPartnerTeilenSheet: View {
    let eintraege: [ZyklusEintrag]
    @Environment(\.dismiss) private var dismiss
    @State private var service = ZyklusPartnerService.shared
    @State private var freigabe: CKShare?
    @State private var zeigeEinladung = false
    @State private var bereitet = false
    @State private var fehler: String?
    @State private var bestaetigeBeenden = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(spacing: 8) {
                        Image(systemName: "person.2.fill").font(.system(size: 34)).foregroundStyle(.pink)
                        Text("Zyklus mit Partner:in teilen").font(.title3.bold())
                    }
                    .frame(maxWidth: .infinity)

                    VStack(alignment: .leading, spacing: 8) {
                        punkt("eye", "Deine Partnerin oder dein Partner sieht alle Zyklusdaten: Periode, Symptome, Tests, Temperatur, Notizen und Prognosen.")
                        punkt("lock.shield", "Nur Ansehen – nichts kann geändert werden. Die Daten laufen über iCloud, nicht über einen fremden Server.")
                        punkt("arrow.triangle.2.circlepath", "Jede Änderung wird automatisch aktualisiert.")
                        punkt("hand.raised", "Du kannst das Teilen jederzeit beenden. Dann hat die Person sofort keinen Zugriff mehr.")
                    }
                    .padding(16)
                    .glassCard(padding: 0)

                    if let fehler { Text(fehler).font(.caption).foregroundStyle(.red) }

                    if service.teiltAktiv {
                        Button { Task { await einladungOeffnen() } } label: {
                            Label("Teilnehmer verwalten / einladen", systemImage: "person.badge.plus")
                                .frame(maxWidth: .infinity).padding(.vertical, 14)
                                .background(Color.pink, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .foregroundStyle(.white).font(.subheadline.bold())
                        }.buttonStyle(.plain).disabled(bereitet)

                        Button(role: .destructive) { bestaetigeBeenden = true } label: {
                            Text("Teilen beenden").font(.subheadline.bold())
                                .frame(maxWidth: .infinity).padding(.vertical, 12)
                        }
                    } else {
                        Button { Task { await einladungOeffnen() } } label: {
                            Label("Einladen", systemImage: "person.badge.plus")
                                .frame(maxWidth: .infinity).padding(.vertical, 14)
                                .background(Color.pink, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .foregroundStyle(.white).font(.subheadline.bold())
                        }.buttonStyle(.plain).disabled(bereitet)
                        Text("Im nächsten Schritt wählst du die Person aus und stellst „Nur ansehen“ ein.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                .padding(16)
            }
            .auroraScreen(.zyklus)
            .navigationTitle("Partner-Sharing")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fertig") { dismiss() } } }
            .sheet(isPresented: $zeigeEinladung) {
                if let freigabe {
                    CloudSharingView(freigabe: freigabe, container: service.container)
                        .ignoresSafeArea()
                }
            }
            .confirmationDialog("Teilen beenden?", isPresented: $bestaetigeBeenden, titleVisibility: .visible) {
                Button("Teilen beenden", role: .destructive) { Task { await service.teilenBeenden() } }
            } message: {
                Text("Die Person verliert sofort den Zugriff auf deinen Zyklus.")
            }
        }
        .environment(\.locale, ZyklusLocale.de)
    }

    private func punkt(_ symbol: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol).foregroundStyle(.pink).frame(width: 22)
            Text(text).font(.footnote).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
    }

    private func einladungOeffnen() async {
        bereitet = true
        fehler = nil
        defer { bereitet = false }
        do {
            freigabe = try await service.erstelleFreigabe(eintraege: eintraege)
            zeigeEinladung = true
        } catch {
            fehler = "Freigabe fehlgeschlagen: \(error.localizedDescription). Ist iCloud aktiv und angemeldet?"
        }
    }
}

/// Systemdialog zum Einladen/Verwalten (nur „Nur ansehen“ und „Nur eingeladene Personen“ erlaubt).
private struct CloudSharingView: UIViewControllerRepresentable {
    let freigabe: CKShare
    let container: CKContainer

    func makeCoordinator() -> Koordinator { Koordinator() }

    func makeUIViewController(context: Context) -> UICloudSharingController {
        let c = UICloudSharingController(share: freigabe, container: container)
        c.availablePermissions = [.allowReadOnly, .allowPrivate]
        c.delegate = context.coordinator
        return c
    }

    func updateUIViewController(_ uiViewController: UICloudSharingController, context: Context) {}

    final class Koordinator: NSObject, UICloudSharingControllerDelegate {
        func itemTitle(for csc: UICloudSharingController) -> String? { "Mein Zyklus" }

        func cloudSharingController(_ csc: UICloudSharingController, failedToSaveShareWithError error: Error) {
            Task { @MainActor in ZyklusPartnerService.shared.meldung = "Teilen fehlgeschlagen: \(error.localizedDescription)" }
        }

        func cloudSharingControllerDidStopSharing(_ csc: UICloudSharingController) {
            Task { @MainActor in ZyklusPartnerService.shared.teiltAktiv = false }
        }
    }
}

// MARK: - Partnerseite: Ansehen

private struct PartnerTagAuswahl: Identifiable {
    let id = UUID()
    let datum: Date
}

/// Schreibgeschützte Ansicht des geteilten Zyklus. Nutzt dieselben Anzeige-Bausteine wie `ZyklusView`
/// (`ZyklusAnzeigeKarten.swift`) – ohne Erfassen-/Bearbeiten-Aktionen und ohne ModelContext.
struct ZyklusPartnerView: View {
    @State private var service = ZyklusPartnerService.shared
    @State private var ringAuswahl: Int? = nil
    @State private var monat = Date()
    @State private var ansicht = 0
    @State private var tagAuswahl: PartnerTagAuswahl? = nil
    @State private var zeigeAnalyse = false

    private var kal: Calendar { Calendar.current }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let p = service.empfangen {
                    inhalt(p)
                } else if service.laedt {
                    ProgressView("Lade geteilten Zyklus …").padding(.top, 40)
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "person.2").font(.largeTitle).foregroundStyle(.pink)
                        Text("Noch nichts geteilt").font(.headline)
                        Text("Wenn dich jemand zu seinem Zyklus einlädt, öffne die Einladung (Nachricht oder Link) – danach erscheint er hier.")
                            .font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    }
                    .padding(24).frame(maxWidth: .infinity).glassCard(padding: 0)
                }
            }
            .padding(.horizontal, 16).padding(.bottom, 24)
        }
        .auroraScreen(.zyklus)
        .environment(\.locale, ZyklusLocale.de)
        .navigationTitle("Geteilter Zyklus")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { Task { await service.laden() } } label: { Image(systemName: "arrow.clockwise") }
            }
        }
        .task { await service.laden() }
        .refreshable { await service.laden() }
        .sheet(item: $tagAuswahl) { auswahl in tagesSheet(auswahl.datum) }
        .sheet(isPresented: $zeigeAnalyse) {
            if let p = service.empfangen {
                ZyklusAnalyseView(partnerEintraege: p.eintraege.map { $0.modell() })
            }
        }
        .alert("Partner-Sharing", isPresented: Binding(get: { service.meldung != nil },
                                                      set: { if !$0 { service.meldung = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(service.meldung ?? "") }
    }

    // Transiente Modellobjekte (werden nicht in einen ModelContext eingefügt)
    private func daten(_ p: ZyklusPartnerPayload) -> (analyse: ZyklusAnalyse, proTag: [Date: ZyklusTagesSicht]) {
        let eintraege = p.eintraege.map { $0.modell() }
        let analyse = ZyklusRechner.analyse(eintraege: eintraege)
        let proTag = Dictionary(grouping: eintraege) { $0.tag.beginn(in: kal.timeZone) }
            .mapValues { ZyklusTagesSicht($0) }
        return (analyse, proTag)
    }

    @ViewBuilder
    private func inhalt(_ p: ZyklusPartnerPayload) -> some View {
        let d = daten(p)
        let analyse = d.analyse
        let proTag = d.proTag

        Text("Nur ansehen · Stand \(p.stand.formatted(.dateTime.day().month().hour().minute().locale(ZyklusLocale.de)))")
            .font(.caption).foregroundStyle(.secondary)

        Picker("Ansicht", selection: $ansicht) {
            Text("Heute").tag(0); Text("Monat").tag(1); Text("Verlauf").tag(2)
        }
        .pickerStyle(.segmented)

        if analyse.zyklusStarts.isEmpty {
            Text("Noch keine Zyklusdaten.").font(.footnote).foregroundStyle(.secondary)
        } else {
            switch ansicht {
            case 0:  heute(p, analyse, proTag)
            case 1:  monatsAnsicht(p, analyse, proTag)
            default:
                ZyklusVerlaufView(analyse: analyse, proTag: proTag)
                analyseButton
            }
        }

        Text("Prognosen sind statistische Schätzungen. Sie ersetzen weder Verhütung noch ärztliche Beratung.")
            .font(.caption2).foregroundStyle(.secondary).multilineTextAlignment(.center)
            .padding(.horizontal, 8)
    }

    // MARK: Heute

    @ViewBuilder
    private func heute(_ p: ZyklusPartnerPayload, _ analyse: ZyklusAnalyse, _ proTag: [Date: ZyklusTagesSicht]) -> some View {
        if p.pausiert {
            VStack(spacing: 8) {
                Image(systemName: "pause.circle.fill").font(.system(size: 30)).foregroundStyle(.pink)
                Text("Prognosen pausiert").font(.headline)
                Text("Es werden keine Perioden-, Eisprung- oder Fruchtbarkeits-Prognosen angezeigt.")
                    .font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
            .padding(20).frame(maxWidth: .infinity).glassCard(padding: 0)
        } else {
            ZyklusRingKarte(analyse: analyse, auswahl: $ringAuswahl)
            if analyse.status != .normal { ZyklusStatusKarte(analyse: analyse) }
            ZyklusPrognoseReihe(analyse: analyse)
        }

        ZyklusErfasstKarte(sicht: proTag[kal.startOfDay(for: Date())])
        ZyklusUeberblickKarte(analyse: analyse)
        analyseButton
    }

    private var analyseButton: some View {
        Button { zeigeAnalyse = true } label: {
            Label("Zyklusanalyse öffnen", systemImage: "chart.bar.xaxis.ascending")
                .font(.subheadline.bold())
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, minHeight: 56)
                .glassTintButton(.pink, radius: 20)
        }
        .buttonStyle(.plain)
    }

    // MARK: Monat

    @ViewBuilder
    private func monatsAnsicht(_ p: ZyklusPartnerPayload, _ analyse: ZyklusAnalyse, _ proTag: [Date: ZyklusTagesSicht]) -> some View {
        ZyklusKalenderView(
            monat: monat, eintraegeProTag: proTag, analyse: analyse,
            zeigePrognosen: !p.pausiert, ausgewaehlterTag: nil,
            onVorheriger: { monat = kal.date(byAdding: .month, value: -1, to: monat) ?? monat },
            onNaechster: { monat = kal.date(byAdding: .month, value: 1, to: monat) ?? monat },
            onTap: { tag in tagAuswahl = PartnerTagAuswahl(datum: kal.startOfDay(for: tag)) })
        .glassCard(padding: 0)

        Text("Tippe auf einen Tag, um alle Details zu sehen.")
            .font(.caption).foregroundStyle(.secondary)

        ZyklusKalenderLegende()
    }

    /// Bottom Sheet mit allen Werten des Tages – nur Anzeige.
    @ViewBuilder
    private func tagesSheet(_ tag: Date) -> some View {
        if let p = service.empfangen {
            let d = daten(p)
            NavigationStack {
                ScrollView {
                    VStack(spacing: 12) {
                        ZyklusTagesKarte(tag: tag, analyse: d.analyse, proTag: d.proTag, prognosen: !p.pausiert)
                        if d.proTag[tag] != nil {
                            ZyklusErfasstKarte(titel: "ERFASSTE WERTE", sicht: d.proTag[tag])
                        }
                    }
                    .padding(16)
                }
                .auroraScreen(.zyklus)
                .environment(\.locale, ZyklusLocale.de)
                .navigationTitle(tag.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(ZyklusLocale.de)))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) { TagesSheetFertig() }
                }
            }
            .presentationDetents([.medium, .large])
            .presentationBackground(.ultraThinMaterial)
        }
    }
}

private struct TagesSheetFertig: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View { Button("Fertig") { dismiss() } }
}
