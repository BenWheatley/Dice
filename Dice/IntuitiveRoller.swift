//
//  IntuitiveRoller.swift
//  Dice
//
//  Created by Codex on 16.02.26.
//

import Foundation

struct IntuitiveRollContext {
	let sideCount: Int
	let numDiceBeingRolled: Int
	let totalRolls: Int
	let persistentTotals: [Int]
	let sortedTotals: [Int]
}

struct IntuitiveRoller {
	let fallbackRoller: TrueRandomRoller
	let randomDouble: () -> Double

	init(
		fallbackRoller: TrueRandomRoller = TrueRandomRoller(),
		randomDouble: @escaping () -> Double = { Double.random(in: 0..<1) }
	) {
		self.fallbackRoller = fallbackRoller
		self.randomDouble = randomDouble
	}

	func roll(context: IntuitiveRollContext, intuitive: Bool) -> Int {
		// Intuitive mode only applies once we have roll history; otherwise preserve baseline randomness.
		if context.totalRolls == 0 || !intuitive {
			return fallbackRoller.roll(sideCount: context.sideCount)
		}

		let localTotalRolls = context.persistentTotals.prefix(context.sideCount).reduce(0, +)
		if localTotalRolls == 0 {
			return fallbackRoller.roll(sideCount: context.sideCount)
		}

		let leastRolled = context.sortedTotals.count >= context.sideCount ? context.sortedTotals[context.sideCount - 1] : 0
		var rollBoundaries = Array(repeating: 0.0, count: context.sideCount)
		var scaleFactor = 0.0

		for index in 0..<context.sideCount {
			let count = context.persistentTotals[index]
			let observedProbability = Double(count) / Double(localTotalRolls)
			// Invert observed frequency so overrepresented faces lose weight over time.
			var intuitiveProbability = 1.0 - observedProbability
			if count - leastRolled >= context.numDiceBeingRolled {
				// If a face is already ahead by at least one full roll, temporarily suppress it.
				intuitiveProbability = 0
			}
			rollBoundaries[index] = intuitiveProbability
			scaleFactor += intuitiveProbability
		}

		if scaleFactor <= 0 {
			return fallbackRoller.roll(sideCount: context.sideCount)
		}

		for index in 0..<context.sideCount {
			rollBoundaries[index] /= scaleFactor
		}

		var sample = randomDouble()
		var index = 0
		// Convert normalized weights into a cumulative boundary walk.
		while index < context.sideCount - 1 && sample >= rollBoundaries[index] {
			sample -= rollBoundaries[index]
			index += 1
		}
		return index + 1
	}
}
