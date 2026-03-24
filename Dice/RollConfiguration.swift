import Foundation

struct RollConfiguration {
	let pools: [DicePool]

	init(diceCount: Int, sideCount: Int, intuitive: Bool) {
		self.pools = [DicePool(diceCount: diceCount, sideCount: sideCount, intuitive: intuitive)]
	}

	init(pools: [DicePool], intuitive: Bool) {
		self.pools = pools.map {
			DicePool(
				diceCount: $0.diceCount,
				sideCount: $0.sideCount,
				intuitive: intuitive,
				colorTag: $0.colorTag
			)
		}
	}

	init(pools: [DicePool]) {
		self.pools = pools
	}

	var intuitive: Bool {
		pools.allSatisfy(\.intuitive)
	}

	var hasIntuitivePools: Bool {
		pools.contains(where: \.intuitive)
	}

	var hasTrueRandomPools: Bool {
		pools.contains(where: { !$0.intuitive })
	}

	var perDieIntuitiveFlags: [Bool] {
		var flags: [Bool] = []
		flags.reserveCapacity(diceCount)
		for pool in pools {
			flags.append(contentsOf: Array(repeating: pool.intuitive, count: pool.diceCount))
		}
		return flags
	}

	var perDieColorTags: [String?] {
		var tags: [String?] = []
		tags.reserveCapacity(diceCount)
		for pool in pools {
			tags.append(contentsOf: Array(repeating: pool.colorTag, count: pool.diceCount))
		}
		return tags
	}

	var modeSignature: String {
		pools.map { $0.intuitive ? "i" : "r" }.joined(separator: ",")
	}

	var diceCount: Int {
		pools.reduce(0) { $0 + $1.diceCount }
	}

	var sideCount: Int {
		pools.first?.sideCount ?? 6
	}

	var uniformSideCount: Int? {
		guard let first = pools.first?.sideCount else { return nil }
		return pools.dropFirst().allSatisfy { $0.sideCount == first } ? first : nil
	}

	var sideCountsPerDie: [Int] {
		var result: [Int] = []
		result.reserveCapacity(diceCount)
		for pool in pools {
			result.append(contentsOf: Array(repeating: pool.sideCount, count: pool.diceCount))
		}
		return result
	}

	var notation: String {
		pools
			.map {
				let color = $0.colorTag.map { "(\($0))" } ?? ""
				return "\($0.diceCount)d\($0.sideCount)\($0.intuitive ? "i" : "")\(color)"
			}
			.joined(separator: "+")
	}
}
