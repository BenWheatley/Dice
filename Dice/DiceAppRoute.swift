import Foundation

enum DiceAppRoute: Equatable {
	case roll
	case repeatLastRoll
	case history
	case presets

	init?(url: URL) {
		guard let scheme = url.scheme?.lowercased(), scheme == "dice" else { return nil }
		let host = url.host?.lowercased()
		let path = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/")).lowercased()
		let token = (host?.isEmpty == false ? host : path)
		switch token {
		case "roll": self = .roll
		case "repeat": self = .repeatLastRoll
		case "history": self = .history
		case "presets": self = .presets
		default: return nil
		}
	}
}

enum DiceRouteNotificationKey {
	static let route = "route"
}

extension Notification.Name {
	static let diceRouteRequested = Notification.Name("Dice.routeRequested")
}
