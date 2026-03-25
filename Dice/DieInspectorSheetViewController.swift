import UIKit

final class DieInspectorSheetViewController: UIViewController {
	private static let sideCountBounds = 2...100

	private enum Palette {
		static let screenBackground = UIColor { trait in
			switch trait.userInterfaceStyle {
			case .dark:
				return UIColor(red: 0.10, green: 0.11, blue: 0.13, alpha: 1.0)
			default:
				return UIColor(white: 1.0, alpha: 1.0)
			}
		}

		static let sectionBackground = UIColor { trait in
			switch trait.userInterfaceStyle {
			case .dark:
				return UIColor(red: 0.18, green: 0.20, blue: 0.23, alpha: 1.0)
			default:
				return UIColor(red: 0.95, green: 0.95, blue: 0.97, alpha: 1.0)
			}
		}

		static let secondaryButtonBackground = UIColor { trait in
			switch trait.userInterfaceStyle {
			case .dark:
				return UIColor(red: 0.22, green: 0.24, blue: 0.27, alpha: 1.0)
			default:
				return UIColor(red: 0.92, green: 0.92, blue: 0.94, alpha: 1.0)
			}
		}

		static let disabledPrimaryBackground = UIColor { trait in
			switch trait.userInterfaceStyle {
			case .dark:
				return UIColor(red: 0.30, green: 0.31, blue: 0.34, alpha: 1.0)
			default:
				return UIColor(red: 0.78, green: 0.79, blue: 0.83, alpha: 1.0)
			}
		}

		static let disabledPrimaryForeground = UIColor { trait in
			switch trait.userInterfaceStyle {
			case .dark:
				return UIColor(red: 0.74, green: 0.77, blue: 0.81, alpha: 1.0)
			default:
				return UIColor(red: 0.42, green: 0.44, blue: 0.48, alpha: 1.0)
			}
		}
	}

	enum StyleSectionKind: Equatable {
		case d6Pips
		case numeralFont
	}

	struct State {
		let dieIndex: Int
		let sideCount: Int
		let isLocked: Bool
		let selectedColor: DiceDieColorPreset
		let d6PipStyle: DiceD6PipStyle
		let selectedFont: DiceFaceNumeralFont
	}

	var onReroll: (() -> Void)?
	var onToggleLock: (() -> Void)?
	var onSetColor: ((DiceDieColorPreset) -> Void)?
	var onSetD6PipStyle: ((DiceD6PipStyle) -> Void)?
	var onSetFaceNumeralFont: ((DiceFaceNumeralFont) -> Void)?
	var onSetSideCount: ((Int) -> Void)?
	var onDismiss: (() -> Void)?

	private let scrollView = UIScrollView()
	private let stackView = UIStackView()
	private let rerollButton = UIButton(type: .system)
	private let lockButton = UIButton(type: .system)
	private let sideCountTextField = UITextField()
	private let styleSegmentedControl = UISegmentedControl(items: [])
	private let styleSectionTitleLabel = UILabel()
	private var colorButtons: [DiceDieColorPreset: UIButton] = [:]
	private var didNotifyDismiss = false
	private var state: State

	init(state: State) {
		self.state = state
		super.init(nibName: nil, bundle: nil)
	}

	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	override func viewDidLoad() {
		super.viewDidLoad()
		view.backgroundColor = Palette.screenBackground
		view.accessibilityIdentifier = "dieInspectorSheet"
#if os(tvOS)
		navigationItem.rightBarButtonItem = UIBarButtonItem(
			title: NSLocalizedString("button.close", comment: "Close button title"),
			style: .done,
			target: self,
			action: #selector(closeSheet)
		)
#else
		navigationItem.rightBarButtonItem = UIBarButtonItem(
			barButtonSystemItem: .close,
			target: self,
			action: #selector(closeSheet)
		)
#endif
		configureLayout()
		applyState()
	}

	override func viewDidDisappear(_ animated: Bool) {
		super.viewDidDisappear(animated)
		let dismissed = isBeingDismissed || navigationController?.isBeingDismissed == true
		if dismissed {
			notifyDismissIfNeeded()
		}
	}

	func updateState(_ state: State) {
		self.state = state
		if isViewLoaded {
			applyState()
		}
	}

	static func styleSectionKind(for sideCount: Int) -> StyleSectionKind {
		sideCount == 6 ? .d6Pips : .numeralFont
	}

	@objc private func closeSheet() {
		notifyDismissIfNeeded()
		dismiss(animated: true)
	}

	@objc private func rerollTapped() {
		onReroll?()
	}

	@objc private func lockTapped() {
		onToggleLock?()
	}

