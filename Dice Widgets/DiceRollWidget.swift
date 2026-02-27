import SwiftUI
import WidgetKit

struct DiceRollWidgetEntry: TimelineEntry {
	let date: Date
	let snapshot: DiceWidgetRollSnapshot
}

struct DiceRollWidgetProvider: TimelineProvider {
	private let store = DiceWidgetSnapshotStore()

	func placeholder(in context: Context) -> DiceRollWidgetEntry {
		DiceRollWidgetEntry(
			date: Date(),
			snapshot: DiceWidgetRollSnapshot(
				notation: "6d6",
				lastTotal: 21,
				modeToken: .trueRandom,
				recentTotals: [21, 18, 24],
				isEmptyState: false,
				themeToken: .system
			)
		)
	}

	func getSnapshot(in context: Context, completion: @escaping (DiceRollWidgetEntry) -> Void) {
		completion(DiceRollWidgetEntry(date: Date(), snapshot: store.loadSnapshot()))
	}

	func getTimeline(in context: Context, completion: @escaping (Timeline<DiceRollWidgetEntry>) -> Void) {
		let entry = DiceRollWidgetEntry(date: Date(), snapshot: store.loadSnapshot())
		let refresh = Calendar.current.date(byAdding: .minute, value: 30, to: entry.date) ?? entry.date.addingTimeInterval(1800)
		completion(Timeline(entries: [entry], policy: .after(refresh)))
	}
}

struct DiceRollWidget: Widget {
	let kind = "DiceRollWidget"

	var body: some WidgetConfiguration {
		StaticConfiguration(kind: kind, provider: DiceRollWidgetProvider()) { entry in
			DiceRollWidgetView(entry: entry)
		}
		.configurationDisplayName("Dice Roll")
		.description("Shows the latest roll summary.")
		.supportedFamilies([
			.systemSmall,
			.systemMedium,
			.accessoryInline,
			.accessoryCircular,
		])
	}
}

private struct DiceRollWidgetView: View {
	let entry: DiceRollWidgetEntry
	@Environment(\.widgetFamily) private var family
	@Environment(\.colorScheme) private var colorScheme

	var body: some View {
		switch family {
		case .accessoryInline:
			Text(inlineText)
		case .accessoryCircular:
			ZStack {
				AccessoryWidgetBackground()
				Text(circularText)
					.font(.caption.bold())
			}
		case .systemSmall:
			VStack(alignment: .leading, spacing: 6) {
				Text(entry.snapshot.notation)
					.font(.caption.bold())
					.lineLimit(1)
				Text("\(entry.snapshot.lastTotal)")
					.font(.system(size: 34, weight: .bold, design: .rounded))
					.lineLimit(1)
				Text(modeLabel)
					.font(.caption2)
			}
			.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
			.padding(12)
			.foregroundStyle(widgetPalette.foreground)
			.containerBackground(widgetPalette.background, for: .widget)
		default:
			VStack(alignment: .leading, spacing: 6) {
				Text(entry.snapshot.notation)
					.font(.headline)
					.lineLimit(1)
				Text("Total \(entry.snapshot.lastTotal)")
					.font(.title2.weight(.bold))
				if !entry.snapshot.recentTotals.isEmpty {
					Text("Recent \(entry.snapshot.recentTotals.map(String.init).joined(separator: " • "))")
						.font(.caption)
						.lineLimit(1)
				}
				Text(entry.snapshot.modeToken == .intuitive ? "Intuitive" : "True-random")
					.font(.caption2)
					.foregroundStyle(.secondary)
			}
			.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
			.padding(10)
		}
	}

	private var inlineText: String {
		if entry.snapshot.isEmptyState {
			return "Dice: ready"
		}
		return "\(entry.snapshot.notation) = \(entry.snapshot.lastTotal)"
	}

	private var circularText: String {
		entry.snapshot.isEmptyState ? "--" : "\(entry.snapshot.lastTotal)"
	}

	private var modeLabel: String {
		entry.snapshot.modeToken == .intuitive ? "Intuitive" : "True-random"
	}

	private var widgetPalette: (foreground: Color, background: Color) {
		switch entry.snapshot.themeToken {
		case .lightMode:
			return (.black, Color(white: 0.95))
		case .darkMode:
			return (.white, Color(white: 0.16))
		case .system:
			return colorScheme == .dark ? (.white, Color(white: 0.16)) : (.black, Color(white: 0.95))
		}
	}
}
