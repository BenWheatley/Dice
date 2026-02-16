//
//  DiceTelemetry.swift
//  Dice
//
//  Created by Codex on 16.02.26.
//

import Foundation
import os

final class DiceTelemetry {
	private let logger = Logger(subsystem: "com.kitsunesoftware.Dice", category: "telemetry")

	func logRoll(configuration: RollConfiguration, sum: Int, diceCount: Int) {
		logger.info("roll mode=\(configuration.intuitive ? "intuitive" : "true-random") notation=\(configuration.notation, privacy: .public) sum=\(sum) dice=\(diceCount)")
	}

	func logInvalidInput(_ text: String, reason: String) {
		logger.error("invalid_input input=\(text, privacy: .public) reason=\(reason, privacy: .public)")
	}

	func logStatsReset() {
		logger.info("stats_reset")
	}
}

