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

enum RollHistoryExportFormat {
	case text
	case csv
}

struct RollHistoryExporter {
	func export(_ entries: [RollHistoryEntry], format: RollHistoryExportFormat) -> String {
		switch format {
		case .text:
			return exportText(entries)
		case .csv:
			return exportCSV(entries)
		}
	}

	private func exportText(_ entries: [RollHistoryEntry]) -> String {
		let formatter = ISO8601DateFormatter()
		return entries.map { entry in
			let mode = entry.intuitive ? "intuitive" : "true-random"
			return "\(formatter.string(from: entry.timestamp)) | \(entry.notation) | \(mode) | values=\(entry.values) | sum=\(entry.sum)"
		}.joined(separator: "\n")
	}

	private func exportCSV(_ entries: [RollHistoryEntry]) -> String {
		let formatter = ISO8601DateFormatter()
		var lines = ["timestamp,notation,mode,values,sum"]
		for entry in entries {
			let mode = entry.intuitive ? "intuitive" : "true-random"
			let values = entry.values.map(String.init).joined(separator: " ")
			lines.append("\(formatter.string(from: entry.timestamp)),\(entry.notation),\(mode),\"\(values)\",\(entry.sum)")
		}
		return lines.joined(separator: "\n")
	}
}

