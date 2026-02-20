import Foundation

struct HistoryRowFormatter {
	static func subtitle(for entry: RollHistoryEntry, dateFormatter: DateFormatter) -> String {
		let time = String(
			format: NSLocalizedString("history.row.time", comment: "History row time label"),
			dateFormatter.string(from: entry.timestamp)
		)
		let values = String(
			format: NSLocalizedString("history.row.values", comment: "History row values label"),
			entry.values.map(String.init).joined(separator: ", ")
		)
		return "\(time) • \(values)"
	}
}
