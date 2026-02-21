PROJECT := Dice.xcodeproj
IOS_SCHEME := Dice
WATCH_SCHEME := Dice WatchKit App
IOS_DEST := platform=iOS Simulator,name=iPhone 16
WATCH_DEST := platform=watchOS Simulator,name=Apple Watch Series 10 (46mm)
CATALYST_DEST := platform=macOS,variant=Mac Catalyst

.PHONY: list test-ios build-watch build-catalyst analyze-ios lint format-check guard-rendering install-hooks

list:
	xcodebuild -list -project "$(PROJECT)"

test-ios:
	xcodebuild test -project "$(PROJECT)" -scheme "$(IOS_SCHEME)" -destination '$(IOS_DEST)'

build-watch:
	xcodebuild build -project "$(PROJECT)" -scheme "$(WATCH_SCHEME)" -destination '$(WATCH_DEST)'

build-catalyst:
	xcodebuild build -project "$(PROJECT)" -scheme "$(IOS_SCHEME)" -destination '$(CATALYST_DEST)'

analyze-ios:
	xcodebuild analyze -project "$(PROJECT)" -scheme "$(IOS_SCHEME)" -destination '$(IOS_DEST)'

lint:
	@if command -v swiftlint >/dev/null 2>&1; then \
		swiftlint --strict; \
	else \
		echo "swiftlint not installed. Install from https://github.com/realm/SwiftLint"; \
		exit 2; \
	fi

format-check:
	@if command -v swift-format >/dev/null 2>&1; then \
		swift-format lint --recursive Dice DiceTests DiceUITests "Dice WatchKit Extension"; \
	else \
		echo "swift-format not installed. Install via Swift toolchain."; \
		exit 2; \
	fi

guard-rendering:
	./scripts/guards/rendering_guard.sh

install-hooks:
	./scripts/install-git-hooks.sh
