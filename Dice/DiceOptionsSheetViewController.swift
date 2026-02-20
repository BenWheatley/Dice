import UIKit

final class DiceOptionsSheetViewController: UIViewController {
	struct State {
		let animationsEnabled: Bool
		let animationIntensity: DiceAnimationIntensity
		let showStats: Bool
		let theme: DiceTheme
		let texture: DiceTableTexture
		let layout: DiceBoardLayoutPreset
		let finish: DiceDieFinish
		let edgeOutlinesEnabled: Bool
		let motionBlurEnabled: Bool
		let largeFaceLabelsEnabled: Bool
		let soundPack: DiceSoundPack
		let soundEffectsEnabled: Bool
		let hapticsEnabled: Bool
	}

	var onToggleAnimations: (() -> Void)?
	var onSetAnimationIntensity: ((DiceAnimationIntensity) -> Void)?
	var onToggleStats: (() -> Void)?
	var onSetTheme: ((DiceTheme) -> Void)?
	var onSetTexture: ((DiceTableTexture) -> Void)?
	var onSetLayout: ((DiceBoardLayoutPreset) -> Void)?
	var onSetFinish: ((DiceDieFinish) -> Void)?
	var onToggleEdgeOutlines: (() -> Void)?
	var onToggleMotionBlur: (() -> Void)?
	var onToggleLargeLabels: (() -> Void)?
	var onSetSoundPack: ((DiceSoundPack) -> Void)?
	var onToggleSoundEffects: (() -> Void)?
	var onToggleHaptics: (() -> Void)?
	var onShowHistory: (() -> Void)?
	var onResetVisuals: (() -> Void)?

	private let state: State
	private let scrollView = UIScrollView()
	private let stackView = UIStackView()

	init(state: State) {
		self.state = state
		super.init(nibName: nil, bundle: nil)
	}

	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	override func viewDidLoad() {
		super.viewDidLoad()
		title = NSLocalizedString("a11y.menu.label", comment: "Main menu accessibility label")
		view.backgroundColor = .systemBackground
		navigationItem.rightBarButtonItem = UIBarButtonItem(
			barButtonSystemItem: .close,
			target: self,
			action: #selector(closeSheet)
		)
		buildForm()
	}

	@objc private func closeSheet() {
		dismiss(animated: true)
	}

