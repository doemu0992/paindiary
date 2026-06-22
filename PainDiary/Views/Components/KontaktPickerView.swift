import SwiftUI
import Contacts

#if os(iOS)
struct KontaktDaten {
    let name: String
    let praxis: String
    let phone: String
    let email: String
    let adresse: String
}

struct KontaktPickerView: View {
    @Environment(\.dismiss) private var dismiss
    let onFertig: ([KontaktDaten]) -> Void

    @State private var kontakte: [CNContact] = []
    @State private var suche = ""
    @State private var laedt = true
    @State private var keinZugriff = false

    private var gefilterteKontakte: [CNContact] {
        guard !suche.isEmpty else { return kontakte }
        let s = suche.lowercased()
        return kontakte.filter {
            $0.givenName.lowercased().contains(s) ||
            $0.familyName.lowercased().contains(s) ||
            $0.organizationName.lowercased().contains(s)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if laedt {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if keinZugriff {
                    ContentUnavailableView(
                        "Kein Zugriff auf Kontakte",
                        systemImage: "person.crop.circle.badge.xmark",
                        description: Text("Erlaube PainDiary den Zugriff auf Kontakte unter Einstellungen → Datenschutz.")
                    )
                } else {
                    List(gefilterteKontakte, id: \.identifier) { kontakt in
                        Button {
                            onFertig([toDaten(kontakt)])
                            dismiss()
                        } label: {
                            kontaktZeile(kontakt)
                        }
                        .buttonStyle(.plain)
                    }
                    .listStyle(.plain)
                }
            }
            .searchable(text: $suche,
                        placement: .navigationBarDrawer(displayMode: .always),
                        prompt: "Suchen…")
            .navigationTitle("Kontakte")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
            }
        }
        .task { await ladeKontakte() }
    }

    @ViewBuilder
    private func kontaktZeile(_ k: CNContact) -> some View {
        let personName = [k.givenName, k.familyName].filter { !$0.isEmpty }.joined(separator: " ")
        let org = k.organizationName
        let anzeigeName = personName.isEmpty ? org : personName
        let telefon = k.phoneNumbers.first?.value.stringValue ?? ""

        VStack(alignment: .leading, spacing: 2) {
            Text(anzeigeName)
                .foregroundStyle(.primary)
            if !personName.isEmpty && !org.isEmpty {
                Text(org)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if !telefon.isEmpty {
                Text(telefon)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    private func ladeKontakte() async {
        let store = CNContactStore()
        let status = CNContactStore.authorizationStatus(for: .contacts)
        if status == .notDetermined {
            guard (try? await store.requestAccess(for: .contacts)) == true else {
                keinZugriff = true; laedt = false; return
            }
        } else if status != .authorized {
            keinZugriff = true; laedt = false; return
        }

        let keys: [CNKeyDescriptor] = [
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
            CNContactOrganizationNameKey as CNKeyDescriptor,
            CNContactPhoneNumbersKey as CNKeyDescriptor,
            CNContactEmailAddressesKey as CNKeyDescriptor,
            CNContactPostalAddressesKey as CNKeyDescriptor,
        ]
        let request = CNContactFetchRequest(keysToFetch: keys)
        request.sortOrder = .userDefault

        // Enumerate contacts off the main thread — enumerateContacts is synchronous blocking I/O
        let result = await Task.detached(priority: .userInitiated) {
            var list: [CNContact] = []
            try? store.enumerateContacts(with: request) { contact, _ in
                guard !contact.givenName.isEmpty || !contact.familyName.isEmpty || !contact.organizationName.isEmpty else { return }
                list.append(contact)
            }
            return list
        }.value

        kontakte = result
        laedt = false
    }

    private func toDaten(_ k: CNContact) -> KontaktDaten {
        let name = [k.givenName, k.familyName].filter { !$0.isEmpty }.joined(separator: " ")
        let phone = k.phoneNumbers.first?.value.stringValue ?? ""
        let email = k.emailAddresses.first?.value as String? ?? ""
        let adresse: String
        if let pa = k.postalAddresses.first?.value {
            let strasse = [pa.street, ""].filter { !$0.isEmpty }.first ?? ""
            let ort = [pa.postalCode, pa.city].filter { !$0.isEmpty }.joined(separator: " ")
            adresse = [strasse, ort].filter { !$0.isEmpty }.joined(separator: ", ")
        } else {
            adresse = ""
        }
        return KontaktDaten(name: name, praxis: k.organizationName, phone: phone, email: email, adresse: adresse)
    }
}
#endif
