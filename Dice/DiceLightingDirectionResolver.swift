import Foundation
import simd

enum DiceLightingDirectionResolver {
	private static let southernHemisphereRegionCodes: Set<String> = [
		"AR", "AU", "BO", "BR", "BW", "CL", "FJ", "ID", "KE", "LS", "MG",
		"MU", "MW", "MZ", "NA", "NZ", "PG", "PY", "PE", "RW", "SB", "SG",
		"TL", "TO", "UY", "ZA", "ZM", "ZW"
	]
	private static let referenceNewMoon = Date(timeIntervalSince1970: 947182440) // 2000-01-06T18:14:00Z
	private static let synodicMonthDays = 29.530588853

	static func isNorthernHemisphere(locale: Locale = .current) -> Bool {
		guard let code = locale.region?.identifier else { return true }
		return !southernHemisphereRegionCodes.contains(code.uppercased())
	}

	static func direction(
		mode: DiceLightingAngle,
		date: Date,
		timeZone: TimeZone,
		isNorthernHemisphere: Bool
	) -> SIMD3<Float> {
		switch mode {
		case .fixed:
			let equatorSign: Float = isNorthernHemisphere ? 1 : -1
			return normalize(SIMD3<Float>(0.70, 0.70 * equatorSign, 0.78))
		case .natural:
			return naturalDirection(date: date, timeZone: timeZone, isNorthernHemisphere: isNorthernHemisphere)
		}
	}

	static func isDaytime(date: Date, timeZone: TimeZone) -> Bool {
		let hour = localClockHour(date: date, timeZone: timeZone)
		return hour >= 6 && hour < 18
	}

	private static func naturalDirection(date: Date, timeZone: TimeZone, isNorthernHemisphere: Bool) -> SIMD3<Float> {
		let hour = localClockHour(date: date, timeZone: timeZone)
		let dayOfYear = localDayOfYear(date: date, timeZone: timeZone)
		let equatorSign: Float = isNorthernHemisphere ? 1 : -1
		let season = Float(sin((2 * Double.pi * Double(dayOfYear - 80)) / 365.25))

		if hour >= 6 && hour < 18 {
			// Daytime sun arc: east-west clock progression plus a mild seasonal declination shift.
			let hourAngle = Float((hour - 12) / 12 * Double.pi)
			let x = sin(hourAngle) * 0.72
			let y = cos(hourAngle) * equatorSign + season * 0.18 * equatorSign
			let z = max(0.20, 0.20 + 0.80 * cos(hourAngle))
			return normalize(SIMD3<Float>(x, y, z))
		}

		// Night moon arc: phase offset avoids identical nightly shadows while keeping predictable movement.
		let moonAgeDays = moonAge(date: date)
		let moonPhaseAngle = Float((moonAgeDays / synodicMonthDays) * (2 * Double.pi))
		let hourAngle = Float((hour - 24) / 12 * Double.pi)
		let nightAzimuth = hourAngle + moonPhaseAngle + (Float.pi / 6)
		let x = sin(nightAzimuth) * 0.64
		let y = cos(nightAzimuth) * equatorSign * 0.58
		let centeredNightHour = hour > 12 ? hour - 24 : hour
		let nightPeak = max(0.0, cos(Float(centeredNightHour / 12 * Double.pi)))
		let z = 0.08 + 0.24 * nightPeak
		return normalize(SIMD3<Float>(x, y, z))
	}

	private static func localClockHour(date: Date, timeZone: TimeZone) -> Double {
		var calendar = Calendar(identifier: .gregorian)
		calendar.timeZone = timeZone
		let components = calendar.dateComponents([.hour, .minute, .second], from: date)
		let hour = Double(components.hour ?? 12)
		let minute = Double(components.minute ?? 0)
		let second = Double(components.second ?? 0)
		return hour + (minute / 60) + (second / 3600)
	}

	private static func localDayOfYear(date: Date, timeZone: TimeZone) -> Int {
		var calendar = Calendar(identifier: .gregorian)
		calendar.timeZone = timeZone
		return calendar.ordinality(of: .day, in: .year, for: date) ?? 1
	}

	private static func moonAge(date: Date) -> Double {
		let days = date.timeIntervalSince(referenceNewMoon) / 86_400
		let wrapped = days.truncatingRemainder(dividingBy: synodicMonthDays)
		return wrapped >= 0 ? wrapped : wrapped + synodicMonthDays
	}

	private static func normalize(_ value: SIMD3<Float>) -> SIMD3<Float> {
		let length = simd_length(value)
		if length < 0.0001 {
			return SIMD3<Float>(0.0, 0.0, 1.0)
		}
		return value / length
	}
}