	private func buildForm() {
		scrollView.translatesAutoresizingMaskIntoConstraints = false
		stackView.translatesAutoresizingMaskIntoConstraints = false
		stackView.axis = .vertical
		stackView.spacing = 12
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

		addSection(title: NSLocalizedString("menu.control.animations", comment: "Animations section")) { section in
			section.addSwitchRow(title: NSLocalizedString("menu.control.animations", comment: "Animations toggle menu title"), isOn: state.animationsEnabled) { [weak self] _ in self?.onToggleAnimations?() }
			section.addSegmentRow(
				title: NSLocalizedString("menu.control.animationIntensity", comment: "Animation intensity submenu title"),
				items: DiceAnimationIntensity.allCases.map { NSLocalizedString($0.menuTitleKey, comment: "Animation intensity option") },
				selectedIndex: DiceAnimationIntensity.allCases.firstIndex(of: state.animationIntensity) ?? 0
			) { [weak self] index in
				guard DiceAnimationIntensity.allCases.indices.contains(index) else { return }
				self?.onSetAnimationIntensity?(DiceAnimationIntensity.allCases[index])
			}
			section.addSwitchRow(title: NSLocalizedString("menu.control.motionBlur", comment: "Motion blur toggle menu title"), isOn: state.motionBlurEnabled) { [weak self] _ in self?.onToggleMotionBlur?() }
		}
		addSection(title: NSLocalizedString("menu.control.theme", comment: "Visual section")) { section in
			section.addSegmentRow(title: NSLocalizedString("menu.control.theme", comment: "Theme submenu title"), items: DiceTheme.allCases.map { NSLocalizedString($0.menuTitleKey, comment: "Theme option title") }, selectedIndex: DiceTheme.allCases.firstIndex(of: state.theme) ?? 0) { [weak self] index in
				guard DiceTheme.allCases.indices.contains(index) else { return }
				self?.onSetTheme?(DiceTheme.allCases[index])
			}
			section.addSegmentRow(title: NSLocalizedString("menu.control.texture", comment: "Texture submenu title"), items: DiceTableTexture.allCases.map { NSLocalizedString($0.menuTitleKey, comment: "Table texture option") }, selectedIndex: DiceTableTexture.allCases.firstIndex(of: state.texture) ?? 0) { [weak self] index in
				guard DiceTableTexture.allCases.indices.contains(index) else { return }
				self?.onSetTexture?(DiceTableTexture.allCases[index])
			}
			section.addSegmentRow(title: NSLocalizedString("menu.control.layout", comment: "Layout submenu title"), items: DiceBoardLayoutPreset.allCases.map { NSLocalizedString($0.menuTitleKey, comment: "Board layout option") }, selectedIndex: DiceBoardLayoutPreset.allCases.firstIndex(of: state.layout) ?? 0) { [weak self] index in
				guard DiceBoardLayoutPreset.allCases.indices.contains(index) else { return }
				self?.onSetLayout?(DiceBoardLayoutPreset.allCases[index])
			}
			section.addSegmentRow(title: NSLocalizedString("menu.control.finish", comment: "Finish submenu title"), items: DiceDieFinish.allCases.map { NSLocalizedString($0.menuTitleKey, comment: "Die finish option") }, selectedIndex: DiceDieFinish.allCases.firstIndex(of: state.finish) ?? 0) { [weak self] index in
				guard DiceDieFinish.allCases.indices.contains(index) else { return }
				self?.onSetFinish?(DiceDieFinish.allCases[index])
			}
			section.addSwitchRow(title: NSLocalizedString("menu.control.largeFaceLabels", comment: "Large face labels toggle title"), isOn: state.largeFaceLabelsEnabled) { [weak self] _ in self?.onToggleLargeLabels?() }
			section.addSwitchRow(title: NSLocalizedString("menu.control.showStats", comment: "Show stats toggle menu title"), isOn: state.showStats) { [weak self] _ in self?.onToggleStats?() }
		}
		addSection(title: NSLocalizedString("menu.control.soundPack", comment: "Sound section")) { section in
			section.addSegmentRow(title: NSLocalizedString("menu.control.soundPack", comment: "Sound pack submenu title"), items: DiceSoundPack.allCases.map { NSLocalizedString($0.menuTitleKey, comment: "Sound pack option") }, selectedIndex: DiceSoundPack.allCases.firstIndex(of: state.soundPack) ?? 0) { [weak self] index in
				guard DiceSoundPack.allCases.indices.contains(index) else { return }
				self?.onSetSoundPack?(DiceSoundPack.allCases[index])
			}
			section.addSwitchRow(title: NSLocalizedString("menu.control.soundEffects", comment: "Sound effects toggle title"), isOn: state.soundEffectsEnabled) { [weak self] _ in self?.onToggleSoundEffects?() }
			section.addSwitchRow(title: NSLocalizedString("menu.control.haptics", comment: "Haptics toggle title"), isOn: state.hapticsEnabled) { [weak self] _ in self?.onToggleHaptics?() }
		}
		addSection(title: NSLocalizedString("menu.control.actions", comment: "Actions section")) { section in
			section.addActionButton(title: NSLocalizedString("button.history", comment: "History button title")) { [weak self] in self?.onShowHistory?() }
			section.addActionButton(title: NSLocalizedString("menu.control.resetVisuals", comment: "Reset visual settings menu title"), destructive: true) { [weak self] in self?.onResetVisuals?() }
		}
	}

	private func addSection(title: String, build: (DiceOptionsSectionBuilder) -> Void) {
		let sectionStack = UIStackView()
		sectionStack.axis = .vertical
		sectionStack.spacing = 8
		let header = UILabel()
		header.text = title
		header.font = .preferredFont(forTextStyle: .headline)
		sectionStack.addArrangedSubview(header)
		let body = UIStackView()
		body.axis = .vertical
		body.spacing = 10
		body.isLayoutMarginsRelativeArrangement = true
		body.layoutMargins = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
		body.backgroundColor = .secondarySystemGroupedBackground
		body.layer.cornerRadius = 12
		sectionStack.addArrangedSubview(body)
		build(DiceOptionsSectionBuilder(stackView: body))
		stackView.addArrangedSubview(sectionStack)
	}
}
