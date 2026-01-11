//
//  PetWidget.swift
//  PetWidget
//
//  Created by 이다솜 on 1/11/26.
//

import WidgetKit
import SwiftUI

struct Provider: TimelineProvider {
    // 위젯의 기본 상태
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), emoji: "🐣")
    }

    // 위젯 미리보기 상태
    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let entry = SimpleEntry(date: Date(), emoji: "🐣")
        completion(entry)
    }

    // 실제 데이터를 가져와서 위젯을 갱신하는 로직
    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        // App Group을 통해 저장된 데이터를 읽어옵니다.
        let prefs = UserDefaults(suiteName: "group.com.ssseregi.petWidgetApp")
        let emoji = prefs?.string(forKey: "pet_emoji") ?? "🐣"

        let entry = SimpleEntry(date: Date(), emoji: emoji)
        let timeline = Timeline(entries: [entry], policy: .atEnd)
        completion(timeline)
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let emoji: String
}

struct PetWidgetEntryView : View {
    var entry: Provider.Entry

    var body: some View {
        VStack {
            Text(entry.emoji)
                .font(.system(size: 60))
        }
    }
}

@main
struct PetWidget: Widget {
    let kind: String = "PetWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            PetWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("우리펫위젯")
        .description("친구의 펫을 확인하세요!")
    }
}
