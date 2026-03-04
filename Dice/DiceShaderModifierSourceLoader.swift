import Foundation

enum DiceShaderModifierSourceLoader {
	private static var cache: [String: String] = [:]
	private static let cacheLock = NSLock()

	static func surfaceShaderModifier(forStoneFinish: Bool) -> String? {
		let resourceName = forStoneFinish ? "DiceSurfaceStoneShader" : "DiceSurfaceBaseShader"
		return loadResource(named: resourceName, extension: "metal")
	}

	static func tableSurfaceShaderModifier() -> String? {
		loadResource(named: "DiceTableSurfaceShader", extension: "metal")
	}

	private static func loadResource(named resource: String, extension ext: String) -> String? {
		let key = "\(resource).\(ext)"
		cacheLock.lock()
		if let cached = cache[key] {
			cacheLock.unlock()
			return cached
		}
		cacheLock.unlock()

		let bundle = Bundle(for: BundleToken.self)
		guard let url = bundle.url(forResource: resource, withExtension: ext),
			  let data = try? Data(contentsOf: url),
			  let source = String(data: data, encoding: .utf8) else {
			return nil
		}

		cacheLock.lock()
		cache[key] = source
		cacheLock.unlock()
		return source
	}
}

private final class BundleToken {}
