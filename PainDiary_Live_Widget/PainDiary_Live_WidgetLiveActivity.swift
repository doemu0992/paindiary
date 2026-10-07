import ActivityKit
import WidgetKit
import SwiftUI

struct PainDiary_Live_WidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ZyklusLiveAttributes.self) { context in
            HStack(spacing: 14) {
                Image(systemName: context.state.symbol)
                    .font(.title)
                    .foregroundStyle(farbe(context.attributes.art))
                VStack(alignment: .leading, spacing: 2) {
                    Text(context.state.titel).font(.headline)
                    Text(context.state.detail).font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                VStack(spacing: 0) {
                    Text("TAG").font(.caption2).foregroundStyle(.secondary)
                    Text("\(context.state.zyklustag)")
                        .font(.system(.title, design: .rounded).bold())
                        .foregroundStyle(farbe(context.attributes.art))
                }
            }
            .padding()
            .activityBackgroundTint(Color.black.opacity(0.35))
            .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: context.state.symbol).foregroundStyle(farbe(context.attributes.art))
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Tag \(context.state.zyklustag)").font(.headline)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading) {
                        Text(context.state.titel).font(.headline)
                        Text(context.state.detail).font(.caption).foregroundStyle(.secondary)
                    }
                }
            } compactLeading: {
                Image(systemName: context.state.symbol).foregroundStyle(farbe(context.attributes.art))
            } compactTrailing: {
                Text("\(context.state.zyklustag)")
            } minimal: {
                Image(systemName: context.state.symbol).foregroundStyle(farbe(context.attributes.art))
            }
            .keylineTint(farbe(context.attributes.art))
        }
    }

    private func farbe(_ art: String) -> Color {
        art == "fruchtbar" ? .teal : Color(red: 0.90, green: 0.25, blue: 0.40)
    }
}
