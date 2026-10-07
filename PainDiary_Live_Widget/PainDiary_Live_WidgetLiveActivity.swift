//
//  PainDiary_Live_WidgetLiveActivity.swift
//  PainDiary_Live_Widget
//
//  Created by Dominik Gerber on 07.10.2026.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct PainDiary_Live_WidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct PainDiary_Live_WidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PainDiary_Live_WidgetAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

extension PainDiary_Live_WidgetAttributes {
    fileprivate static var preview: PainDiary_Live_WidgetAttributes {
        PainDiary_Live_WidgetAttributes(name: "World")
    }
}

extension PainDiary_Live_WidgetAttributes.ContentState {
    fileprivate static var smiley: PainDiary_Live_WidgetAttributes.ContentState {
        PainDiary_Live_WidgetAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: PainDiary_Live_WidgetAttributes.ContentState {
         PainDiary_Live_WidgetAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: PainDiary_Live_WidgetAttributes.preview) {
   PainDiary_Live_WidgetLiveActivity()
} contentStates: {
    PainDiary_Live_WidgetAttributes.ContentState.smiley
    PainDiary_Live_WidgetAttributes.ContentState.starEyes
}
