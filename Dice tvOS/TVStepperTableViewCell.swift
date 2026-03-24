import UIKit

final class TVStepperTableViewCell: UITableViewCell {
	var onDecrement: (() -> Void)?
	var onIncrement: (() -> Void)?

	private let titleLabel = UILabel()
	private let valueLabel = UILabel()
	private let decrementButton = UIButton(type: .system)
	private let incrementButton = UIButton(type: .system)
	private let buttonStack = UIStackView()
	private let contentStack = UIStackView()

	override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
		super.init(style: style, reuseIdentifier: reuseIdentifier)
		configureHierarchy()
		configureButtons()
	}

	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	func configure(title: String, value: String, canDecrement: Bool, canIncrement: Bool) {
		titleLabel.text = title
		valueLabel.text = value
		decrementButton.isEnabled = canDecrement
		incrementButton.isEnabled = canIncrement
	}

	private func configureHierarchy() {
		selectionStyle = .none
		backgroundColor = .clear

		titleLabel.font = UIFont.preferredFont(forTextStyle: .title3)
		titleLabel.textColor = .white

		valueLabel.font = UIFont.preferredFont(forTextStyle: .title2)
		valueLabel.textColor = .white
		valueLabel.textAlignment = .center

		buttonStack.axis = .horizontal
		buttonStack.alignment = .fill
		buttonStack.distribution = .fillEqually
		buttonStack.spacing = 20

		contentStack.axis = .vertical
		contentStack.alignment = .fill
		contentStack.spacing = 18

		[decrementButton, incrementButton].forEach { button in
			button.translatesAutoresizingMaskIntoConstraints = false
			button.heightAnchor.constraint(equalToConstant: 72).isActive = true
			buttonStack.addArrangedSubview(button)
		}

		[titleLabel, valueLabel, buttonStack].forEach { arrangedView in
			contentStack.addArrangedSubview(arrangedView)
		}

		contentStack.translatesAutoresizingMaskIntoConstraints = false
		contentView.addSubview(contentStack)

		NSLayoutConstraint.activate([
			contentStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 18),
			contentStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 28),
			contentStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -28),
			contentStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -18),
		])

		var background = UIBackgroundConfiguration.listCell()
		background.backgroundColor = UIColor(white: 0.12, alpha: 0.96)
		background.cornerRadius = 20
		background.backgroundInsets = NSDirectionalEdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0)
		backgroundConfiguration = background
	}

	private func configureButtons() {
		configure(button: decrementButton, title: "−", action: #selector(handleDecrement))
		configure(button: incrementButton, title: "+", action: #selector(handleIncrement))
	}

	private func configure(button: UIButton, title: String, action: Selector) {
		var configuration = UIButton.Configuration.borderedProminent()
		configuration.title = title
		configuration.baseForegroundColor = .white
		configuration.baseBackgroundColor = UIColor(white: 0.22, alpha: 1.0)
		configuration.cornerStyle = .capsule
		configuration.contentInsets = NSDirectionalEdgeInsets(top: 18, leading: 28, bottom: 18, trailing: 28)
		button.configuration = configuration
		button.addTarget(self, action: action, for: .primaryActionTriggered)
	}

	@objc private func handleDecrement() {
		onDecrement?()
	}

	@objc private func handleIncrement() {
		onIncrement?()
	}
}
