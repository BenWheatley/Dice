//
//  DiceRollSession.swift
//  Dice
//
//  Created by Codex on 16.02.26.
//

import Foundation

struct D6FaceOrientation {
	static func eulerAngles(for value: Int) -> (x: Float, y: Float, z: Float) {
		switch value {
		case 1:
			return (0, 0, 0)
		case 2:
			return (0, -Float.pi / 2, 0)
		case 3:
			return (0, Float.pi, 0)
		case 4:
			return (0, Float.pi / 2, 0)
		case 5:
			return (Float.pi / 2, 0, 0)
		case 6:
			return (-Float.pi / 2, 0, 0)
		default:
			return (0, 0, 0)
		}
	}
}

struct RollOutcome {
	let values: [Int]
	let sideCounts: [Int]
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

		let maxSideCount = configuration.pools.map(\.sideCount).max() ?? configuration.sideCount
		ensureCapacity(maxSideCount)
		sortedTotals = Array(persistentTotals.prefix(maxSideCount)).sorted(by: >)

		var values: [Int] = []
		values.reserveCapacity(configuration.diceCount)
		var sideCounts: [Int] = []
		sideCounts.reserveCapacity(configuration.diceCount)
		var localTotals = Array(repeating: 0, count: maxSideCount)

		for pool in configuration.pools {
			for _ in 0..<pool.diceCount {
				let roll = getDiceRoll(sideCount: pool.sideCount, numDiceBeingRolled: pool.diceCount, intuitive: configuration.intuitive)
				values.append(roll)
				sideCounts.append(pool.sideCount)
				let index = roll - 1
				localTotals[index] += 1
				persistentTotals[index] += 1
				totalRolls += 1
			}
		}

		let sessionTotals = Array(persistentTotals.prefix(maxSideCount))
		sortedTotals = sessionTotals.sorted(by: >)
		let sum = values.reduce(0, +)

		return RollOutcome(values: values, sideCounts: sideCounts, localTotals: localTotals, sessionTotals: sessionTotals, totalRolls: totalRolls, sum: sum)
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
