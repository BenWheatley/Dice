import UIKit

struct DiceMotionBehaviorProfile: Equatable {
	let duration: TimeInterval
	let motionScale: Float
	let liftMultiplier: Float
	let oscillationAmplitude: Float

	static func resolve(intensity: DiceAnimationIntensity, reduceMotionEnabled: Bool) -> DiceMotionBehaviorProfile {
		switch intensity {
		case .off:
			return DiceMotionBehaviorProfile(duration: 0, motionScale: 0, liftMultiplier: 0, oscillationAmplitude: 0)
		case .full:
			if reduceMotionEnabled {
				return DiceMotionBehaviorProfile(duration: 0.85, motionScale: 0.45, liftMultiplier: 0.55, oscillationAmplitude: 0.14)
			}
			return DiceMotionBehaviorProfile(duration: 1.6, motionScale: 1.0, liftMultiplier: 1.35, oscillationAmplitude: 0.28)
		}
	}
}
