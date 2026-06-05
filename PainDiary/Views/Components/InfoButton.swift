import SwiftUI

struct InfoButton: View {
    let titel: String
    let text: String
    @State private var zeige = false

    var body: some View {
        Button { zeige = true } label: {
            Image(systemName: "info.circle")
                .font(.caption)
                .foregroundStyle(.teal.opacity(0.8))
        }
        .buttonStyle(.plain)
        .popover(isPresented: $zeige) {
            VStack(alignment: .leading, spacing: 10) {
                Text(titel).font(.headline)
                Text(text)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding()
            .frame(minWidth: 220, maxWidth: 300)
            .presentationCompactAdaptation(.popover)
        }
    }
}
