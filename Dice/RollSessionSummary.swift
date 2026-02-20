import Foundation

struct RollSessionSummary: Equatable {
	let rollCount: Int
	let totalDiceRolled: Int
	let topNotation: String?
	let latestNotation: String?
	let latestSum: Int?
}
