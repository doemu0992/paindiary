import SwiftUI
import ContactsUI
import Contacts

#if os(iOS)
struct KontaktDaten {
    let name: String
    let praxis: String
    let phone: String
    let email: String
    let adresse: String
}

struct KontaktPickerView: UIViewControllerRepresentable {
    let onFertig: ([KontaktDaten]) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> CNContactPickerViewController {
        let picker = CNContactPickerViewController()
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: CNContactPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onFertig: onFertig, dismiss: dismiss)
    }

    class Coordinator: NSObject, CNContactPickerDelegate {
        let onFertig: ([KontaktDaten]) -> Void
        let dismiss: DismissAction

        init(onFertig: @escaping ([KontaktDaten]) -> Void, dismiss: DismissAction) {
            self.onFertig = onFertig
            self.dismiss = dismiss
        }

        func contactPicker(_ picker: CNContactPickerViewController, didSelect contacts: [CNContact]) {
            let daten = contacts.compactMap { kontakt -> KontaktDaten? in
                let personName = [kontakt.givenName, kontakt.familyName]
                    .filter { !$0.isEmpty }.joined(separator: " ")
                let praxis = kontakt.organizationName
                // At least one of name or praxis must be present
                guard !personName.isEmpty || !praxis.isEmpty else { return nil }

                let phone = kontakt.phoneNumbers.first?.value.stringValue ?? ""
                let email = kontakt.emailAddresses.first?.value as String? ?? ""

                let adresse: String
                if let pa = kontakt.postalAddresses.first?.value {
                    let teile = [pa.street, [pa.postalCode, pa.city].filter { !$0.isEmpty }.joined(separator: " ")]
                        .filter { !$0.isEmpty }
                    adresse = teile.joined(separator: ", ")
                } else {
                    adresse = ""
                }

                return KontaktDaten(name: personName, praxis: praxis, phone: phone, email: email, adresse: adresse)
            }
            onFertig(daten)
            dismiss()
        }

        func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
            dismiss()
        }
    }
}
#endif
