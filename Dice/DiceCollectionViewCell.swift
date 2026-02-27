import UIKit

class DiceCollectionViewCell: UICollectionViewCell {
	private let boardSupportedSides: Set<Int> = [4, 6, 8, 10, 12, 20]
	var onTapDie: ((CGPoint) -> Void)?
	private var currentPalette = DiceTheme.system.palette
	private var isLocked = false
	private let lockIconView = UIImageView(image: UIImage(systemName: "lock.fill"))
	private let menuHitPadding: CGFloat = 10
	private var hasInstalledFullSizeButtonConstraints = false

	@IBOutlet weak var diceButton: UIButton!

	override init(frame: CGRect) {
		super.init(frame: frame)
		configureLockIcon()
	}

	required init?(coder: NSCoder) {
		super.init(coder: coder)
		configureLockIcon()
	}

	override func awakeFromNib() {
		super.awakeFromNib()
		configureLockIcon()
		installFullSizeButtonConstraintsIfNeeded()
	}

	override func layoutSubviews() {
		super.layoutSubviews()
		let iconSize: CGFloat = 18
		lockIconView.frame = CGRect(x: contentView.bounds.maxX - iconSize - 4, y: 4, width: iconSize, height: iconSize)
	}

	override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
		Self.expandedHitBounds(for: bounds, padding: menuHitPadding).contains(point)
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

	private func setFaceValue(_ value: Int, sideCount _: Int, largeFaceLabelsEnabled _: Bool) {
		_ = value
		diceButton.setTitle(nil, for: .normal)
		diceButton.setImage(nil, for: .normal)
		diceButton.layer.borderWidth = 0
		diceButton.layer.cornerRadius = 0
		diceButton.layer.borderColor = UIColor.clear.cgColor
		diceButton.backgroundColor = UIColor.clear
		contentView.backgroundColor = .clear
		backgroundColor = .clear
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

	private func installFullSizeButtonConstraintsIfNeeded() {
		guard !hasInstalledFullSizeButtonConstraints else { return }
		hasInstalledFullSizeButtonConstraints = true
		let constraintsToReplace = Self.constraintsInvolvingButton(
			diceButton,
			cellConstraints: constraints,
			contentConstraints: contentView.constraints
		)
		NSLayoutConstraint.deactivate(constraintsToReplace)
		diceButton.translatesAutoresizingMaskIntoConstraints = false
		NSLayoutConstraint.activate([
			diceButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
			diceButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
			diceButton.topAnchor.constraint(equalTo: contentView.topAnchor),
			diceButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
		])
	}

	static func constraintsInvolvingButton(
		_ button: UIView,
		cellConstraints: [NSLayoutConstraint],
		contentConstraints: [NSLayoutConstraint]
	) -> [NSLayoutConstraint] {
		(cellConstraints + contentConstraints).filter { constraint in
			(constraint.firstItem as? UIView) == button || (constraint.secondItem as? UIView) == button
		}
	}

	static func expandedHitBounds(for bounds: CGRect, padding: CGFloat) -> CGRect {
		bounds.insetBy(dx: -padding, dy: -padding)
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
