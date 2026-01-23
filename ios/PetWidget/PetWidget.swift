import WidgetKit
import SwiftUI

let AppGroup = "group.com.ssseregi.petWidgetApp"

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), petImage: "cat", petMessage: "Hello!")
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let entry = SimpleEntry(date: Date(), petImage: "cat", petMessage: "Hello!")
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        var entries: [SimpleEntry] = []
        let userDefaults = UserDefaults(suiteName: AppGroup)
        let petImage = userDefaults?.string(forKey: "pet_emoji")
        let petMessage = userDefaults?.string(forKey: "pet_message")

        let currentDate = Date()
        let entry = SimpleEntry(date: currentDate, petImage: petImage, petMessage: petMessage)
        entries.append(entry)

        let timeline = Timeline(entries: entries, policy: .atEnd)
        completion(timeline)
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let petImage: String?
    let petMessage: String?
}

struct PetWidgetEntryView : View {
    var entry: Provider.Entry

    var body: some View {
        VStack {
            Text("Pet Image: \(entry.petImage ?? "not set")")
            Text("Pet Message: \(entry.petMessage ?? "not set")")
            // Ccommented out until the user provides the image
            // if let message = entry.petMessage, !message.isEmpty {
            //     ZStack {
            //         Image("pixel_message")
            //             .resizable()
            //             .frame(width: 80, height: 60)
            //         Text(message)
            //             .font(.system(size: 12))
            //             .foregroundColor(.black)
            //             .padding(.bottom, 5)
            //     }
            //     .padding(.bottom, -10)
            // }

            if let petImageName = entry.petImage, !petImageName.isEmpty,
               ["cat", "dog_1", "frog", "hamster", "horse_1", "parrot_1", "parrot_2", "rabbit"].contains(petImageName) {
                Image(petImageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100, height: 100)
            }
        }
    }
}

struct PetWidget: Widget {
    let kind: String = "PetWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            if #available(iOS 17.0, *) {
                PetWidgetEntryView(entry: entry)
                    .containerBackground(for: .widget) {
                        ZStack {
                            Color(red: 0.53, green: 0.81, blue: 0.92) // Sky blue
                            VStack {
                                Spacer()
                                Rectangle()
                                    .fill(Color(red: 0.4, green: 0.8, blue: 0.4)) // Green grass
                                    .frame(height: 45)
                            }
                        }
                    }
            } else {
                ZStack {
                    Color(red: 0.53, green: 0.81, blue: 0.92) // Sky blue
                    VStack {
                        Spacer()
                        Rectangle()
                            .fill(Color(red: 0.4, green: 0.8, blue: 0.4)) // Green grass
                            .frame(height: 45)
                    }
                    PetWidgetEntryView(entry: entry)
                }
            }
        }
        .configurationDisplayName("My Widget")
        .description("This is an example widget.")
    }
}

#Preview(as: .systemSmall) {
    PetWidget()
} timeline: {
    SimpleEntry(date: .now, petImage: "cat", petMessage: "Hi there!")
    SimpleEntry(date: .now, petImage: "dog_1", petMessage: "Woof!")
}
