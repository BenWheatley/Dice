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
			snapshot: DiceWidgetTimelinePolicy.placeholderSnapshot
		)
	}

	func getSnapshot(in context: Context, completion: @escaping (DiceRollWidgetEntry) -> Void) {
		if context.isPreview {
			completion(placeholder(in: context))
			return
		}
		completion(DiceRollWidgetEntry(date: Date(), snapshot: store.loadSnapshot()))
	}

	func getTimeline(in context: Context, completion: @escaping (Timeline<DiceRollWidgetEntry>) -> Void) {
		let entry = DiceRollWidgetEntry(date: Date(), snapshot: store.loadSnapshot())
		let refreshMinutes = DiceWidgetTimelinePolicy.refreshIntervalMinutes(for: entry.snapshot)
		let refresh = Calendar.current.date(byAdding: .minute, value: refreshMinutes, to: entry.date) ?? entry.date.addingTimeInterval(TimeInterval(refreshMinutes * 60))
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
				lineLimit(1)
				.widgetURL(URL(string: "dice://roll"))
		case .accessoryCircular:
			ZStack {
				AccessoryWidgetBackground()
				VStack(spacing: 0) {
					Text(circularText)
						.font(.system(size: 14, weight: .bold, design: .rounded))
						.monospacedDigit()
					Text(circularModeToken)
						.font(.system(size: 8, weight: .semibold, design: .rounded))
						.foregroundStyle(.secondary)
				}
			}
			.widgetURL(URL(string: "dice://presets"))
		case .systemSmall:
			VStack(alignment: .leading, spacing: 6) {
				Text(entry.snapshot.isEmptyState ? "Ready" : entry.snapshot.notation)
					.font(.caption.bold())
					.lineLimit(1)
				Text(entry.snapshot.isEmptyState ? "--" : "\(entry.snapshot.lastTotal)")
					.font(.system(size: 34, weight: .bold, design: .rounded))
					.lineLimit(1)
				Text(entry.snapshot.isEmptyState ? "Roll to start" : modeLabel)
					.font(.caption2)
			}
			.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
			.padding(12)
			.foregroundStyle(widgetPalette.foreground)
			.containerBackground(widgetPalette.background, for: .widget)
			.widgetURL(URL(string: "dice://roll"))
		case .systemMedium:
			VStack(alignment: .leading, spacing: 8) {
				HStack(alignment: .firstTextBaseline) {
					Text(entry.snapshot.isEmptyState ? "No roll yet" : entry.snapshot.notation)
						.font(.headline)
						.lineLimit(1)
					Spacer(minLength: 8)
					Text(entry.snapshot.isEmptyState ? "Ready" : modeLabel)
						.font(.caption)
						.foregroundStyle(.secondary)
				}
				HStack(alignment: .firstTextBaseline, spacing: 6) {
					Text("Last")
						.font(.caption)
						.foregroundStyle(.secondary)
					Text(entry.snapshot.isEmptyState ? "--" : "\(entry.snapshot.lastTotal)")
						.font(.system(size: 34, weight: .bold, design: .rounded))
						.lineLimit(1)
				}
				HStack(spacing: 6) {
					ForEach(recentStripValues.indices, id: \.self) { index in
						let value = recentStripValues[index]
						Text("\(value)")
							.font(.caption2.bold())
							.frame(maxWidth: .infinity)
							.padding(.vertical, 6)
							.background(Color.secondary.opacity(0.14), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
					}
				}
			}
			.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
			.padding(12)
			.widgetURL(URL(string: "dice://history"))
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
			.widgetURL(URL(string: "dice://roll"))
		}
	}

	private var inlineText: String {
		if entry.snapshot.isEmptyState {
			return "Dice ready"
		}
		return "\(compactModeToken) \(entry.snapshot.notation) \(entry.snapshot.lastTotal)"
	}

	private var circularText: String {
		entry.snapshot.isEmptyState ? "--" : "\(entry.snapshot.lastTotal)"
	}

	private var compactModeToken: String {
		entry.snapshot.modeToken == .intuitive ? "I" : "R"
	}

	private var circularModeToken: String {
		entry.snapshot.modeToken == .intuitive ? "INT" : "RND"
	}

	private var modeLabel: String {
		entry.snapshot.modeToken == .intuitive ? "Intuitive" : "True-random"
	}

	private var recentStripValues: [Int] {
		let values = Array(entry.snapshot.recentTotals.prefix(3))
		if values.count >= 3 { return values }
		return values + Array(repeating: 0, count: 3 - values.count)
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
