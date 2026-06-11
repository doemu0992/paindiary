import SwiftUI
import QuickLook

#if os(iOS)
struct PDFPreviewView: UIViewControllerRepresentable {
    let url: URL

    func makeCoordinator() -> Coordinator { Coordinator(url: url) }

    func makeUIViewController(context: Context) -> UINavigationController {
        let preview = QLPreviewController()
        preview.dataSource = context.coordinator

        let shareBtn = UIBarButtonItem(
            image: UIImage(systemName: "square.and.arrow.up"),
            style: .plain,
            target: context.coordinator,
            action: #selector(Coordinator.teilen(_:))
        )
        preview.navigationItem.rightBarButtonItem = shareBtn

        let nav = UINavigationController(rootViewController: preview)
        // Force light mode so PDF colors always render correctly
        nav.overrideUserInterfaceStyle = .light
        context.coordinator.navController = nav
        return nav
    }

    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {}

    class Coordinator: NSObject, QLPreviewControllerDataSource {
        let url: URL
        weak var navController: UINavigationController?

        init(url: URL) { self.url = url }

        func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }
        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            url as NSURL
        }

        @objc func teilen(_ sender: UIBarButtonItem) {
            let av = UIActivityViewController(activityItems: [url], applicationActivities: nil)
            av.popoverPresentationController?.barButtonItem = sender
            navController?.topViewController?.present(av, animated: true)
        }
    }
}
#endif
