import Foundation
import SceneKit

enum DiceRollAnimationMath {
	static func clampedUnitProgress(_ progress: Float) -> Float {
		max(0, min(1, progress))
	}

	static func settleProgress(_ progress: Float) -> Float {
		let clamped = clampedUnitProgress(progress)
		return 1 - powf(1 - clamped, 3)
	}

	static func residualSpin(_ progress: Float) -> Float {
		powf(1 - clampedUnitProgress(progress), 3)
	}

	static func randomTurnRadians(min: Int, max: Int, motionScale: Float = 1) -> Float {
		let turns = Float(Int.random(in: min...max))
		let sign: Float = Bool.random() ? 1 : -1
		return turns * sign * Float.pi * 2 * motionScale
	}

	static func cylindricalEulerAngles(
		targetOrientation: SCNVector3,
		progress: Float,
		motionScale: Float,
		spinDirection: Float
	) -> SCNVector3 {
		let clamped = clampedUnitProgress(progress)
		let turns = max(2, Int(round(3.0 * Double(max(0.5, motionScale)))))
		let spinMagnitude = Float(turns) * spinDirection * Float.pi * 2
		let tilt = settleProgress(clamped)
		let spin = residualSpin(clamped)
		return SCNVector3(
			targetOrientation.x * tilt,
			targetOrientation.y * tilt,
			targetOrientation.z + (spinMagnitude * spin)
		)
	}
}
