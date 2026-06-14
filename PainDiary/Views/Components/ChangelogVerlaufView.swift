import SwiftUI

struct ChangelogVerlaufView: View {
    var body: some View {
        List {
            ForEach(appChangelog, id: \.build) { version in
                Section {
                    ForEach(version.aenderungen) { item in
                        HStack(alignment: .top, spacing: 14) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(item.farbe.opacity(0.15))
                                    .frame(width: 44, height: 44)
                                Image(systemName: item.icon)
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(item.farbe)
                            }
                            VStack(alignment: .leading, spacing: 3) {
                                Text(item.titel)
                                    .font(.subheadline.bold())
                                Text(item.beschreibung)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(.vertical, 6)
                        }
                    }
                } header: {
                    HStack {
                        Text("Version \(version.version)")
                            .font(.subheadline.bold())
                            .foregroundStyle(.primary)
                            .textCase(nil)
                        Spacer()
                        Text("Build \(version.build)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textCase(nil)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Versionsverlauf")
        .navigationBarTitleDisplayMode(.large)
    }
}
