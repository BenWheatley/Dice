import Foundation
import WatchKit

final class WatchCustomizeInterfaceController: WKInterfaceController {
	private let configurationSync = WatchSingleDieConfigurationSyncBridge.shared
	private var customizationState = WatchSingleDieCustomizationState(configuration: WatchSingleDieConfiguration.watchDefault)

	@IBOutlet private weak var sideCountButton: WKInterfaceButton!
	@IBOutlet private weak var colorButton: WKInterfaceButton!
	@IBOutlet private weak var modeButton: WKInterfaceButton!

	override func awake(withContext context: Any?) {
		super.awake(withContext: context)
		if let configuration = context as? WatchSingleDieConfiguration {
			customizationState = WatchSingleDieCustomizationState(configuration: configuration)
		} else {
			customizationState = WatchSingleDieCustomizationState(configuration: configurationSync.currentConfiguration())
		}
		applyUIState()
	}

	@IBAction func editSideCount() {
		let suggestions = ["2", "4", "6", "8", "10", "12", "20"]
		presentTextInputController(withSuggestions: suggestions, allowedInputMode: .plain) { [weak self] results in
			guard let self,
				  let first = results?.first as? String,
				  let parsed = Int(first.trimmingCharacters(in: .whitespacesAndNewlines)) else {
				return
			}
			self.customizationState.setSideCount(parsed)
			self.persistCustomization()
		}
	}

	@IBAction func cycleColor() {
		customizationState.cycleColorForward()
		persistCustomization()
	}

	@IBAction func toggleMode() {
		customizationState.toggleMode()
		persistCustomization()
	}

	@IBAction func closeCustomize() {
		pop()
	}

	private func persistCustomization() {
		configurationSync.updateLocalConfiguration { [customizationState] configuration in
			customizationState.apply(to: &configuration)
		}
		applyUIState()
	}

	private func applyUIState() {
		sideCountButton.setTitle("Side: \(customizationState.sideToken)")
		colorButton.setTitle("Color: \(customizationState.colorToken)")
		modeButton.setTitle("Mode: \(customizationState.modeToken)")
	}
}
