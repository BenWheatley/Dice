import UIKit

struct DieInspectorSheetHandlers {
	let reroll: () -> Void
	let toggleLock: () -> Void
	let setColor: (DiceDieColorPreset) -> Void
	let setD6PipStyle: (DiceD6PipStyle) -> Void
	let setFaceNumeralFont: (DiceFaceNumeralFont) -> Void
	let setSideCount: (Int) -> Void
}

enum DieInspectorSheetCoordinator {
	static func makeState(viewModel: DiceViewModel, dieIndex: Int) -> DieInspectorSheetViewController.State {
		let sideCount = viewModel.diceSideCounts[dieIndex]
		let selectedColor = viewModel.dieColorPreset(forDieAt: dieIndex) ?? viewModel.dieColorPreset(for: sideCount)
		let selectedFont = viewModel.faceNumeralFont(forDieAt: dieIndex) ?? viewModel.faceNumeralFont
		return DieInspectorSheetViewController.State(
			dieIndex: dieIndex,
			sideCount: sideCount,
			isLocked: viewModel.isDieLocked(at: dieIndex),
			selectedColor: selectedColor,
			d6PipStyle: viewModel.d6PipStyle,
			selectedFont: selectedFont
		)
	}

	static func bind(_ inspector: DieInspectorSheetViewController, handlers: DieInspectorSheetHandlers) {
		inspector.onReroll = handlers.reroll
		inspector.onToggleLock = handlers.toggleLock
		inspector.onSetColor = handlers.setColor
		inspector.onSetD6PipStyle = handlers.setD6PipStyle
		inspector.onSetFaceNumeralFont = handlers.setFaceNumeralFont
		inspector.onSetSideCount = handlers.setSideCount
	}

	static func themedNavigationController(rootViewController: UIViewController, theme: DiceTheme) -> UINavigationController {
		let navigationController = UINavigationController(rootViewController: rootViewController)
		switch theme {
		case .lightMode:
			navigationController.overrideUserInterfaceStyle = .light
		case .darkMode:
			navigationController.overrideUserInterfaceStyle = .dark
		case .system:
			navigationController.overrideUserInterfaceStyle = .unspecified
		}
		return navigationController
	}
}
