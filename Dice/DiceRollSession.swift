//
//  DiceRollSession.swift
//  Dice
//
//  Created by Codex on 16.02.26.
//

import Foundation

struct RollOutcome {
	let values: [Int]
	let localTotals: [Int]
	let sessionTotals: [Int]
	let totalRolls: Int
	let sum: Int
}

final class DiceRollSession {
	private var persistentTotals: [Int] = []
	private var sortedTotals: [Int] = []
	private var totalRolls = 0
	private var wasIntuitive = false
	private let intuitiveRoller: IntuitiveRoller

	init(intuitiveRoller: IntuitiveRoller = IntuitiveRoller()) {
		self.intuitiveRoller = intuitiveRoller
	}

	func roll(_ configuration: RollConfiguration) -> RollOutcome {
		if configuration.intuitive != wasIntuitive {
			persistentTotals = []
			sortedTotals = []
			totalRolls = 0
			wasIntuitive = configuration.intuitive
		}

		ensureCapacity(configuration.sideCount)
		sortedTotals = Array(persistentTotals.prefix(configuration.sideCount)).sorted(by: >)

		var values: [Int] = []
		values.reserveCapacity(configuration.diceCount)
		var localTotals = Array(repeating: 0, count: configuration.sideCount)

		for _ in 0..<configuration.diceCount {
			let roll = getDiceRoll(sideCount: configuration.sideCount, numDiceBeingRolled: configuration.diceCount, intuitive: configuration.intuitive)
			values.append(roll)
			let index = roll - 1
			localTotals[index] += 1
			persistentTotals[index] += 1
			totalRolls += 1
		}

		let sessionTotals = Array(persistentTotals.prefix(configuration.sideCount))
		sortedTotals = sessionTotals.sorted(by: >)
		let sum = values.reduce(0, +)

		return RollOutcome(values: values, localTotals: localTotals, sessionTotals: sessionTotals, totalRolls: totalRolls, sum: sum)
	}

	func reset() {
		persistentTotals = []
		sortedTotals = []
		totalRolls = 0
	}

	private func ensureCapacity(_ sideCount: Int) {
		if persistentTotals.count < sideCount {
			persistentTotals += Array(repeating: 0, count: sideCount - persistentTotals.count)
		}
		if sortedTotals.count < sideCount {
			sortedTotals += Array(repeating: 0, count: sideCount - sortedTotals.count)
		}
	}

	private func getDiceRoll(sideCount: Int, numDiceBeingRolled: Int, intuitive: Bool) -> Int {
		let context = IntuitiveRollContext(
			sideCount: sideCount,
			numDiceBeingRolled: numDiceBeingRolled,
			totalRolls: totalRolls,
			persistentTotals: persistentTotals,
			sortedTotals: sortedTotals
		)
		return intuitiveRoller.roll(context: context, intuitive: intuitive)
	}
}
