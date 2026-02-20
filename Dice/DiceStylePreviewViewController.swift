import UIKit

final class DiceStylePreviewViewController: UIViewController {
	private let state: DiceStylePreviewState
	private let previewBoard = DiceCubeView()
	private let summaryLabel = UILabel()
	private lazy var textureBackgroundView = DiceShaderBackgroundView(texture: state.texture)

	init(state: DiceStylePreviewState) {
		self.state = state
		super.init(nibName: nil, bundle: nil)
	}

	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	override func viewDidLoad() {
		super.viewDidLoad()
		title = NSLocalizedString("preview.title", comment: "Style preview screen title")
		navigationItem.leftBarButtonItem = UIBarButtonItem(
			title: NSLocalizedString("button.close", comment: "Close button title"),
			style: .plain,
			target: self,
			action: #selector(close)
		)

		let palette = state.theme.palette
		view.backgroundColor = palette.screenBackgroundColor

		let texturePanel = UIView()
		texturePanel.translatesAutoresizingMaskIntoConstraints = false
		texturePanel.layer.cornerRadius = 12
		texturePanel.clipsToBounds = true

		textureBackgroundView.translatesAutoresizingMaskIntoConstraints = false

		previewBoard.translatesAutoresizingMaskIntoConstraints = false
		previewBoard.setDieFinish(state.dieFinish)
		previewBoard.setEdgeOutlinesEnabled(state.edgeOutlinesEnabled)
		previewBoard.setDieColorPreferences(state.dieColors)
		previewBoard.setD6PipStyle(state.d6PipStyle)
		previewBoard.setFaceNumeralFont(state.faceNumeralFont)
		previewBoard.setLargeFaceLabelsEnabled(state.largeFaceLabelsEnabled)

		summaryLabel.translatesAutoresizingMaskIntoConstraints = false
		summaryLabel.font = .systemFont(ofSize: 13, weight: .medium)
		summaryLabel.textColor = palette.secondaryTextColor
		summaryLabel.numberOfLines = 0
		summaryLabel.textAlignment = .center
		summaryLabel.text = summaryText()

		texturePanel.addSubview(textureBackgroundView)
		texturePanel.addSubview(previewBoard)
		view.addSubview(texturePanel)
		view.addSubview(summaryLabel)

		NSLayoutConstraint.activate([
			texturePanel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
			texturePanel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
			texturePanel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
			texturePanel.heightAnchor.constraint(equalTo: texturePanel.widthAnchor, multiplier: 0.64),

			textureBackgroundView.topAnchor.constraint(equalTo: texturePanel.topAnchor),
			textureBackgroundView.leadingAnchor.constraint(equalTo: texturePanel.leadingAnchor),
			textureBackgroundView.trailingAnchor.constraint(equalTo: texturePanel.trailingAnchor),
			textureBackgroundView.bottomAnchor.constraint(equalTo: texturePanel.bottomAnchor),

			previewBoard.topAnchor.constraint(equalTo: texturePanel.topAnchor),
			previewBoard.leadingAnchor.constraint(equalTo: texturePanel.leadingAnchor),
			previewBoard.trailingAnchor.constraint(equalTo: texturePanel.trailingAnchor),
			previewBoard.bottomAnchor.constraint(equalTo: texturePanel.bottomAnchor),

			summaryLabel.topAnchor.constraint(equalTo: texturePanel.bottomAnchor, constant: 12),
			summaryLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
			summaryLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
			summaryLabel.bottomAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -12),
		])

		preferredContentSize = CGSize(width: 420, height: 430)
	}

	override func viewDidLayoutSubviews() {
		super.viewDidLayoutSubviews()
		let panelBounds = previewBoard.bounds
		guard panelBounds.width > 80, panelBounds.height > 80 else { return }
		textureBackgroundView.setTexture(state.texture)
		textureBackgroundView.refreshBackground(size: panelBounds.size)
		let side = max(52, min(96, min(panelBounds.width / 4.2, panelBounds.height / 2.6)))
		let y = panelBounds.midY
		let centers = [
			CGPoint(x: panelBounds.width * 0.20, y: y),
			CGPoint(x: panelBounds.width * 0.40, y: y),
			CGPoint(x: panelBounds.width * 0.60, y: y),
			CGPoint(x: panelBounds.width * 0.80, y: y),
		]
		previewBoard.setDice(
			values: [2, 5, 8, 14],
			centers: centers,
			sideLength: side,
			sideCounts: [4, 6, 10, 20],
			animated: false
		)
	}

	private func summaryText() -> String {
		let texture = NSLocalizedString(state.texture.menuTitleKey, comment: "Texture title")
		let finish = NSLocalizedString(state.dieFinish.menuTitleKey, comment: "Finish title")
		let pip = NSLocalizedString(state.d6PipStyle.menuTitleKey, comment: "Pip style title")
		let font = NSLocalizedString(state.faceNumeralFont.menuTitleKey, comment: "Font title")
		return String(
			format: NSLocalizedString("preview.summary", comment: "Style preview summary text"),
			texture,
			finish,
			pip,
			font
		)
	}

	@objc private func close() {
		dismiss(animated: true)
	}
}
