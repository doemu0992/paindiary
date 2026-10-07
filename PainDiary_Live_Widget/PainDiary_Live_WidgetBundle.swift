import WidgetKit
import SwiftUI

@main
struct PainDiary_Live_WidgetBundle: WidgetBundle {
    var body: some Widget {
        PainDiary_Live_Widget()
        PainDiary_Live_WidgetLiveActivity()
    }
}
