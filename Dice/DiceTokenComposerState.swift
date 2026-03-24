import Foundation

struct DiceTokenComposerState: Equatable {
	static let commonSideCounts = [2, 3, 4, 6, 8, 10, 12, 20, 100]
	static let commonRolls = ["1d20", "2d6", "3d6", "6d6"]

	private(set) var pools: [DicePool]

	init(configuration: RollConfiguration) {
		pools = configuration.pools.isEmpty ? [Self.defaultPool] : configuration.pools
	}

	var configuration: RollConfiguration {
		RollConfiguration(pools: pools)
	}

	var notation: String {
		configuration.notation
	}

	static func quickRollNotations(recent: [String]) -> [String] {
		var ordered: [String] = []
		for notation in commonRolls + recent {
			guard !ordered.contains(where: { $0.caseInsensitiveCompare(notation) == .orderedSame }) else { continue }
			ordered.append(notation)
		}
		return ordered
	}

	mutating func addPool(_ pool: DicePool = defaultPool) {
		pools.append(pool)
	}

	mutating func replacePool(at index: Int, with pool: DicePool) {
		guard pools.indices.contains(index) else { return }
		pools[index] = pool
	}

	mutating func removePool(at index: Int) {
		guard pools.indices.contains(index), pools.count > 1 else { return }
		pools.remove(at: index)
	}

	mutating func setDiceCount(_ count: Int, at index: Int) {
		updatePool(at: index) { pool in
			DicePool(diceCount: max(1, min(30, count)), sideCount: pool.sideCount, intuitive: pool.intuitive, colorTag: pool.colorTag)
		}
	}

	mutating func setSideCount(_ sideCount: Int, at index: Int) {
		updatePool(at: index) { pool in
			DicePool(diceCount: pool.diceCount, sideCount: max(2, min(100, sideCount)), intuitive: pool.intuitive, colorTag: pool.colorTag)
		}
	}

	mutating func setIntuitive(_ intuitive: Bool, at index: Int) {
		updatePool(at: index) { pool in
			DicePool(diceCount: pool.diceCount, sideCount: pool.sideCount, intuitive: intuitive, colorTag: pool.colorTag)
		}
	}

	mutating func setColor(_ preset: DiceDieColorPreset?, at index: Int) {
		updatePool(at: index) { pool in
			DicePool(diceCount: pool.diceCount, sideCount: pool.sideCount, intuitive: pool.intuitive, colorTag: preset?.notationName)
		}
	}

	func stepSideCount(from currentSideCount: Int, delta: Int) -> Int {
		let values = Self.commonSideCounts
		let currentIndex = values.firstIndex(of: currentSideCount) ?? values.firstIndex(of: 6) ?? 0
		let nextIndex = max(0, min(values.count - 1, currentIndex + delta))
		return values[nextIndex]
	}

	static func displayTitle(for pool: DicePool) -> String {
		let countPrefix = pool.diceCount == 1 ? "" : "\(pool.diceCount)"
		return "\(countPrefix)d\(pool.sideCount)"
	}

	static func displaySubtitle(for pool: DicePool) -> String {
		let mode = pool.intuitive
			? NSLocalizedString("stats.mode.intuitive", comment: "Intuitive roll mode")
			: NSLocalizedString("stats.mode.trueRandom", comment: "True random roll mode")
		if let colorTag = pool.colorTag, let preset = DiceDieColorPreset.fromNotation(colorTag) {
			return "\(mode) • \(NSLocalizedString(preset.menuTitleKey, comment: "Die color preset"))"
		}
		return "\(mode) • \(NSLocalizedString("tvos.diceComposer.color.default", comment: "Default die color"))"
	}

	private mutating func updatePool(at index: Int, transform: (DicePool) -> DicePool) {
		guard pools.indices.contains(index) else { return }
		pools[index] = transform(pools[index])
	}

	private static let defaultPool = DicePool(diceCount: 1, sideCount: 6, intuitive: false)
}
