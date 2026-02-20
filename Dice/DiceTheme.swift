//
//  DiceTheme.swift
//  Dice
//
//  Created by Codex on 17.02.26.
//

import UIKit

enum DiceTheme: String, CaseIterable {
	case lightMode
	case darkMode
	case system

	var menuTitleKey: String {
		switch self {
		case .lightMode:
			return "theme.lightMode"
		case .darkMode:
			return "theme.darkMode"
		case .system:
			return "theme.system"
		}
	}

	var palette: DiceThemePalette {
		switch self {
		case .lightMode:
			return DiceThemePalette(
				screenBackgroundColor: UIColor(white: 0.97, alpha: 1.0),
				panelBackgroundColor: UIColor(white: 1.0, alpha: 0.95),
				primaryTextColor: UIColor(white: 0.08, alpha: 1.0),
				secondaryTextColor: UIColor(white: 0.28, alpha: 1.0),
				validationColor: .systemRed,
				fieldBorderErrorColor: .systemRed,
				fallbackDieBackgroundColor: UIColor(white: 1.0, alpha: 0.8),
				fallbackDieBorderColor: UIColor(white: 0.25, alpha: 1.0),
				fallbackDieTextColor: .black
			)
		case .darkMode:
			return DiceThemePalette(
				screenBackgroundColor: UIColor(red: 0.12, green: 0.15, blue: 0.18, alpha: 1.0),
				panelBackgroundColor: UIColor(red: 0.20, green: 0.24, blue: 0.28, alpha: 0.94),
				primaryTextColor: UIColor(red: 0.94, green: 0.96, blue: 0.98, alpha: 1.0),
				secondaryTextColor: UIColor(red: 0.83, green: 0.87, blue: 0.91, alpha: 1.0),
				validationColor: UIColor(red: 1.0, green: 0.49, blue: 0.48, alpha: 1.0),
				fieldBorderErrorColor: UIColor(red: 1.0, green: 0.49, blue: 0.48, alpha: 1.0),
				fallbackDieBackgroundColor: UIColor(red: 0.25, green: 0.30, blue: 0.34, alpha: 0.95),
				fallbackDieBorderColor: UIColor(red: 0.73, green: 0.79, blue: 0.86, alpha: 1.0),
				fallbackDieTextColor: UIColor(red: 0.95, green: 0.97, blue: 0.99, alpha: 1.0)
			)
		case .system:
			return DiceThemePalette(
				screenBackgroundColor: .systemBackground,
				panelBackgroundColor: UIColor.secondarySystemBackground.withAlphaComponent(0.9),
				primaryTextColor: .label,
				secondaryTextColor: .secondaryLabel,
				validationColor: .systemRed,
				fieldBorderErrorColor: .systemRed,
				fallbackDieBackgroundColor: UIColor.systemBackground.withAlphaComponent(0.8),
				fallbackDieBorderColor: .separator,
				fallbackDieTextColor: .label
			)
		}
	}
}
