//
//  DiceWidgetSnapshotStore.swift
//  Dice
//
//  Created by Codex on 27.02.26.
//

import Foundation

enum DiceWidgetModeToken: String, Codable {
	case trueRandom
	case intuitive
}

enum DiceWidgetThemeToken: String, Codable {
	case system
	case lightMode
	case darkMode
}

struct DiceWidgetRollSnapshot: Equatable {
	let notation: String
	let lastTotal: Int
	let modeToken: DiceWidgetModeToken
	let recentTotals: [Int]
	let isEmptyState: Bool
	let themeToken: DiceWidgetThemeToken
}

final class DiceWidgetSnapshotStore {
	private enum Keys {
		static let lastNotation = "Dice.lastNotation"
		static let persistedHistory = "Dice.persistedHistory"
		static let theme = "Dice.theme"
	}

	private let defaults: UserDefaults
	private let decoder: JSONDecoder

	init(defaults: UserDefaults = .standard) {
		self.defaults = defaults
		self.decoder = JSONDecoder()
		self.decoder.dateDecodingStrategy = .iso8601
	}

	func loadSnapshot() -> DiceWidgetRollSnapshot {
		let notation = defaults.string(forKey: Keys.lastNotation) ?? "6d6"
		let entries = loadPersistedEntries()
		let latest = entries.last
		let recent = entries.suffix(3).reversed().map(\.sum)
		let themeToken = DiceWidgetThemeToken(rawValue: defaults.string(forKey: Keys.theme) ?? "") ?? .system

		return DiceWidgetRollSnapshot(
			notation: notation,
			lastTotal: latest?.sum ?? 0,
			modeToken: latest?.intuitive == true ? .intuitive : .trueRandom,
			recentTotals: recent,
			isEmptyState: entries.isEmpty,
			themeToken: themeToken
		)
	}

	private func loadPersistedEntries() -> [RollHistoryEntry] {
		guard
			let data = defaults.data(forKey: Keys.persistedHistory),
			let entries = try? decoder.decode([RollHistoryEntry].self, from: data)
		else {
			return []
		}
		return entries
	}
}
