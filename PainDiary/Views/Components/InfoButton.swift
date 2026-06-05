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
        .sheet(isPresented: $zeige) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    Text(titel).font(.headline)
                    Spacer()
                    Button { zeige = false } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                Divider()
                Text(text)
                    .font(.body)
                    .foregroundStyle(.primary.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .padding(20)
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(20)
        }
    }
}

