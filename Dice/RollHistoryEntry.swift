import Foundation

struct RollHistoryEntry: Codable, Equatable {
	let timestamp: Date
	let notation: String
	let values: [Int]
	let sum: Int
	let intuitive: Bool
}
