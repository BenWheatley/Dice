import Foundation

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
