import UIKit

final class TVRootViewController: UIViewController {
	private static let tvHelpShownKey = "Dice.tvOS.helpShown"

	private let viewModel = DiceViewModel()
	private let diceBoardView = DiceCubeView()
	private let controlOverlayView = TVControlOverlayView()
	private var hasPerformedInitialRoll = false
	private var previousBoardLayoutBounds: CGRect?

	override func viewDidLoad() {
		super.viewDidLoad()
		viewModel.restore()
		configureBoard()
		configureControlOverlay()
		applyTheme()
		renderBoard(animated: false)
	}

	override func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated)
		guard !hasPerformedInitialRoll else { return }
		hasPerformedInitialRoll = true
		performRoll(animated: false)
		presentHelpIfNeeded()
	}

	override func viewDidLayoutSubviews() {
		super.viewDidLayoutSubviews()
		let currentBounds = diceBoardView.bounds
		if DiceBoardLayoutCalculator.layoutNeedsRefresh(previousBounds: previousBoardLayoutBounds, currentBounds: currentBounds) {
			renderBoard(animated: false)
			previousBoardLayoutBounds = currentBounds
		}
	}

	override var preferredFocusEnvironments: [UIFocusEnvironment] {
		[controlOverlayView.primaryFocusableView]
	}

	private func configureBoard() {
		view.addSubview(diceBoardView)
		diceBoardView.translatesAutoresizingMaskIntoConstraints = false
		diceBoardView.accessibilityIdentifier = "tvDiceBoardView"
		NSLayoutConstraint.activate([
			diceBoardView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
			diceBoardView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
			diceBoardView.topAnchor.constraint(equalTo: view.topAnchor),
			diceBoardView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
		])
	}

	private func configureControlOverlay() {
		view.addSubview(controlOverlayView)
		NSLayoutConstraint.activate([
			controlOverlayView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
			controlOverlayView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
			controlOverlayView.topAnchor.constraint(equalTo: view.topAnchor),
			controlOverlayView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
		])

		controlOverlayView.onRoll = { [weak self] in
			self?.performRoll(animated: self?.viewModel.animationIntensity != .off)
		}
		controlOverlayView.onShowPresets = { [weak self] in
			self?.presentPresets()
		}
		controlOverlayView.onShowSettings = { [weak self] in
			self?.presentSettings()
		}
		controlOverlayView.onShowHelp = { [weak self] in
			self?.presentHelp(markAsShown: true)
		}
	}

	private func applyTheme() {
		view.backgroundColor = viewModel.theme.palette.screenBackgroundColor
		controlOverlayView.applyTheme()
		updateOverlaySummary()
	}

	private func performRoll(animated: Bool) {
		_ = viewModel.rollCurrent()
		renderBoard(animated: animated)
	}

	private func renderBoard(animated: Bool) {
		let sideCounts = viewModel.diceSideCounts
		guard !sideCounts.isEmpty else {
			diceBoardView.isHidden = true
			diceBoardView.setDice(values: [], centers: [], sideLength: 0, sideCounts: [], animated: false)
			return
		}

		diceBoardView.isHidden = false
		diceBoardView.setDieFinish(viewModel.dieFinish)
		diceBoardView.setEdgeOutlinesEnabled(viewModel.edgeOutlinesEnabled)
		diceBoardView.setDieColorPreferences(viewModel.dieColorPreferences)
		diceBoardView.setD6PipStyle(viewModel.d6PipStyle)
		diceBoardView.setFaceNumeralFont(viewModel.faceNumeralFont)
		diceBoardView.setLargeFaceLabelsEnabled(viewModel.largeFaceLabelsEnabled)
		diceBoardView.setLightingAngle(viewModel.lightingAngle)
		diceBoardView.setAnimationIntensity(viewModel.animationIntensity)
		diceBoardView.setTableTexture(viewModel.tableTexture)
		diceBoardView.setMotionBlurEnabled(viewModel.motionBlurEnabled)
		diceBoardView.setCameraViewportInsets(controlOverlayView.boardViewportInsets)

		let itemCount = min(viewModel.diceValues.count, sideCounts.count)
		let mixed = Set(sideCounts).count > 1
		let viewportInsets = controlOverlayView.boardViewportInsets
		let layoutBounds = diceBoardView.bounds.inset(by: viewportInsets)
		let layout = DiceBoardLayoutCalculator.boardRenderLayout(
			itemCount: itemCount,
			bounds: layoutBounds.isNull || layoutBounds.isEmpty ? diceBoardView.bounds : layoutBounds,
			layoutPreset: viewModel.boardLayoutPreset,
			mixed: mixed
		)
		let values = Array(viewModel.diceValues.prefix(itemCount))
		let boardSideCounts = Array(sideCounts.prefix(itemCount))
		let colorOverrides = (0..<values.count).map { viewModel.dieColorOverridesByIndex[$0] }
		let fontOverrides = (0..<values.count).map { viewModel.dieFaceNumeralFontOverridesByIndex[$0] }

		diceBoardView.setDice(
			values: values,
			centers: layout.centers,
			sideLength: layout.sideLength,
			sideCounts: boardSideCounts,
			dieColorPresets: colorOverrides,
			faceNumeralFonts: fontOverrides,
			lockedIndices: viewModel.lockedDieIndices,
			animated: animated
		)
		updateOverlaySummary()
	}

	private func updateOverlaySummary() {
		controlOverlayView.updateSummary(
			notation: viewModel.configuration.notation,
			mode: currentModeText()
		)
	}

	private func currentModeText() -> String {
		let configuration = viewModel.configuration
		if configuration.hasIntuitivePools && configuration.hasTrueRandomPools {
			return NSLocalizedString("stats.mode.mixed", comment: "Mixed roll mode")
		}
		let key = configuration.hasIntuitivePools ? "stats.mode.intuitive" : "stats.mode.trueRandom"
		return NSLocalizedString(key, comment: "tvOS roll mode summary")
	}

	private func presentHelpIfNeeded() {
		guard !UserDefaults.standard.bool(forKey: Self.tvHelpShownKey) else { return }
		presentHelp(markAsShown: true)
	}

	private func presentHelp(markAsShown: Bool) {
		if markAsShown {
			UserDefaults.standard.set(true, forKey: Self.tvHelpShownKey)
		}
		let alert = UIAlertController(
			title: NSLocalizedString("tvos.help.title", comment: "tvOS help title"),
			message: NSLocalizedString("tvos.help.message", comment: "tvOS help message"),
			preferredStyle: .alert
		)
		alert.addAction(UIAlertAction(title: NSLocalizedString("button.ok", comment: "Generic confirmation button"), style: .default))
		present(alert, animated: true)
	}

	private func presentPresets() {
		let picker = PresetPickerViewController(
			currentNotation: viewModel.configuration.notation,
			customPresets: viewModel.customPresets,
			recentNotations: viewModel.recentPresets
		)
		picker.onSelectNotationPreset = { [weak self] notation in
			self?.applyNotationPreset(notation)
		}
		picker.onSaveCustomPresets = { [weak self] presets in
			self?.viewModel.saveCustomPresets(presets)
		}
		picker.onCreateCustomPreset = { [weak self] title, notation in
			self?.viewModel.createCustomPreset(title: title, notation: notation) ?? .failure(.invalidFormat)
		}
#if os(tvOS)
		picker.onEditCurrentDice = { [weak self, weak picker] _ in
			self?.pushDiceComposer(from: picker)
		}
#endif
		let navigationController = UINavigationController(rootViewController: picker)
		navigationController.modalPresentationStyle = UIModalPresentationStyle.fullScreen
		present(navigationController, animated: true)
	}

	private func pushDiceComposer(from picker: UIViewController?) {
		let composer = TVDiceComposerViewController(configuration: viewModel.configuration)
		composer.onApplyConfiguration = { [weak self] configuration in
			self?.applyNotationPreset(configuration.notation)
		}
		picker?.navigationController?.pushViewController(composer, animated: true)
	}

	private func applyNotationPreset(_ notation: String) {
		switch viewModel.rollFromInput(notation) {
		case .success:
			applyTheme()
			renderBoard(animated: true)
		case let .failure(error):
			presentInlineAlert(title: "Invalid Preset", message: error.userMessage)
		}
	}

	private func presentSettings() {
		let settingsController = TVSettingsViewController(
			mode: currentModeOption(),
			texture: viewModel.tableTexture,
			theme: viewModel.theme
		)
		settingsController.onSelectMode = { [weak self] option in
			self?.setRollMode(option)
		}
		settingsController.onSelectTexture = { [weak self] texture in
			self?.viewModel.setTableTexture(texture)
			self?.applyTheme()
			self?.renderBoard(animated: false)
		}
		settingsController.onSelectTheme = { [weak self] theme in
			self?.viewModel.setTheme(theme)
			self?.applyTheme()
			self?.renderBoard(animated: false)
		}
		let navigationController = UINavigationController(rootViewController: settingsController)
		navigationController.modalPresentationStyle = .fullScreen
		present(navigationController, animated: true)
	}

	private func currentModeOption() -> TVSettingsViewController.ModeOption? {
		let configuration = viewModel.configuration
		if configuration.hasIntuitivePools && configuration.hasTrueRandomPools {
			return nil
		}
		return configuration.hasIntuitivePools ? .intuitive : .trueRandom
	}

	private func setRollMode(_ mode: TVSettingsViewController.ModeOption) {
		let configuration = RollConfiguration(
			pools: viewModel.configuration.pools,
			intuitive: mode == .intuitive
		)
		applyNotationPreset(configuration.notation)
	}

	private func presentInlineAlert(title: String, message: String) {
		let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
		alert.addAction(UIAlertAction(title: NSLocalizedString("button.ok", comment: "Generic confirmation button"), style: .default))
		present(alert, animated: true)
	}
}
