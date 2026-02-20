import Foundation

struct DicePool: Equatable {
	let diceCount: Int
	let sideCount: Int
	let intuitive: Bool
	let colorTag: String?

	init(diceCount: Int, sideCount: Int, intuitive: Bool = false) {
		self.diceCount = diceCount
		self.sideCount = sideCount
		self.intuitive = intuitive
		self.colorTag = nil
	}

	init(diceCount: Int, sideCount: Int, intuitive: Bool, colorTag: String?) {
		self.diceCount = diceCount
		self.sideCount = sideCount
		self.intuitive = intuitive
		self.colorTag = colorTag
	}
}
