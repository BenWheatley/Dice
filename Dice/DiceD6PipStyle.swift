enum DiceD6PipStyle: String, CaseIterable {
	case round
	case square

	var menuTitleKey: String {
		switch self {
		case .round:
			return "pipStyle.round"
		case .square:
			return "pipStyle.square"
		}
	}
}
