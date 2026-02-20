//
//  DiceRollHistoryStore.swift
//  Dice
//
//  Created by Codex on 16.02.26.
//

import Foundation

final class DiceRollHistoryStore {
	private enum Keys {
		static let persistedHistory = "Dice.persistedHistory"
	}

	private let defaults: UserDefaults
	private let encoder = JSONEncoder()
	private let decoder = JSONDecoder()

	init(defaults: UserDefaults = .standard) {
		self.defaults = defaults
		encoder.dateEncodingStrategy = .iso8601
		decoder.dateDecodingStrategy = .iso8601
	}

	func loadPersistedEntries() -> [RollHistoryEntry] {
		guard
			let data = defaults.data(forKey: Keys.persistedHistory),
			let entries = try? decoder.decode([RollHistoryEntry].self, from: data)
		else {
			return []
		}
		return entries
	}

	func savePersistedEntries(_ entries: [RollHistoryEntry]) {
		guard let data = try? encoder.encode(entries) else { return }
		defaults.set(data, forKey: Keys.persistedHistory)
	}
}
