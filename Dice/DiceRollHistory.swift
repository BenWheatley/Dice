//
//  DiceRollHistory.swift
//  Dice
//
//  Created by Codex on 16.02.26.
//

import Foundation

/// Retention policy:
/// - sessionEntries: full in-memory history for the active window/session
/// - persistedRecentEntries: bounded recent history intended for persistence
final class DiceRollHistory {
	private(set) var sessionEntries: [RollHistoryEntry]
	private(set) var persistedRecentEntries: [RollHistoryEntry]
	let maxPersistedEntries: Int

	init(
		sessionEntries: [RollHistoryEntry] = [],
		persistedRecentEntries: [RollHistoryEntry] = [],
		maxPersistedEntries: Int = 200
	) {
		self.sessionEntries = sessionEntries
		self.persistedRecentEntries = Array(persistedRecentEntries.prefix(maxPersistedEntries))
		self.maxPersistedEntries = maxPersistedEntries
	}

	func append(_ entry: RollHistoryEntry, persist: Bool = true) {
		sessionEntries.insert(entry, at: 0)
		guard persist else { return }
		persistedRecentEntries.insert(entry, at: 0)
		if persistedRecentEntries.count > maxPersistedEntries {
			persistedRecentEntries.removeLast(persistedRecentEntries.count - maxPersistedEntries)
		}
	}

	func clearSession() {
		sessionEntries.removeAll()
	}

	func clearPersistedRecent() {
		persistedRecentEntries.removeAll()
	}
}
