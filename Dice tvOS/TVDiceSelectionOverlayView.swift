import UIKit

final class TVDiceSelectionOverlayView: UIView {
	var onSelectDie: ((Int) -> Void)?
	var onFocusedDie: ((Int?) -> Void)?

	private let focusRingView = UIView()
	private var dieButtons: [UIButton] = []
	private var preferredFocusedDieIndex: Int?

	override init(frame: CGRect) {
		super.init(frame: frame)
		configureView()
	}

	required init?(coder: NSCoder) {
		super.init(coder: coder)
		configureView()
	}

	var primaryFocusableView: UIView? {
		if let preferredFocusedDieIndex,
		   dieButtons.indices.contains(preferredFocusedDieIndex),
		   dieButtons[preferredFocusedDieIndex].isHidden == false {
			return dieButtons[preferredFocusedDieIndex]
		}
		return dieButtons.first(where: { $0.isHidden == false })
	}

	func updateDiceTargets(centers: [CGPoint], sideLength: CGFloat) {
		ensureButtonCount(centers.count)
		let focusDiameter = max(96, sideLength * 1.18)
		for (index, center) in centers.enumerated() {
			let button = dieButtons[index]
			button.tag = index
			button.isHidden = false
			button.frame = CGRect(
				x: center.x - focusDiameter / 2,
				y: center.y - focusDiameter / 2,
				width: focusDiameter,
				height: focusDiameter
			).integral
			button.accessibilityIdentifier = "tvDieButton_\(index)"
		}

		if dieButtons.count > centers.count {
			for button in dieButtons[centers.count...] {
				button.isHidden = true
			}
		}

		guard let focusedButton = focusedDieButton() else {
			focusRingView.alpha = 0
			return
		}
		updateFocusRing(for: focusedButton)
	}

	func setPreferredFocusedDieIndex(_ index: Int?) {
		preferredFocusedDieIndex = index
	}

	override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
		super.didUpdateFocus(in: context, with: coordinator)

		let nextButton = (context.nextFocusedView as? UIButton).flatMap { button in
			dieButtons.contains(button) ? button : nil
		}
		if let nextButton {
			preferredFocusedDieIndex = nextButton.tag
		}

		coordinator.addCoordinatedAnimations({ [weak self] in
			guard let self else { return }
			if let button = nextButton {
				self.updateFocusRing(for: button)
				self.focusRingView.alpha = 1
				self.onFocusedDie?(button.tag)
			} else {
				self.focusRingView.alpha = 0
				self.onFocusedDie?(nil)
			}
		})
	}

	private func configureView() {
		translatesAutoresizingMaskIntoConstraints = false
		backgroundColor = .clear

		focusRingView.isUserInteractionEnabled = false
		focusRingView.alpha = 0
		focusRingView.layer.borderWidth = 6
		focusRingView.layer.borderColor = UIColor.systemBlue.withAlphaComponent(0.92).cgColor
		focusRingView.layer.shadowColor = UIColor.systemBlue.cgColor
		focusRingView.layer.shadowOpacity = 0.45
		focusRingView.layer.shadowRadius = 20
		focusRingView.layer.shadowOffset = .zero
		addSubview(focusRingView)
	}

	private func ensureButtonCount(_ count: Int) {
		while dieButtons.count < count {
			let button = UIButton(type: .custom)
			button.backgroundColor = .clear
			button.addTarget(self, action: #selector(handleDieSelection(_:)), for: .primaryActionTriggered)
			addSubview(button)
			dieButtons.append(button)
		}
	}

	private func focusedDieButton() -> UIButton? {
		guard let preferredFocusedDieIndex,
			  dieButtons.indices.contains(preferredFocusedDieIndex) else {
			return nil
		}
		let button = dieButtons[preferredFocusedDieIndex]
		return button.isHidden ? nil : button
	}

	private func updateFocusRing(for button: UIButton) {
		let ringFrame = button.frame.insetBy(dx: -12, dy: -12)
		bringSubviewToFront(focusRingView)
		focusRingView.frame = ringFrame
		focusRingView.layer.cornerRadius = ringFrame.width / 2
	}

	@objc private func handleDieSelection(_ sender: UIButton) {
		preferredFocusedDieIndex = sender.tag
		onSelectDie?(sender.tag)
	}
}
