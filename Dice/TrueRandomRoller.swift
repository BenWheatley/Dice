//
//  TrueRandomRoller.swift
//  Dice
//
//  Created by Codex on 16.02.26.
//

import Foundation

struct TrueRandomRoller {
	let randomInt: (ClosedRange<Int>) -> Int

	init(randomInt: @escaping (ClosedRange<Int>) -> Int = { Int.random(in: $0) }) {
		self.randomInt = randomInt
	}

	func roll(sideCount: Int) -> Int {
		randomInt(1...sideCount)
	}
}