	@objc private func styleChanged() {
		switch Self.styleSectionKind(for: state.sideCount) {
		case .d6Pips:
			guard DiceD6PipStyle.allCases.indices.contains(styleSegmentedControl.selectedSegmentIndex) else { return }
			onSetD6PipStyle?(DiceD6PipStyle.allCases[styleSegmentedControl.selectedSegmentIndex])
		case .numeralFont:
			guard DiceFaceNumeralFont.allCases.indices.contains(styleSegmentedControl.selectedSegmentIndex) else { return }
			onSetFaceNumeralFont?(DiceFaceNumeralFont.allCases[styleSegmentedControl.selectedSegmentIndex])
		}
	}

    @objc private func sideCountEditingChanged() {
        let text = sideCountTextField.text?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        // Convert safely, default to 2 if nil or invalid, then clip to range 2-100 inclusive
        var sideCount = Int(text ?? "") ?? 2
        sideCount = max(2, min(sideCount, 100))
        
        // Reflect corrected value back into the text field
        sideCountTextField.text = "\(sideCount)"
        
        onSetSideCount?(sideCount)
    }

	private func configureLayout() {
		scrollView.translatesAutoresizingMaskIntoConstraints = false
		stackView.translatesAutoresizingMaskIntoConstraints = false
		stackView.axis = .vertical
		stackView.spacing = 14

		view.addSubview(scrollView)
		scrollView.addSubview(stackView)

		NSLayoutConstraint.activate([
			scrollView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
			scrollView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
			scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
			scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
			stackView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 16),
			stackView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -16),
			stackView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 16),
			stackView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -16),
			stackView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -32),
		])

		configureActionSection()
		configureSideCountSection()
		configureColorSection()
		configureStyleSection()
	}

	private func configureActionSection() {
		let section = makeSection(titleKey: "menu.control.actions")
		let body = section.body

		var rerollConfig = UIButton.Configuration.filled()
		rerollConfig.title = NSLocalizedString("die.options.reroll", comment: "Reroll one die action")
		rerollConfig.cornerStyle = .large
		rerollConfig.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12)
		rerollButton.configuration = rerollConfig
		rerollButton.accessibilityIdentifier = "dieInspectorRerollButton"
		rerollButton.addTarget(self, action: #selector(rerollTapped), for: .touchUpInside)

		var lockConfig = UIButton.Configuration.gray()
		lockConfig.cornerStyle = .large
		lockConfig.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12)
		lockButton.configuration = lockConfig
		lockButton.accessibilityIdentifier = "dieInspectorLockButton"
		lockButton.addTarget(self, action: #selector(lockTapped), for: .touchUpInside)

		body.addArrangedSubview(rerollButton)
		body.addArrangedSubview(lockButton)
		stackView.addArrangedSubview(section.container)
	}

	private func configureSideCountSection() {
		let section = makeSection(titleKey: "die.options.faces")
		let body = section.body

		sideCountTextField.borderStyle = .roundedRect
		sideCountTextField.clearButtonMode = .whileEditing
		sideCountTextField.accessibilityIdentifier = "dieInspectorSideCountField"
		sideCountTextField.addTarget(self, action: #selector(sideCountEditingChanged), for: .editingChanged)
		sideCountTextField.keyboardType = .numberPad
        sideCountTextField.delegate = self
        
		body.addArrangedSubview(sideCountTextField)
		stackView.addArrangedSubview(section.container)
	}

	private func configureColorSection() {
		let section = makeSection(titleKey: "die.options.color")
		let body = section.body
		let presets = DiceDieColorPreset.allCases
		let columns = 3
		var rowStack: UIStackView?
		for (index, preset) in presets.enumerated() {
			if index % columns == 0 {
				let row = UIStackView()
				row.axis = .horizontal
				row.spacing = 8
				row.distribution = .fillEqually
				body.addArrangedSubview(row)
				rowStack = row
			}
			let button = UIButton(type: .system)
			var config = UIButton.Configuration.gray()
			config.title = NSLocalizedString(preset.menuTitleKey, comment: "Die color option")
			config.cornerStyle = .medium
			config.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8)
			button.configuration = config
			button.titleLabel?.adjustsFontForContentSizeCategory = true
			button.accessibilityIdentifier = "dieInspectorColor_\(preset.rawValue)"
			button.addAction(UIAction { [weak self] _ in
				guard let self else { return }
				self.onSetColor?(preset)
			}, for: .touchUpInside)
			rowStack?.addArrangedSubview(button)
			colorButtons[preset] = button
		}
		if let rowStack, rowStack.arrangedSubviews.count < columns {
			for _ in rowStack.arrangedSubviews.count..<columns {
				let spacer = UIView()
				rowStack.addArrangedSubview(spacer)
			}
		}
		stackView.addArrangedSubview(section.container)
	}

	private func configureStyleSection() {
		let section = makeSection(titleKey: "die.options.font", customTitleLabel: styleSectionTitleLabel)
		let body = section.body
		styleSegmentedControl.addTarget(self, action: #selector(styleChanged), for: .valueChanged)
		styleSegmentedControl.accessibilityIdentifier = "dieInspectorStyleSegmentedControl"
		body.addArrangedSubview(styleSegmentedControl)
		stackView.addArrangedSubview(section.container)
	}

	private func applyState() {
		title = String(
			format: NSLocalizedString("die.options.title", comment: "Per-die options title"),
			state.dieIndex + 1,
			state.sideCount
		)

		rerollButton.isEnabled = !state.isLocked
		var rerollConfig = rerollButton.configuration
		rerollConfig?.baseBackgroundColor = state.isLocked ? Palette.disabledPrimaryBackground : .systemBlue
		rerollConfig?.baseForegroundColor = state.isLocked ? Palette.disabledPrimaryForeground : .white
		rerollButton.configuration = rerollConfig

		var lockConfig = lockButton.configuration
		lockConfig?.title = NSLocalizedString(state.isLocked ? "die.options.unlock" : "die.options.lock", comment: "Toggle lock action")
		lockConfig?.image = UIImage(systemName: state.isLocked ? "lock.open" : "lock")
		lockConfig?.imagePlacement = .leading
		lockConfig?.imagePadding = 6
		lockButton.configuration = lockConfig

		for (preset, button) in colorButtons {
			var config = button.configuration
			let isSelected = preset == state.selectedColor
			config?.baseBackgroundColor = isSelected ? .systemBlue : Palette.secondaryButtonBackground
			config?.baseForegroundColor = isSelected ? .white : .label
			config?.background.strokeColor = isSelected ? UIColor.systemBlue : UIColor.separator
			config?.background.strokeWidth = 1
			button.configuration = config
		}

		if !sideCountTextField.isFirstResponder {
			sideCountTextField.text = String(state.sideCount)
		}
		sideCountTextField.placeholder = String(
			format: NSLocalizedString("die.options.faces.placeholder", comment: "Side-count entry placeholder"),
			state.sideCount
		)

		styleSegmentedControl.removeAllSegments()
		switch Self.styleSectionKind(for: state.sideCount) {
		case .d6Pips:
			styleSectionTitleLabel.text = NSLocalizedString("die.options.pips", comment: "Change d6 pip style action")
			for (index, style) in DiceD6PipStyle.allCases.enumerated() {
				styleSegmentedControl.insertSegment(withTitle: NSLocalizedString(style.menuTitleKey, comment: "D6 pip style option"), at: index, animated: false)
			}
			styleSegmentedControl.selectedSegmentIndex = DiceD6PipStyle.allCases.firstIndex(of: state.d6PipStyle) ?? 0
		case .numeralFont:
			styleSectionTitleLabel.text = NSLocalizedString("die.options.font", comment: "Change numeral font action")
			for (index, font) in DiceFaceNumeralFont.allCases.enumerated() {
				styleSegmentedControl.insertSegment(withTitle: NSLocalizedString(font.menuTitleKey, comment: "Numeral font option"), at: index, animated: false)
			}
			styleSegmentedControl.selectedSegmentIndex = DiceFaceNumeralFont.allCases.firstIndex(of: state.selectedFont) ?? 0
		}
	}

	private func makeSection(titleKey: String, customTitleLabel: UILabel? = nil) -> (container: UIStackView, body: UIStackView) {
		let container = UIStackView()
		container.axis = .vertical
		container.spacing = 8

		let titleLabel = customTitleLabel ?? UILabel()
		titleLabel.font = .preferredFont(forTextStyle: .headline)
		titleLabel.text = NSLocalizedString(titleKey, comment: "Die inspector section title")
		titleLabel.adjustsFontForContentSizeCategory = true

		let body = UIStackView()
		body.axis = .vertical
		body.spacing = 10
		body.isLayoutMarginsRelativeArrangement = true
		body.layoutMargins = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
		body.backgroundColor = Palette.sectionBackground
		body.layer.cornerRadius = 12

		container.addArrangedSubview(titleLabel)
		container.addArrangedSubview(body)
		return (container, body)
	}

	private func notifyDismissIfNeeded() {
		guard !didNotifyDismiss else { return }
		didNotifyDismiss = true
		onDismiss?()
	}
}

extension DieInspectorSheetViewController: UITextFieldDelegate {
    func textField(_ textField: UITextField,
                   shouldChangeCharactersIn range: NSRange,
                   replacementString string: String) -> Bool {
        if textField == sideCountTextField {
            // Allow only digits
            let allowedCharacters = CharacterSet.decimalDigits
            let characterSet = CharacterSet(charactersIn: string)
            return allowedCharacters.isSuperset(of: characterSet)
        }
        
        return true
    }
}
