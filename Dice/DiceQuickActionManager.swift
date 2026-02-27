import UIKit
#if canImport(WidgetKit)
import WidgetKit
#endif

enum DiceQuickActionType: String, CaseIterable {
	case rollNow = "com.kitsunesoftware.Dice.rollNow"
	case repeatLastRoll = "com.kitsunesoftware.Dice.repeatLastRoll"
	case presets = "com.kitsunesoftware.Dice.presets"
	case rollHistory = "com.kitsunesoftware.Dice.rollHistory"

	var symbolName: String {
		switch self {
		case .rollNow: return "die.face.5.fill"
		case .repeatLastRoll: return "arrow.clockwise"
		case .presets: return "list.bullet"
		case .rollHistory: return "clock.arrow.trianglehead.counterclockwise.rotate.90"
		}
	}

	var titleKey: String {
		switch self {
		case .rollNow: return "quickaction.rollNow.title"
		case .repeatLastRoll: return "quickaction.repeatLast.title"
		case .presets: return "quickaction.presets.title"
		case .rollHistory: return "quickaction.history.title"
		}
	}

	var subtitleKey: String {
		switch self {
		case .rollNow: return "quickaction.rollNow.subtitle"
		case .repeatLastRoll: return "quickaction.repeatLast.subtitle"
		case .presets: return "quickaction.presets.subtitle"
		case .rollHistory: return "quickaction.history.subtitle"
		}
	}

	var shortcutType: String { rawValue }
}

enum DiceQuickActionLibrary {
	static func dynamicItems(for snapshot: DiceWidgetRollSnapshot) -> [UIApplicationShortcutItem] {
		var types: [DiceQuickActionType] = [.rollNow]
		if !snapshot.isEmptyState {
			types.append(.repeatLastRoll)
		}
		types.append(contentsOf: [.presets, .rollHistory])
		return types.map { makeShortcutItem(type: $0, snapshot: snapshot) }
	}

	private static func makeShortcutItem(type: DiceQuickActionType, snapshot: DiceWidgetRollSnapshot) -> UIApplicationShortcutItem {
		let title = NSLocalizedString(type.titleKey, comment: "App icon quick action title")
		let subtitle: String
		if type == .repeatLastRoll, !snapshot.notation.isEmpty {
			subtitle = String(
				format: NSLocalizedString("quickaction.repeatLast.subtitle.withNotation", comment: "Repeat quick action subtitle with notation"),
				snapshot.notation
			)
		} else {
			subtitle = NSLocalizedString(type.subtitleKey, comment: "App icon quick action subtitle")
		}
		return UIApplicationShortcutItem(
			type: type.shortcutType,
			localizedTitle: title,
			localizedSubtitle: subtitle,
			icon: UIApplicationShortcutIcon(systemImageName: type.symbolName),
			userInfo: nil
		)
	}
}

final class DiceQuickActionManager {
	static let shared = DiceQuickActionManager()

	private let snapshotStore: DiceWidgetSnapshotStore
	private let quickActionApplier: ([UIApplicationShortcutItem]) -> Void

	init(
		snapshotStore: DiceWidgetSnapshotStore = DiceWidgetSnapshotStore(),
		quickActionApplier: @escaping ([UIApplicationShortcutItem]) -> Void = { UIApplication.shared.shortcutItems = $0 }
	) {
		self.snapshotStore = snapshotStore
		self.quickActionApplier = quickActionApplier
	}

	func refresh() {
		let snapshot = snapshotStore.loadSnapshot()
		quickActionApplier(DiceQuickActionLibrary.dynamicItems(for: snapshot))
#if canImport(WidgetKit)
		WidgetCenter.shared.reloadTimelines(ofKind: "DiceRollWidget")
#endif
	}
}
