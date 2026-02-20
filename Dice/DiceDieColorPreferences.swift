import UIKit

struct DiceDieColorPreferences: Equatable {
	static let supportedSideCounts = [4, 6, 8, 10, 12, 20]

	private(set) var presetsBySideCount: [Int: DiceDieColorPreset]

	init(presetsBySideCount: [Int: DiceDieColorPreset]) {
		self.presetsBySideCount = presetsBySideCount
		for sideCount in Self.supportedSideCounts where self.presetsBySideCount[sideCount] == nil {
			self.presetsBySideCount[sideCount] = .ivory
		}
	}

	static let `default` = DiceDieColorPreferences(presetsBySideCount: [:])

	func preset(for sideCount: Int) -> DiceDieColorPreset {
		presetsBySideCount[sideCount] ?? .ivory
	}

	func fillColor(for sideCount: Int) -> UIColor {
		preset(for: sideCount).fillColor
	}

	func updated(sideCount: Int, preset: DiceDieColorPreset) -> DiceDieColorPreferences {
		var updated = presetsBySideCount
		updated[sideCount] = preset
		return DiceDieColorPreferences(presetsBySideCount: updated)
	}

	func serialized() -> [String: String] {
		var map: [String: String] = [:]
		for sideCount in Self.supportedSideCounts {
			map[String(sideCount)] = preset(for: sideCount).rawValue
		}
		return map
	}

	static func deserialize(_ raw: [String: String]) -> DiceDieColorPreferences {
		var map: [Int: DiceDieColorPreset] = [:]
		for sideCount in supportedSideCounts {
			if let rawValue = raw[String(sideCount)], let preset = DiceDieColorPreset(rawValue: rawValue) {
				map[sideCount] = preset
			}
		}
		return DiceDieColorPreferences(presetsBySideCount: map)
	}
}
