import Foundation

struct RollHistoryIndicators: Equatable {
	let highStreak: Int
	let lowStreak: Int
	let outlierNotation: String?
	let outlierZScore: Double?

	var hasHighlights: Bool {
		highStreak >= 3 || lowStreak >= 3 || (outlierZScore.map { abs($0) >= 1.75 } ?? false)
	}
}
