import WidgetKit
import SwiftUI

let AppGroup = "group.com.ssseregi.petWidget"

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
        
        // 디버깅을 위한 로그
        print("PetWidget - petImage: \(petImage ?? "nil")")
        print("PetWidget - petMessage: \(petMessage ?? "nil")")

        let currentDate = Date()
        let entry = SimpleEntry(date: currentDate, petImage: petImage, petMessage: petMessage)
        entries.append(entry)

        // 5분마다 자동 새로고침
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 5, to: currentDate)!
        let timeline = Timeline(entries: entries, policy: .after(nextUpdate))
        completion(timeline)
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let petImage: String?
    let petMessage: String?
}

private let supportedPetImageNames: Set<String> = [
    "cat", "dog_1", "dog_4", "frog", "hamster", "horse_1", "parrot_1", "parrot_2", "rabbit", "rhino"
]

private func normalizedPetImageName(from rawValue: String?) -> String? {
    guard let rawValue, !rawValue.isEmpty else { return nil }

    let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }

    let lastComponent = (trimmed as NSString).lastPathComponent
    let nameWithoutExtension = (lastComponent as NSString).deletingPathExtension
    let candidate = nameWithoutExtension.isEmpty ? lastComponent : nameWithoutExtension
    let normalized = candidate.lowercased()

    if supportedPetImageNames.contains(normalized) {
        return normalized
    }

    // Handle legacy id-like values.
    switch normalized {
    case "cat_01":
        return "cat"
    case "dog_01":
        return "dog_1"
    case "dog_04":
        return "dog_4"
    case "frog_01":
        return "frog"
    case "hamster_01":
        return "hamster"
    case "horse_01":
        return "horse_1"
    case "parrot_01":
        return "parrot_1"
    case "parrot_02":
        return "parrot_2"
    case "rabbit_01":
        return "rabbit"
    case "rhino_01":
        return "rhino"
    default:
        return nil
    }
}

struct PetWidgetEntryView : View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        let isSmall = family == .systemSmall
        let bubbleSize = isSmall ? CGSize(width: 70, height: 50) : CGSize(width: 80, height: 60)
        let imageSize: CGFloat = isSmall ? 72 : 100

        VStack {
            if let message = entry.petMessage, !message.isEmpty {
                ZStack {
                    Image("pixel_message")
                        .resizable()
                        .frame(width: bubbleSize.width, height: bubbleSize.height)
                    Text(message)
                        .font(.system(size: isSmall ? 10 : 12))
                        .lineLimit(1)
                        .foregroundColor(.black)
                        .padding(.bottom, isSmall ? 3 : 5)
                }
                .padding(.bottom, isSmall ? -6 : -10)
            }

            if let petImageName = normalizedPetImageName(from: entry.petImage) {
                Image(petImageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: imageSize, height: imageSize)
            } else if let fallbackText = entry.petImage, !fallbackText.isEmpty {
                Text("PET")
                    .font(.system(size: isSmall ? 18 : 22, weight: .bold))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .widgetURL(URL(string: "petwidget://yard"))
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
                                    .frame(height: 40)
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
                            .frame(height: 40)
                    }
                    PetWidgetEntryView(entry: entry)
                }
            }
        }
        .configurationDisplayName("My Widget")
        .description("This is an example widget.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

#Preview(as: .systemSmall) {
    PetWidget()
} timeline: {
    SimpleEntry(date: .now, petImage: "cat", petMessage: "Hi there!")
    SimpleEntry(date: .now, petImage: "dog_1", petMessage: "Woof!")
}
