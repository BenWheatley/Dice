//
//  DiceNotationParser.swift
//  Dice
//
//  Created by Codex on 16.02.26.
//

import Foundation

struct RollConfiguration {
	let diceCount: Int
	let sideCount: Int
	let intuitive: Bool

	var notation: String {
		"\(diceCount)d\(sideCount)\(intuitive ? "i" : "")"
	}
}

struct DiceNotationParser {
	let diceBounds: ClosedRange<Int>
	let sideBounds: ClosedRange<Int>

	init(diceBounds: ClosedRange<Int> = 1...500, sideBounds: ClosedRange<Int> = 2...1000) {
		self.diceBounds = diceBounds
		self.sideBounds = sideBounds
	}

	func parse(_ text: String) -> RollConfiguration? {
		let sanitized = text.lowercased().replacingOccurrences(of: " ", with: "")
		if sanitized.isEmpty { return nil }

		let intuitive = sanitized.contains("i")
		let withoutIntuitiveFlag = sanitized.replacingOccurrences(of: "i", with: "")

		let diceCount: Int
		let sideCount: Int

		if let dIndex = withoutIntuitiveFlag.firstIndex(of: "d") {
			let dicePart = String(withoutIntuitiveFlag[..<dIndex])
			let sidePart = String(withoutIntuitiveFlag[withoutIntuitiveFlag.index(after: dIndex)...])
			guard let parsedDice = Int(dicePart), let parsedSides = Int(sidePart) else {
				return nil
			}
			diceCount = parsedDice
			sideCount = parsedSides
		} else {
			guard let parsedDice = Int(withoutIntuitiveFlag) else { return nil }
			diceCount = parsedDice
			sideCount = 6
		}

		guard diceBounds.contains(diceCount), sideBounds.contains(sideCount) else {
			return nil
		}

		return RollConfiguration(diceCount: diceCount, sideCount: sideCount, intuitive: intuitive)
	}
}

