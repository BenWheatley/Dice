import Foundation

struct DiceStats {
	var localTotals: [Int]
	var sessionTotals: [Int]
	var totalRolls: Int
	var sum: Int

	static var empty: DiceStats {
		DiceStats(localTotals: [], sessionTotals: [], totalRolls: 0, sum: 0)
	}

	init(localTotals: [Int], sessionTotals: [Int], totalRolls: Int, sum: Int) {
		self.localTotals = localTotals
		self.sessionTotals = sessionTotals
		self.totalRolls = totalRolls
		self.sum = sum
	}

	init(outcome: RollOutcome) {
		self.init(
			localTotals: outcome.localTotals,
			sessionTotals: outcome.sessionTotals,
			totalRolls: outcome.totalRolls,
			sum: outcome.sum
		)
	}
}
