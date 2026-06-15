import SwiftUI
import SwiftData

struct PushManagerView: View {
    @AppStorage("tagesErinnerungAktiv") private var tagesErinnerungAktiv = false
    @AppStorage("tagesErinnerungZeit") private var tagesErinnerungZeitSek = 28800.0

    @AppStorage("wasserErinnerungAktiv") private var wasserErinnerungAktiv = false
    @AppStorage("wasserErinnerungZeit") private var wasserErinnerungZeitSek = 54000.0

    @Query(sort: \Dauermedikation.name) private var medikamente: [Dauermedikation]

    @State private var bearbeitetMedikament: Dauermedikation? = nil

    private let notif = NotificationManager.shared

    private var tagesErinnerungZeit: Binding<Date> {
        Binding(
            get: { Date(timeIntervalSinceReferenceDate: tagesErinnerungZeitSek) },
            set: { tagesErinnerungZeitSek = $0.timeIntervalSinceReferenceDate }
        )
    }

    private var wasserErinnerungZeit: Binding<Date> {
        Binding(
            get: { Date(timeIntervalSinceReferenceDate: wasserErinnerungZeitSek) },
            set: { wasserErinnerungZeitSek = $0.timeIntervalSinceReferenceDate }
        )
    }

    var body: some View {
        List {
            // MARK: - Status
            if notif.status != .authorized {
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: "bell.slash.fill")
                            .font(.title2)
                            .foregroundStyle(.red)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Benachrichtigungen deaktiviert")
                                .font(.subheadline.bold())
                            Text("Aktiviere sie in den iOS-Einstellungen damit Erinnerungen ankommen.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button {
                            if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        } label: {
                            Text("Öffnen")
                                .font(.caption.bold())
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.red.opacity(0.12), in: Capsule())
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 4)
                }
            }

            // MARK: - Tägliche Erinnerung
            Section {
                Toggle("Tägliche Erinnerung", isOn: $tagesErinnerungAktiv)
                    .onChange(of: tagesErinnerungAktiv) { _, aktiv in
                        if aktiv {
                            Task {
                                let granted = await notif.berechtigungAnfordern()
                                if granted {
                                    let dc = Calendar.current.dateComponents([.hour, .minute], from: tagesErinnerungZeit.wrappedValue)
                                    notif.planeTagesErinnerung(stunde: dc.hour ?? 8, minute: dc.minute ?? 0)
                                } else {
                                    tagesErinnerungAktiv = false
                                }
                            }
                        } else {
                            notif.loescheTagesErinnerung()
                        }
                    }

                if tagesErinnerungAktiv {
                    DatePicker("Uhrzeit", selection: tagesErinnerungZeit, displayedComponents: .hourAndMinute)
                        .onChange(of: tagesErinnerungZeit.wrappedValue) { _, neue in
                            let dc = Calendar.current.dateComponents([.hour, .minute], from: neue)
                            notif.planeTagesErinnerung(stunde: dc.hour ?? 8, minute: dc.minute ?? 0)
                        }
                }
            } header: {
                Label("Tagebuch", systemImage: "book.pages")
            } footer: {
                Text("Erinnert dich täglich daran, deinen Schmerzstatus zu erfassen.")
            }

            // MARK: - Wasser-Erinnerung
            Section {
                Toggle("Wasser-Erinnerung", isOn: $wasserErinnerungAktiv)
                    .onChange(of: wasserErinnerungAktiv) { _, aktiv in
                        if aktiv {
                            Task {
                                let granted = await notif.berechtigungAnfordern()
                                if granted {
                                    let dc = Calendar.current.dateComponents([.hour, .minute], from: wasserErinnerungZeit.wrappedValue)
                                    notif.planeWasserErinnerung(stunde: dc.hour ?? 15, minute: dc.minute ?? 0)
                                } else {
                                    wasserErinnerungAktiv = false
                                }
                            }
                        } else {
                            notif.loescheWasserErinnerung()
                        }
                    }

                if wasserErinnerungAktiv {
                    DatePicker("Uhrzeit", selection: wasserErinnerungZeit, displayedComponents: .hourAndMinute)
                        .onChange(of: wasserErinnerungZeit.wrappedValue) { _, neue in
                            let dc = Calendar.current.dateComponents([.hour, .minute], from: neue)
                            notif.planeWasserErinnerung(stunde: dc.hour ?? 15, minute: dc.minute ?? 0)
                        }
                }
            } header: {
                Label("Wohlbefinden", systemImage: "drop.fill")
            } footer: {
                Text("Erinnert dich daran, genug Wasser zu trinken.")
            }

            // MARK: - Medikament-Erinnerungen
            Section {
                if medikamente.isEmpty {
                    Text("Keine Medikamente erfasst")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                } else {
                    ForEach(medikamente) { med in
                        Button {
                            bearbeitetMedikament = med
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: med.typSymbol)
                                    .font(.title3)
                                    .foregroundStyle(med.erinnerungAktiv && med.aktiv ? Color.accentColor : .secondary)
                                    .frame(width: 32)

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(med.name)
                                        .font(.subheadline.bold())
                                        .foregroundStyle(.primary)
                                    if med.erinnerungAktiv && med.aktiv {
                                        let zeiten = notif.gueltigeZeiten(fuer: med)
                                        if zeiten.isEmpty {
                                            Text("Bei Bedarf")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        } else {
                                            Text(zeiten.map(\.anzeigeText).joined(separator: " · "))
                                                .font(.caption)
                                                .foregroundStyle(Color.accentColor)
                                        }
                                    } else if !med.aktiv {
                                        Text("Inaktiv")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    } else {
                                        Text("Keine Erinnerung")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 2)
                        }
                        .buttonStyle(.plain)
                    }
                }
            } header: {
                Label("Medikamente", systemImage: "pills.fill")
            } footer: {
                Text("Tippe auf ein Medikament um Erinnerungszeiten zu bearbeiten.")
            }

            // MARK: - Zyklus
            Section {
                HStack(spacing: 12) {
                    Image(systemName: "circle.grid.cross.fill")
                        .font(.title3)
                        .foregroundStyle(.pink)
                        .frame(width: 32)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Zyklus-Erinnerungen")
                            .font(.subheadline.bold())
                        Text("Automatisch basierend auf deinem Zyklus")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
                .padding(.vertical, 2)
            } header: {
                Label("Zyklus", systemImage: "circle.grid.cross.fill")
            } footer: {
                Text("Erinnerungen für Periode, fruchtbare Tage und Eisprung werden automatisch aus deinen Zyklus-Daten berechnet.")
            }
        }
        .navigationTitle("Benachrichtigungen")
        .navigationBarTitleDisplayMode(.large)
        .sheet(item: $bearbeitetMedikament) { med in
            NavigationStack {
                MedikamentFormView(medikament: med)
            }
        }
        .task { await notif.berechtigungAnfordern() }
    }

}

