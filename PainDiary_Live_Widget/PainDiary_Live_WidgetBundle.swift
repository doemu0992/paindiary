//
//  PainDiary_Live_WidgetBundle.swift
//  PainDiary_Live_Widget
//
//  Created by Dominik Gerber on 07.10.2026.
//

import WidgetKit
import SwiftUI

@main
struct PainDiary_Live_WidgetBundle: WidgetBundle {
    var body: some Widget {
        PainDiary_Live_Widget()
        PainDiary_Live_WidgetControl()
        PainDiary_Live_WidgetLiveActivity()
    }
}
