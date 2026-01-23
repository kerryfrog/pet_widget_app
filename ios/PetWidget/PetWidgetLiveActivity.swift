//
//  PetWidgetLiveActivity.swift
//  PetWidget
//
//  Created by 이다솜 on 1/19/26.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct PetWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct PetWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PetWidgetAttributes.self) { context in
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

extension PetWidgetAttributes {
    fileprivate static var preview: PetWidgetAttributes {
        PetWidgetAttributes(name: "World")
    }
}

extension PetWidgetAttributes.ContentState {
    fileprivate static var smiley: PetWidgetAttributes.ContentState {
        PetWidgetAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: PetWidgetAttributes.ContentState {
         PetWidgetAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: PetWidgetAttributes.preview) {
   PetWidgetLiveActivity()
} contentStates: {
    PetWidgetAttributes.ContentState.smiley
    PetWidgetAttributes.ContentState.starEyes
}
