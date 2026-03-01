import Charts
import SwiftUI
import UIKit

struct DiceRollDistributionPoint: Identifiable, Equatable {
	let face: Int
	let count: Int

	var id: Int { face }
}

enum DiceRollDistributionChartData {
	static func points(from counts: [Int]) -> [DiceRollDistributionPoint] {
		counts.enumerated().map { offset, count in
			DiceRollDistributionPoint(face: offset + 1, count: count)
		}
	}
}

struct DiceRollDistributionChartView: View {
	let points: [DiceRollDistributionPoint]
	let yAxisTitle: String
	let barColor: Color
	let axisColor: Color
	let gridColor: Color

	var body: some View {
		Chart(points) { point in
			BarMark(
				x: .value("Face", point.face),
				y: .value("Count", point.count)
			)
			.foregroundStyle(barColor)
		}
		.chartYAxisLabel(yAxisTitle, position: .leading)
		.chartXAxis {
			AxisMarks(values: points.map(\.face)) {
				AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
					.foregroundStyle(gridColor)
				AxisTick(stroke: StrokeStyle(lineWidth: 0.5))
					.foregroundStyle(axisColor)
				AxisValueLabel()
					.foregroundStyle(axisColor)
                    .font(.system(size: 9))
			}
		}
		.chartYAxis {
			AxisMarks(position: .leading) {
				AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
					.foregroundStyle(gridColor)
				AxisTick(stroke: StrokeStyle(lineWidth: 0.5))
					.foregroundStyle(axisColor)
				AxisValueLabel()
					.foregroundStyle(axisColor)
			}
		}
		.chartPlotStyle { plot in
			plot.background(.clear)
		}
		.background(.clear)
	}
}
