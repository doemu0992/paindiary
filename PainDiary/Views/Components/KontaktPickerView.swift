import SwiftUI
import ContactsUI

#if os(iOS)
struct KontaktPickerView: UIViewControllerRepresentable {
    let onFertig: ([(name: String, phone: String)]) -> Void
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
        let onFertig: ([(name: String, phone: String)]) -> Void
        let dismiss: DismissAction

        init(onFertig: @escaping ([(name: String, phone: String)]) -> Void, dismiss: DismissAction) {
            self.onFertig = onFertig
            self.dismiss = dismiss
        }

        func contactPicker(_ picker: CNContactPickerViewController, didSelect contacts: [CNContact]) {
            let daten = contacts.compactMap { kontakt -> (name: String, phone: String)? in
                let name = [kontakt.givenName, kontakt.familyName]
                    .filter { !$0.isEmpty }.joined(separator: " ")
                guard !name.isEmpty else { return nil }
                let phone = kontakt.phoneNumbers.first?.value.stringValue ?? ""
                return (name: name, phone: phone)
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
