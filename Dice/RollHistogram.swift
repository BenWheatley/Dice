import Foundation

struct RollHistogram: Equatable {
	let sideCount: Int
	let bins: [Int]
	let totalSamples: Int
}
