import UIKit

class DiceCollectionViewCell: UICollectionViewCell {
	private let boardSupportedSides: Set<Int> = [4, 6, 8, 10, 12, 20]
	var onTapDie: ((CGPoint) -> Void)?
	var onToggleLock: (() -> Void)?
	private var currentPalette = DiceTheme.system.palette
	private var isLocked = false
	private var lockGestureConfigured = false
	private let lockIconView = UIImageView(image: UIImage(systemName: "lock.fill"))

	@IBOutlet weak var diceButton: UIButton!

	override init(frame: CGRect) {
		super.init(frame: frame)
		configureGestures()
		configureLockIcon()
	}

	required init?(coder: NSCoder) {
		super.init(coder: coder)
		configureGestures()
		configureLockIcon()
	}

	override func awakeFromNib() {
		super.awakeFromNib()
		configureGestures()
		configureLockIcon()
	}

	override func layoutSubviews() {
		super.layoutSubviews()
		diceButton.frame = contentView.bounds
		let iconSize: CGFloat = 18
		lockIconView.frame = CGRect(x: contentView.bounds.maxX - iconSize - 4, y: 4, width: iconSize, height: iconSize)
	}

	func configure(faceValue: Int, sideCount: Int, index: Int, palette: DiceThemePalette, isLocked: Bool, largeFaceLabelsEnabled: Bool) {
		currentPalette = palette
		self.isLocked = isLocked
		diceButton.accessibilityIdentifier = "dieButton_\(index)"
		diceButton.accessibilityLabel = String(
			format: NSLocalizedString("a11y.die.label", comment: "Die button accessibility label format"),
			locale: .current,
			index + 1,
			faceValue
		)
		diceButton.accessibilityHint = isLocked
			? NSLocalizedString("a11y.die.lockedHint", comment: "Locked die accessibility hint")
			: NSLocalizedString("a11y.die.hint", comment: "Die button accessibility hint")
		diceButton.accessibilityTraits = .button
		setFaceValue(faceValue, sideCount: sideCount, largeFaceLabelsEnabled: largeFaceLabelsEnabled)
		lockIconView.isHidden = !isLocked
	}

	private func setFaceValue(_ value: Int, sideCount: Int, largeFaceLabelsEnabled: Bool) {
		if boardSupportedSides.contains(sideCount) {
			diceButton.setTitle(nil, for: .normal)
			diceButton.setImage(nil, for: .normal)
			diceButton.layer.borderWidth = 0
			diceButton.layer.cornerRadius = 0
			diceButton.layer.borderColor = UIColor.clear.cgColor
			diceButton.backgroundColor = UIColor.clear
		} else {
			diceButton.setImage(nil, for: .normal)
			diceButton.setTitle("\(value)", for: .normal)
			diceButton.setTitleColor(currentPalette.fallbackDieTextColor, for: .normal)
			let side = min(contentView.bounds.width, contentView.bounds.height)
			let pointSize = DiceFaceLabelSizing.staticFallbackPointSize(cellSideLength: side, large: largeFaceLabelsEnabled)
			diceButton.titleLabel?.font = UIFont.systemFont(ofSize: pointSize, weight: .bold)
			diceButton.layer.borderColor = isLocked ? UIColor.systemYellow.cgColor : currentPalette.fallbackDieBorderColor.cgColor
			diceButton.layer.borderWidth = isLocked ? 2 : 1
			diceButton.layer.cornerRadius = 8
			diceButton.backgroundColor = currentPalette.fallbackDieBackgroundColor
		}
	}

	private func configureGestures() {
		guard !lockGestureConfigured, let diceButton else { return }
		lockGestureConfigured = true
		let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
		longPress.minimumPressDuration = 0.35
		diceButton.addGestureRecognizer(longPress)
		diceButton.isUserInteractionEnabled = true
	}

	private func configureLockIcon() {
		guard lockIconView.superview == nil else { return }
		lockIconView.tintColor = .systemYellow
		lockIconView.contentMode = .scaleAspectFit
		lockIconView.layer.shadowColor = UIColor.black.cgColor
		lockIconView.layer.shadowOpacity = 0.35
		lockIconView.layer.shadowRadius = 1.5
		lockIconView.layer.shadowOffset = CGSize(width: 0, height: 1)
		lockIconView.isHidden = true
		contentView.addSubview(lockIconView)
		contentView.bringSubviewToFront(lockIconView)
	}

	@objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
		if gesture.state == .began {
			onToggleLock?()
		}
	}

	@IBAction func reroll(_ sender: Any) {
		guard let button = sender as? UIButton else {
			onTapDie?(CGPoint(x: contentView.bounds.midX, y: contentView.bounds.midY))
			return
		}
		let point = button.convert(CGPoint(x: button.bounds.midX, y: button.bounds.midY), to: contentView)
		onTapDie?(point)
	}
}
