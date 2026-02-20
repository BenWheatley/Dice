import UIKit

final class DiceHapticsEngine {
	private let impact = UIImpactFeedbackGenerator(style: .medium)
	private let settle = UIImpactFeedbackGenerator(style: .soft)
	private let invalid = UINotificationFeedbackGenerator()

	func playRollImpact() {
		impact.prepare()
		impact.impactOccurred(intensity: 0.85)
	}

	func playRollSettle() {
		settle.prepare()
		settle.impactOccurred(intensity: 0.65)
	}

	func playInvalidInput() {
		invalid.notificationOccurred(.warning)
	}
}
