import UIKit

final class TVRootViewController: UIViewController {
	private let viewModel = DiceViewModel()
	private let diceBoardView = DiceCubeView()
	private var hasPerformedInitialRoll = false
	private var previousBoardLayoutBounds: CGRect?

	override func viewDidLoad() {
		super.viewDidLoad()
		viewModel.restore()
		configureBoard()
		applyTheme()
		renderBoard(animated: false)
	}

	override func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated)
		guard !hasPerformedInitialRoll else { return }
		hasPerformedInitialRoll = true
		performRoll(animated: false)
	}

	override func viewDidLayoutSubviews() {
		super.viewDidLayoutSubviews()
		let currentBounds = diceBoardView.bounds
		if DiceBoardLayoutCalculator.layoutNeedsRefresh(previousBounds: previousBoardLayoutBounds, currentBounds: currentBounds) {
			renderBoard(animated: false)
			previousBoardLayoutBounds = currentBounds
		}
	}

	override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
		if presses.contains(where: { $0.type == .select || $0.type == .playPause }) {
			performRoll(animated: viewModel.animationIntensity != .off)
			return
		}
		super.pressesEnded(presses, with: event)
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

	private func applyTheme() {
		view.backgroundColor = viewModel.theme.palette.screenBackgroundColor
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
		diceBoardView.setCameraViewportInsets(.zero)

		let itemCount = min(viewModel.diceValues.count, sideCounts.count)
		let mixed = Set(sideCounts).count > 1
		let layoutBounds = view.convert(view.safeAreaLayoutGuide.layoutFrame, to: diceBoardView)
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
	}
}
