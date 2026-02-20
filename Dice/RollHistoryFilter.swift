import Foundation

struct RollHistoryFilter: Equatable {
	var searchText: String
	var mode: RollHistoryModeFilter
	var dateRange: RollHistoryDateRangeFilter

	static let `default` = RollHistoryFilter(searchText: "", mode: .all, dateRange: .all)
}
