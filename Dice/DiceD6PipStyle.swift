enum DiceD6PipStyle: String, CaseIterable {
	case round
	case square
	case inset

	var menuTitleKey: String {
		switch self {
		case .round:
			return "pipStyle.round"
		case .square:
			return "pipStyle.square"
		case .inset:
			return "pipStyle.inset"
		}
	}
}
