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

/// Schreibgeschützte Ansicht des geteilten Zyklus.
struct ZyklusPartnerView: View {
    @State private var service = ZyklusPartnerService.shared
    @State private var ringAuswahl: Int? = nil
    @State private var monat = Date()
    @State private var ansicht = 0

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
        .alert("Partner-Sharing", isPresented: Binding(get: { service.meldung != nil },
                                                      set: { if !$0 { service.meldung = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(service.meldung ?? "") }
    }

    @ViewBuilder
    private func inhalt(_ p: ZyklusPartnerPayload) -> some View {
        // Transiente Modellobjekte (werden nicht in einen ModelContext eingefügt)
        let eintraege = p.eintraege.map { $0.modell() }
        let analyse = ZyklusRechner.analyse(eintraege: eintraege)
        let proTag = Dictionary(grouping: eintraege) { $0.tag.beginn(in: kal.timeZone) }
            .mapValues { ZyklusTagesSicht($0) }

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
            case 0:
                ZyklusRingView(analyse: analyse, untertitel: statusText(analyse), auswahl: $ringAuswahl)
                    .padding(8).glassCard(padding: 0)
            case 1:
                ZyklusKalenderView(
                    monat: monat, eintraegeProTag: proTag, analyse: analyse,
                    zeigePrognosen: !p.pausiert, ausgewaehlterTag: nil,
                    onVorheriger: { monat = kal.date(byAdding: .month, value: -1, to: monat) ?? monat },
                    onNaechster: { monat = kal.date(byAdding: .month, value: 1, to: monat) ?? monat },
                    onTap: { _ in })
                .glassCard(padding: 0)
            default:
                ZyklusVerlaufView(analyse: analyse, proTag: proTag)
            }
        }
    }

    private func statusText(_ a: ZyklusAnalyse) -> String {
        guard let np = a.naechstePeriodeStart else { return "" }
        let tage = kal.dateComponents([.day], from: kal.startOfDay(for: Date()), to: kal.startOfDay(for: np)).day ?? 0
        return tage < 0 ? "Periode \(-tage) Tage überfällig" : (tage == 0 ? "Periode heute erwartet" : "Periode in \(tage) Tagen")
    }
}
