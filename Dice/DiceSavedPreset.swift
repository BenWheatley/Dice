import Foundation

struct DiceSavedPreset: Codable, Equatable, Identifiable {
	let id: String
	var title: String
	var notation: String
	var pinned: Bool

	init(id: String = UUID().uuidString, title: String, notation: String, pinned: Bool = false) {
		self.id = id
		self.title = title
		self.notation = notation
		self.pinned = pinned
	}
}
