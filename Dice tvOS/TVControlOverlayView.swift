import UIKit

final class TVControlOverlayView: UIView {
	var onRoll: (() -> Void)?
	var onShowPresets: (() -> Void)?
	var onShowSettings: (() -> Void)?
	var onShowHelp: (() -> Void)?

	private let summaryContainer = UIView()
	private let summaryLabel = UILabel()
	private let actionContainer = UIView()
	private let actionStackView = UIStackView()
	private let rollButton = UIButton(type: .system)
	private let presetsButton = UIButton(type: .system)
	private let settingsButton = UIButton(type: .system)
	private let helpButton = UIButton(type: .system)

	override init(frame: CGRect) {
		super.init(frame: frame)
		configureHierarchy()
		configureButtons()
	}

	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	var primaryFocusableView: UIView {
		rollButton
	}

	var boardViewportInsets: UIEdgeInsets {
		let horizontalInset: CGFloat = 96
		let verticalPadding: CGFloat = 36
		let top = max(0, summaryContainer.frame.maxY + verticalPadding)
		let bottom = max(0, bounds.maxY - actionContainer.frame.minY + verticalPadding)
		return UIEdgeInsets(top: top, left: horizontalInset, bottom: bottom, right: horizontalInset)
	}

	func applyTheme() {
		backgroundColor = .clear
		summaryContainer.backgroundColor = UIColor(white: 0.08, alpha: 0.84)
		actionContainer.backgroundColor = UIColor(white: 0.08, alpha: 0.84)
		summaryLabel.textColor = .white
		configure(button: rollButton, title: NSLocalizedString("button.roll", comment: "Roll button title"))
		configure(button: presetsButton, title: NSLocalizedString("button.presets", comment: "Presets button title"))
		configure(button: settingsButton, title: NSLocalizedString("button.settings", comment: "Settings button title"))
		configure(button: helpButton, title: NSLocalizedString("button.help", comment: "Help button title"))
	}

	func updateSummary(notation: String) {
		summaryLabel.text = "\(notation)"
	}

	private func configureHierarchy() {
		translatesAutoresizingMaskIntoConstraints = false

		summaryContainer.translatesAutoresizingMaskIntoConstraints = false
		summaryContainer.layer.cornerRadius = 28
		summaryContainer.layer.cornerCurve = .continuous
		summaryContainer.clipsToBounds = true

		actionContainer.translatesAutoresizingMaskIntoConstraints = false
		actionContainer.layer.cornerRadius = 30
		actionContainer.layer.cornerCurve = .continuous
		actionContainer.clipsToBounds = true

		summaryLabel.translatesAutoresizingMaskIntoConstraints = false
		summaryLabel.font = UIFont.preferredFont(forTextStyle: .title3)
		summaryLabel.adjustsFontForContentSizeCategory = true
		summaryLabel.lineBreakMode = .byTruncatingMiddle

		actionStackView.translatesAutoresizingMaskIntoConstraints = false
		actionStackView.axis = .horizontal
		actionStackView.alignment = .fill
		actionStackView.distribution = .fillEqually
		actionStackView.spacing = 24

		addSubview(summaryContainer)
		addSubview(actionContainer)
		summaryContainer.addSubview(summaryLabel)
		actionContainer.addSubview(actionStackView)

		NSLayoutConstraint.activate([
			summaryContainer.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 40),
			summaryContainer.leadingAnchor.constraint(equalTo: safeAreaLayoutGuide.leadingAnchor, constant: 64),
			summaryContainer.trailingAnchor.constraint(lessThanOrEqualTo: safeAreaLayoutGuide.trailingAnchor, constant: -64),

			summaryLabel.topAnchor.constraint(equalTo: summaryContainer.topAnchor, constant: 20),
			summaryLabel.leadingAnchor.constraint(equalTo: summaryContainer.leadingAnchor, constant: 24),
			summaryLabel.trailingAnchor.constraint(equalTo: summaryContainer.trailingAnchor, constant: -24),
            summaryLabel.bottomAnchor.constraint(equalTo: summaryContainer.bottomAnchor, constant: -20),

			actionContainer.leadingAnchor.constraint(equalTo: safeAreaLayoutGuide.leadingAnchor, constant: 64),
			actionContainer.trailingAnchor.constraint(equalTo: safeAreaLayoutGuide.trailingAnchor, constant: -64),
			actionContainer.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -40),

			actionStackView.topAnchor.constraint(equalTo: actionContainer.topAnchor, constant: 20),
			actionStackView.leadingAnchor.constraint(equalTo: actionContainer.leadingAnchor, constant: 24),
			actionStackView.trailingAnchor.constraint(equalTo: actionContainer.trailingAnchor, constant: -24),
			actionStackView.bottomAnchor.constraint(equalTo: actionContainer.bottomAnchor, constant: -20),
		])
	}

	private func configureButtons() {
		configure(button: rollButton, title: NSLocalizedString("button.roll", comment: "Roll button title"), action: #selector(handleRoll))
		configure(button: presetsButton, title: NSLocalizedString("button.presets", comment: "Presets button title"), action: #selector(handleShowPresets))
		configure(button: settingsButton, title: NSLocalizedString("button.settings", comment: "Settings button title"), action: #selector(handleShowSettings))
		configure(button: helpButton, title: NSLocalizedString("button.help", comment: "Help button title"), action: #selector(handleShowHelp))

		rollButton.accessibilityIdentifier = "tvRollButton"
		presetsButton.accessibilityIdentifier = "tvPresetsButton"
		settingsButton.accessibilityIdentifier = "tvSettingsButton"
		helpButton.accessibilityIdentifier = "tvHelpButton"

		for button in [rollButton, presetsButton, settingsButton, helpButton] {
			button.translatesAutoresizingMaskIntoConstraints = false
			button.heightAnchor.constraint(greaterThanOrEqualToConstant: 72).isActive = true
			actionStackView.addArrangedSubview(button)
		}
	}

	private func configure(button: UIButton, title: String, action: Selector) {
		var configuration = UIButton.Configuration.borderedProminent()
		configuration.title = title
		configuration.cornerStyle = .capsule
		configuration.contentInsets = NSDirectionalEdgeInsets(top: 18, leading: 28, bottom: 18, trailing: 28)
		button.configuration = configuration
		button.addTarget(self, action: action, for: .primaryActionTriggered)
	}

	private func configure(button: UIButton, title: String) {
		guard var configuration = button.configuration else { return }
		configuration.title = title
		configuration.baseForegroundColor = .white
		configuration.baseBackgroundColor = UIColor(white: 0.16, alpha: 0.94)
		button.configuration = configuration
	}

	@objc private func handleRoll() {
		onRoll?()
	}

	@objc private func handleShowPresets() {
		onShowPresets?()
	}

	@objc private func handleShowSettings() {
		onShowSettings?()
	}

	@objc private func handleShowHelp() {
		onShowHelp?()
	}
}
