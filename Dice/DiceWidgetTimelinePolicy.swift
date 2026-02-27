import Foundation

enum DiceWidgetTimelinePolicy {
	static let placeholderSnapshot = DiceWidgetRollSnapshot(
		notation: "6d6",
		lastTotal: 21,
		modeToken: .trueRandom,
		recentTotals: [21, 18, 24],
		isEmptyState: false,
		themeToken: .system
	)

	static func refreshIntervalMinutes(for snapshot: DiceWidgetRollSnapshot) -> Int {
		snapshot.isEmptyState ? 120 : 30
	}
}
