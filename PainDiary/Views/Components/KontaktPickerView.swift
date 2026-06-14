import SwiftUI
import ContactsUI

#if os(iOS)
struct KontaktDaten {
    let name: String
    let phone: String
    let email: String
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
                let name = [kontakt.givenName, kontakt.familyName]
                    .filter { !$0.isEmpty }.joined(separator: " ")
                guard !name.isEmpty else { return nil }
                let phone = kontakt.phoneNumbers.first?.value.stringValue ?? ""
                let email = kontakt.emailAddresses.first?.value as String? ?? ""
                return KontaktDaten(name: name, phone: phone, email: email)
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
