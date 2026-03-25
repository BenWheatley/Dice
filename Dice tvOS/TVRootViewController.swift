import UIKit

final class TVRootViewController: UIViewController {
	private static let tvHelpShownKey = "Dice.tvOS.helpShown"

	private let viewModel = DiceViewModel()
	private let diceBoardView = DiceCubeView()
	private let diceSelectionOverlayView = TVDiceSelectionOverlayView()
	private let controlOverlayView = TVControlOverlayView()
	private var hasPerformedInitialRoll = false
	private var previousBoardLayoutBounds: CGRect?
	private var selectedDieIndex: Int?
	private weak var dieInspectorSheetController: DieInspectorSheetViewController?

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
		[diceSelectionOverlayView.primaryFocusableView ?? controlOverlayView.primaryFocusableView]
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

		view.addSubview(diceSelectionOverlayView)
		NSLayoutConstraint.activate([
			diceSelectionOverlayView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
			diceSelectionOverlayView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
			diceSelectionOverlayView.topAnchor.constraint(equalTo: view.topAnchor),
			diceSelectionOverlayView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
		])

		diceSelectionOverlayView.onSelectDie = { [weak self] index in
			self?.presentDieInspector(for: index)
		}
		diceSelectionOverlayView.onFocusedDie = { [weak self] index in
			guard let self else { return }
			guard self.dieInspectorSheetController?.presentingViewController == nil else { return }
			self.selectedDieIndex = index
			self.diceBoardView.setSelectedDieIndex(index)
		}
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
			diceSelectionOverlayView.isHidden = true
			diceBoardView.setDice(values: [], centers: [], sideLength: 0, sideCounts: [], animated: false)
			diceSelectionOverlayView.updateDiceTargets(centers: [], sideLength: 0)
			selectedDieIndex = nil
			diceBoardView.setSelectedDieIndex(nil)
			return
		}

		diceBoardView.isHidden = false
		diceSelectionOverlayView.isHidden = false
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
		if let selectedDieIndex, selectedDieIndex >= values.count {
			self.selectedDieIndex = nil
		}
		diceSelectionOverlayView.updateDiceTargets(centers: layout.centers, sideLength: layout.sideLength)
		diceSelectionOverlayView.setPreferredFocusedDieIndex(selectedDieIndex)
		diceBoardView.setSelectedDieIndex(selectedDieIndex)
		updateOverlaySummary()
	}

	private func updateOverlaySummary() {
		controlOverlayView.updateSummary(
			notation: viewModel.configuration.notation
		)
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

	private func presentDieInspector(for index: Int) {
		guard viewModel.diceValues.indices.contains(index), viewModel.diceSideCounts.indices.contains(index) else { return }
		selectedDieIndex = index
		diceSelectionOverlayView.setPreferredFocusedDieIndex(index)
		diceBoardView.setSelectedDieIndex(index)
		let state = DieInspectorSheetCoordinator.makeState(viewModel: viewModel, dieIndex: index)

		if let inspector = dieInspectorSheetController, inspector.presentingViewController != nil {
			DieInspectorSheetCoordinator.bind(inspector, handlers: dieInspectorHandlers(for: index))
			inspector.updateState(state)
			return
		}

		let inspector = DieInspectorSheetViewController(state: state)
		DieInspectorSheetCoordinator.bind(inspector, handlers: dieInspectorHandlers(for: index))
		inspector.onDismiss = { [weak self, weak inspector] in
			guard let self else { return }
			if self.dieInspectorSheetController === inspector {
				self.dieInspectorSheetController = nil
			}
			guard let index = self.selectedDieIndex else { return }
			self.diceSelectionOverlayView.setPreferredFocusedDieIndex(index)
			self.setNeedsFocusUpdate()
			self.updateFocusIfNeeded()
		}

		let navigationController = DieInspectorSheetCoordinator.themedNavigationController(
			rootViewController: inspector,
			theme: viewModel.theme
		)
		navigationController.modalPresentationStyle = .automatic
		navigationController.preferredContentSize = CGSize(width: 900, height: 980)
		present(navigationController, animated: true)
		dieInspectorSheetController = inspector
	}

	private func dieInspectorHandlers(for dieIndex: Int) -> DieInspectorSheetHandlers {
		DieInspectorSheetHandlers(
			reroll: { [weak self] in
				guard let self else { return }
				_ = self.viewModel.rerollDie(at: dieIndex)
				self.renderBoard(animated: self.viewModel.animationIntensity != .off)
			},
			toggleLock: { [weak self] in
				guard let self else { return }
				self.viewModel.toggleDieLock(at: dieIndex)
				self.renderBoard(animated: false)
				self.refreshDieInspectorIfVisible()
			},
			setColor: { [weak self] preset in
				guard let self else { return }
				self.viewModel.applyPerDieColorSelection(preset, at: dieIndex)
				self.renderBoard(animated: false)
				self.refreshDieInspectorIfVisible()
			},
			setD6PipStyle: { [weak self] style in
				guard let self else { return }
				self.viewModel.setD6PipStyle(style)
				self.renderBoard(animated: false)
				self.refreshDieInspectorIfVisible()
			},
			setFaceNumeralFont: { [weak self] font in
				guard let self else { return }
				self.viewModel.setFaceNumeralFont(font, forDieAt: dieIndex)
				self.renderBoard(animated: false)
				self.refreshDieInspectorIfVisible()
			},
			setSideCount: { [weak self] sideCount in
				guard let self else { return }
				guard case .success = self.viewModel.setDieSideCount(sideCount, forDieAt: dieIndex) else { return }
				self.renderBoard(animated: false)
				self.refreshDieInspectorIfVisible()
			}
		)
	}

	private func refreshDieInspectorIfVisible() {
		guard let inspector = dieInspectorSheetController, inspector.presentingViewController != nil else { return }
		guard let index = selectedDieIndex else { return }
		guard viewModel.diceValues.indices.contains(index), viewModel.diceSideCounts.indices.contains(index) else { return }
		DieInspectorSheetCoordinator.bind(inspector, handlers: dieInspectorHandlers(for: index))
		inspector.updateState(DieInspectorSheetCoordinator.makeState(viewModel: viewModel, dieIndex: index))
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
