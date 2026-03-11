//
//  WatchSingleDieConfigurationSyncBridge.swift
//  Dice
//
//  Created by Codex on 11.03.26.
//

import Foundation
#if canImport(WatchConnectivity) && !targetEnvironment(macCatalyst)
import WatchConnectivity
#endif

struct WatchSingleDieConfiguration: Codable, Equatable {
	static let minimumSideCount = 2
	static let maximumSideCount = 100

	var sideCount: Int
	var colorTag: String
	var isIntuitiveMode: Bool
	var backgroundTexture: String
	var updatedAt: Date

	init(
		sideCount: Int = 6,
		colorTag: String = "ivory",
		isIntuitiveMode: Bool = false,
		backgroundTexture: String = "neutral",
		updatedAt: Date = Date()
	) {
		self.sideCount = Self.clamp(sideCount)
		self.colorTag = colorTag
		self.isIntuitiveMode = isIntuitiveMode
		self.backgroundTexture = backgroundTexture
		self.updatedAt = updatedAt
	}

	func withCurrentTimestamp() -> WatchSingleDieConfiguration {
		WatchSingleDieConfiguration(
			sideCount: sideCount,
			colorTag: colorTag,
			isIntuitiveMode: isIntuitiveMode,
			backgroundTexture: backgroundTexture,
			updatedAt: Date()
		)
	}

	static func clamp(_ sideCount: Int) -> Int {
		min(max(sideCount, minimumSideCount), maximumSideCount)
	}
}

final class WatchSingleDieConfigurationStore {
	private enum Keys {
		static let configuration = "Dice.watchSingleDieConfiguration.v1"
	}

	private let defaults: UserDefaults
	private let decoder = JSONDecoder()
	private let encoder = JSONEncoder()

	init(defaults: UserDefaults = .standard) {
		self.defaults = defaults
	}

	var hasPersistedConfiguration: Bool {
		defaults.data(forKey: Keys.configuration) != nil
	}

	func load() -> WatchSingleDieConfiguration {
		guard let data = defaults.data(forKey: Keys.configuration) else {
			return WatchSingleDieConfiguration()
		}
		guard let decoded = try? decoder.decode(WatchSingleDieConfiguration.self, from: data) else {
			return WatchSingleDieConfiguration()
		}
		return WatchSingleDieConfiguration(
			sideCount: decoded.sideCount,
			colorTag: decoded.colorTag,
			isIntuitiveMode: decoded.isIntuitiveMode,
			backgroundTexture: decoded.backgroundTexture,
			updatedAt: decoded.updatedAt
		)
	}

	func save(_ configuration: WatchSingleDieConfiguration) {
		guard let encoded = try? encoder.encode(configuration) else { return }
		defaults.set(encoded, forKey: Keys.configuration)
	}
}

enum WatchSingleDieConfigurationConflictResolver {
	// Last-write-wins with timestamp is acceptable here because this is a single-user,
	// multi-device preference sync problem: there is no multi-user concurrent authoring model.
	// The newest write should become source-of-truth, and ties prefer remote to converge peers.
	static func resolve(local: WatchSingleDieConfiguration, remote: WatchSingleDieConfiguration) -> WatchSingleDieConfiguration {
		if remote.updatedAt > local.updatedAt {
			return remote
		}
		if remote.updatedAt < local.updatedAt {
			return local
		}
		return remote
	}
}

final class WatchSingleDieConfigurationSyncBridge: NSObject {
	private enum PayloadKeys {
		static let configurationData = "watchSingleDieConfigurationData"
	}

	static let shared = WatchSingleDieConfigurationSyncBridge()

	private let store: WatchSingleDieConfigurationStore
	private let encoder = JSONEncoder()
	private let decoder = JSONDecoder()

	var onRemoteConfigurationApplied: ((WatchSingleDieConfiguration) -> Void)?

	init(store: WatchSingleDieConfigurationStore = WatchSingleDieConfigurationStore()) {
		self.store = store
		super.init()
	}

	func start() {
		#if canImport(WatchConnectivity) && !targetEnvironment(macCatalyst)
		guard WCSession.isSupported() else { return }
		let session = WCSession.default
		session.delegate = self
		session.activate()
		#endif
	}

	var hasPersistedConfiguration: Bool {
		store.hasPersistedConfiguration
	}

	func currentConfiguration() -> WatchSingleDieConfiguration {
		store.load()
	}

	func seedLocalIfMissing(_ configuration: WatchSingleDieConfiguration) {
		guard !store.hasPersistedConfiguration else { return }
		store.save(configuration)
		publish(configuration)
	}

	func updateLocalConfiguration(_ mutate: (inout WatchSingleDieConfiguration) -> Void) {
		var configuration = store.load()
		mutate(&configuration)
		configuration = configuration.withCurrentTimestamp()
		store.save(configuration)
		publish(configuration)
	}

	func applyPhoneSnapshotIfChanged(_ snapshot: WatchSingleDieConfiguration) {
		let local = store.load()
		guard local.sideCount != snapshot.sideCount
				|| local.colorTag != snapshot.colorTag
				|| local.isIntuitiveMode != snapshot.isIntuitiveMode
				|| local.backgroundTexture != snapshot.backgroundTexture else {
			return
		}
		let updated = WatchSingleDieConfiguration(
			sideCount: snapshot.sideCount,
			colorTag: snapshot.colorTag,
			isIntuitiveMode: snapshot.isIntuitiveMode,
			backgroundTexture: snapshot.backgroundTexture,
			updatedAt: Date()
		)
		store.save(updated)
		publish(updated)
	}

	@discardableResult
	func applyRemoteConfiguration(_ remote: WatchSingleDieConfiguration) -> WatchSingleDieConfiguration {
		let local = store.load()
		let winner = WatchSingleDieConfigurationConflictResolver.resolve(local: local, remote: remote)
		if winner != local {
			store.save(winner)
			DispatchQueue.main.async { [weak self] in
				self?.onRemoteConfigurationApplied?(winner)
			}
			return winner
		}
		publish(local)
		return local
	}

	private func publish(_ configuration: WatchSingleDieConfiguration) {
		#if canImport(WatchConnectivity) && !targetEnvironment(macCatalyst)
		guard WCSession.isSupported() else { return }
		guard let payload = payload(for: configuration) else { return }
		do {
			try WCSession.default.updateApplicationContext(payload)
		} catch {
			// Best-effort sync: keep local persisted state as source of truth and retry on next update.
		}
		#endif
	}

	private func payload(for configuration: WatchSingleDieConfiguration) -> [String: Any]? {
		guard let data = try? encoder.encode(configuration) else { return nil }
		return [PayloadKeys.configurationData: data]
	}

	private func configuration(from applicationContext: [String: Any]) -> WatchSingleDieConfiguration? {
		guard let data = applicationContext[PayloadKeys.configurationData] as? Data else { return nil }
		return try? decoder.decode(WatchSingleDieConfiguration.self, from: data)
	}
}

#if canImport(WatchConnectivity) && !targetEnvironment(macCatalyst)
extension WatchSingleDieConfigurationSyncBridge: WCSessionDelegate {
	func session(
		_ session: WCSession,
		activationDidCompleteWith activationState: WCSessionActivationState,
		error: Error?
	) {
		guard activationState == .activated else { return }
		publish(store.load())
	}

	func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
		guard let incoming = configuration(from: applicationContext) else { return }
		_ = applyRemoteConfiguration(incoming)
	}

	#if os(iOS)
	func sessionDidBecomeInactive(_ session: WCSession) {}

	func sessionDidDeactivate(_ session: WCSession) {
		session.activate()
	}
	#endif
}
#endif
