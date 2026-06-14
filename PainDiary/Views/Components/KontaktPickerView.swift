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

// CNContactPickerViewController must be presented natively (not wrapped in a SwiftUI sheet)
// otherwise its internal search bar stops working. This representable embeds a transparent
// UIViewController that presents the picker directly when isPresented becomes true.
struct KontaktPickerView: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let onFertig: ([KontaktDaten]) -> Void

    func makeUIViewController(context: Context) -> UIViewController {
        let vc = UIViewController()
        vc.view.backgroundColor = .clear
        return vc
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        if isPresented && context.coordinator.pickerVC == nil {
            let picker = CNContactPickerViewController()
            picker.delegate = context.coordinator
            context.coordinator.pickerVC = picker
            uiViewController.present(picker, animated: true)
        } else if !isPresented, let picker = context.coordinator.pickerVC {
            picker.dismiss(animated: true)
            context.coordinator.pickerVC = nil
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(isPresented: $isPresented, onFertig: onFertig)
    }

    class Coordinator: NSObject, CNContactPickerDelegate {
        @Binding var isPresented: Bool
        let onFertig: ([KontaktDaten]) -> Void
        var pickerVC: CNContactPickerViewController?

        init(isPresented: Binding<Bool>, onFertig: @escaping ([KontaktDaten]) -> Void) {
            _isPresented = isPresented
            self.onFertig = onFertig
        }

        func contactPicker(_ picker: CNContactPickerViewController, didSelect contacts: [CNContact]) {
            let daten = contacts.compactMap { kontakt -> KontaktDaten? in
                let personName = [kontakt.givenName, kontakt.familyName]
                    .filter { !$0.isEmpty }.joined(separator: " ")
                let praxis = kontakt.organizationName
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
            pickerVC = nil
            isPresented = false
        }

        func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
            pickerVC = nil
            isPresented = false
        }
    }
}
#endif
