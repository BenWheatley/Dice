//
//  DiceCubeView.swift
//  Dice
//
//  Created by Ben Wheatley on 15.02.26.
//  Copyright © 2026 Ben Wheatley. All rights reserved.
//

import UIKit
import SceneKit
import simd

final class DiceCubeView: UIView {
	private static let faceTextureEdgeLength: CGFloat = 256
	private static let neutralTextureName = "stripes"

	private static let neutralTableTextureImage: UIImage? = {
		let bundles = [Bundle.main, Bundle(for: DiceCubeView.self)]
		for bundle in bundles {
			if let image = UIImage(named: neutralTextureName, in: bundle, compatibleWith: nil) {
				return image
			}
		}
		return UIImage(named: neutralTextureName)
	}()

	private static let neutralTableTexturePixelSize: CGSize = {
		guard let image = neutralTableTextureImage else { return .zero }
		if let cgImage = image.cgImage {
			return CGSize(width: cgImage.width, height: cgImage.height)
		}
		return CGSize(width: image.size.width * image.scale, height: image.size.height * image.scale)
	}()
	private struct MeshCacheKey: Hashable {
		let sideCount: Int
		let roundedSideLength: Int
		let dieFinish: DiceDieFinish
	}

	private struct BadgeCacheKey: Hashable {
		let value: Int
		let roundedBadgeSize: Int
		let font: DiceFaceNumeralFont
		let sideCount: Int
		let showsSideCount: Bool
	}

	private struct MeshData {
		let vertices: [SIMD3<Float>]
		let faces: [[Int]]
	}

	private struct BuiltMesh {
		let geometry: SCNGeometry
		let faceNormals: [SIMD3<Float>]
		let faceUps: [SIMD3<Float>]
		let materialFaces: [[Int]]
	}

	private struct FaceTextureSet {
		let diffuse: UIImage
		let normal: UIImage
		let metalness: UIImage
		let roughness: UIImage
	}

	private struct FaceTextureCacheKey: Hashable {
		let sideCount: Int
		let value: Int
		let d4VertexLabels: [Int]
		let fillRed: UInt8
		let fillGreen: UInt8
		let fillBlue: UInt8
		let fillAlpha: UInt8
		let fontRawValue: String
		let largeLabels: Bool
	}

	private static var sharedFaceTextureSetCache: [FaceTextureCacheKey: FaceTextureSet] = [:]
	private static let sharedFaceTextureSetCacheLock = NSLock()
	private static var sharedBadgeImageCache: [BadgeCacheKey: UIImage] = [:]
	private static let sharedBadgeImageCacheLock = NSLock()

	private let scnView = SCNView()
	private let scene = SCNScene()
	private let cameraNode = SCNNode()
	private let tableNode = SCNNode()
	private let tableMaterial = SCNMaterial()
	private var dieNodes: [SCNNode] = []
	private var currentSideLength: CGFloat = 0
	private var dieSideCounts: [Int] = []
	private var appliedColorOverrides: [DiceDieColorPreset?] = []
	private var appliedFontOverrides: [DiceFaceNumeralFont?] = []
	private var appliedAppearanceGeneration: [Int] = []
	private var appearanceGeneration: Int = 0
	private var orientationCache: [Int: [Int: SCNVector3]] = [:]
	private var meshCache: [MeshCacheKey: BuiltMesh] = [:]
	private var labelValueCache: [ObjectIdentifier: Int] = [:]
	private var lifecycleObservers: [NSObjectProtocol] = []
	private var activeDieFinish: DiceDieFinish = .matte
	private var activeEdgeOutlinesEnabled = false
	private var activeDieColorPreferences: DiceDieColorPreferences = .default
	private var activeD6PipStyle: DiceD6PipStyle = .round
	private var activeFaceNumeralFont: DiceFaceNumeralFont = .classic
	private var activeLargeFaceLabelsEnabled = false
	private var activeAnimationIntensity: DiceAnimationIntensity = .full
	private var activeMotionBlurEnabled = false
	private var activeTableTexture: DiceTableTexture = .neutral
	private var selectedDieIndex: Int?
	private var reduceMotionEnabled = UIAccessibility.isReduceMotionEnabled
	private var dieAccessibilityElements: [UIAccessibilityElement] = []
	private var needsMeshRefresh = false
	private var activeRollAnimationToken: Int = 0
	private var pendingRollAnimationCompletions = 0
	private let supportedPolyhedralSideCounts: Set<Int> = [4, 6, 8, 10, 12, 20]
	// D4 numbering is vertex-based and intentionally decoupled from raw mesh indices.
	private let d4VertexValueByIndex: [Int] = [4, 3, 2, 1]
#if DEBUG
	private var debugMaterialRefreshCount = 0
	private var debugMeshBuildCount = 0
#endif
	var onRollSettled: (() -> Void)?
	var onDieTapped: ((Int, CGPoint) -> Void)?

	static func dieAccessibilityIdentifier(for index: Int) -> String {
		"die_\(index)"
	}

	static func dieIndex(fromAccessibilityIdentifier identifier: String?) -> Int? {
		guard let identifier else { return nil }
		guard identifier.hasPrefix("die_") else { return nil }
		return Int(identifier.dropFirst("die_".count))
	}

	override init(frame: CGRect) {
		super.init(frame: frame)
		configureScene()
		configureLifecycleObservers()
	}

	required init?(coder: NSCoder) {
		super.init(coder: coder)
		configureScene()
		configureLifecycleObservers()
	}

	deinit {
		for observer in lifecycleObservers {
			NotificationCenter.default.removeObserver(observer)
		}
	}

	override func layoutSubviews() {
		super.layoutSubviews()
		updateCamera(animated: false)
	}

	func setDice(
		values: [Int],
		centers: [CGPoint],
		sideLength: CGFloat,
		sideCounts: [Int],
		dieColorPresets: [DiceDieColorPreset?] = [],
		faceNumeralFonts: [DiceFaceNumeralFont?] = [],
		lockedIndices: Set<Int> = [],
		animated: Bool
	) {
		guard values.count == centers.count, values.count == sideCounts.count else { return }
		ensureNodeCount(values.count)
		let motionProfile = DiceMotionBehaviorProfile.resolve(intensity: activeAnimationIntensity, reduceMotionEnabled: reduceMotionEnabled)
		let shouldAnimateRoll = animated && activeAnimationIntensity != .off && motionProfile.duration > 0
		let animatingIndices = shouldAnimateRoll ? values.indices.filter { !lockedIndices.contains($0) } : []
		if shouldAnimateRoll {
			activeRollAnimationToken += 1
			pendingRollAnimationCompletions = animatingIndices.count
		} else {
			pendingRollAnimationCompletions = 0
		}
		let rollToken = activeRollAnimationToken

		let sizeChanged = abs(currentSideLength - sideLength) > 0.5
		if sizeChanged {
			currentSideLength = sideLength
			for node in dieNodes {
				let label = node.childNode(withName: "label", recursively: false)
				label?.geometry = makeLabelGeometry(sideLength: sideLength)
				label?.position = SCNVector3(0, 0, Float(sideLength * 0.65))
			}
		}

		let styleChanged = needsMeshRefresh
		for index in values.indices {
			let container = dieNodes[index]
			container.name = Self.dieAccessibilityIdentifier(for: index)
			let sideCount = sideCounts[index]
			let didSideChange = dieSideCounts[index] != sideCount
			if didSideChange || sizeChanged || styleChanged {
				let body = container.childNode(withName: "body", recursively: false)
				let mesh = builtMesh(sideLength: sideLength, sideCount: sideCount)
				// Geometry materials are mutated per die (color/font overrides); avoid sharing instances.
				body?.geometry = (mesh.geometry.copy() as? SCNGeometry) ?? mesh.geometry
				let outline = container.childNode(withName: "outline", recursively: false)
				if let bodyGeometry = body?.geometry {
					outline?.geometry = makeOutlineGeometry(from: bodyGeometry)
				}
				outline?.isHidden = !activeEdgeOutlinesEnabled
				dieSideCounts[index] = sideCount
			}
			let colorPreset = index < dieColorPresets.count ? dieColorPresets[index] : nil
			let numeralFont = index < faceNumeralFonts.count ? faceNumeralFonts[index] : nil
			let needsAppearanceRefresh = didSideChange ||
				sizeChanged ||
				styleChanged ||
				appliedAppearanceGeneration[index] != appearanceGeneration ||
				appliedColorOverrides[index] != colorPreset ||
				appliedFontOverrides[index] != numeralFont
			if needsAppearanceRefresh {
				let body = container.childNode(withName: "body", recursively: false)
				applyFaceMaterials(
					to: body?.geometry,
					sideCount: sideCount,
					sideLength: sideLength,
					colorPresetOverride: colorPreset,
					faceNumeralFontOverride: numeralFont,
					dieIndex: index
				)
				appliedColorOverrides[index] = colorPreset
				appliedFontOverrides[index] = numeralFont
				appliedAppearanceGeneration[index] = appearanceGeneration
			}

			let showLabel = sideCount != 6
			let labelNode = container.childNode(withName: "label", recursively: false)
			labelNode?.isHidden = !showLabel
			if showLabel, let labelNode {
				let cacheKey = ObjectIdentifier(labelNode)
				let previousValue = labelValueCache[cacheKey]
				if sizeChanged || didSideChange || previousValue != values[index] {
					(labelNode.geometry as? SCNPlane)?.firstMaterial?.diffuse.contents = valueBadgeImage(
						values[index],
						sideLength: sideLength,
						sideCount: sideCount,
						font: numeralFont ?? activeFaceNumeralFont
					)
					labelValueCache[cacheKey] = values[index]
				}
			}

			let targetPosition = scenePosition(for: centers[index])
			let targetFace = values[index]
			let startPosition = SCNVector3(container.presentation.position.x, container.presentation.position.y, 0)

			if shouldAnimateRoll && !lockedIndices.contains(index) {
				animateRoll(
					node: container,
					from: startPosition,
					to: targetPosition,
					faceValue: targetFace,
					sideLength: sideLength,
					sideCount: sideCount,
					motionProfile: motionProfile
				) { [weak self] in
					self?.handleRollAnimationCompletion(for: rollToken)
				}
			} else {
				container.removeAllActions()
				container.position = targetPosition
				container.eulerAngles = orientation(for: targetFace, sideCount: sideCount)
			}
		}
		updateAccessibilityElements(
			values: values,
			sideCounts: sideCounts,
			centers: centers,
			sideLength: sideLength,
			lockedIndices: lockedIndices
		)
		applySelectionAppearance(animated: false)
		needsMeshRefresh = false
	}

	func setDieFinish(_ finish: DiceDieFinish) {
		guard activeDieFinish != finish else { return }
		activeDieFinish = finish
		appearanceGeneration += 1
		needsMeshRefresh = true
	}

	func setEdgeOutlinesEnabled(_ enabled: Bool) {
		guard activeEdgeOutlinesEnabled != enabled else { return }
		activeEdgeOutlinesEnabled = enabled
		appearanceGeneration += 1
		needsMeshRefresh = true
	}

	func setDieColorPreferences(_ preferences: DiceDieColorPreferences) {
		guard activeDieColorPreferences != preferences else { return }
		activeDieColorPreferences = preferences
		appearanceGeneration += 1
		meshCache.removeAll()
		clearSharedTextureCaches(clearBadges: false)
		needsMeshRefresh = true
	}

	func setD6PipStyle(_ style: DiceD6PipStyle) {
		guard activeD6PipStyle != style else { return }
		activeD6PipStyle = style
		appearanceGeneration += 1
		meshCache.removeAll()
		clearSharedTextureCaches(clearBadges: false)
		needsMeshRefresh = true
	}

	func setFaceNumeralFont(_ font: DiceFaceNumeralFont) {
		guard activeFaceNumeralFont != font else { return }
		activeFaceNumeralFont = font
		appearanceGeneration += 1
	}

	func setLargeFaceLabelsEnabled(_ enabled: Bool) {
		guard activeLargeFaceLabelsEnabled != enabled else { return }
		activeLargeFaceLabelsEnabled = enabled
		appearanceGeneration += 1
	}

	private func clearSharedTextureCaches(clearBadges: Bool) {
		Self.sharedFaceTextureSetCacheLock.lock()
		Self.sharedFaceTextureSetCache.removeAll()
		Self.sharedFaceTextureSetCacheLock.unlock()
		guard clearBadges else { return }
		Self.sharedBadgeImageCacheLock.lock()
		Self.sharedBadgeImageCache.removeAll()
		Self.sharedBadgeImageCacheLock.unlock()
	}

	func setAnimationIntensity(_ intensity: DiceAnimationIntensity) {
		activeAnimationIntensity = intensity
	}

	func setTableTexture(_ texture: DiceTableTexture) {
		guard activeTableTexture != texture else { return }
		activeTableTexture = texture
		applyTableTexture()
	}

	func setMotionBlurEnabled(_ enabled: Bool) {
		activeMotionBlurEnabled = enabled
		cameraNode.camera?.motionBlurIntensity = enabled ? 0.45 : 0.0
	}

	func setSelectedDieIndex(_ index: Int?) {
		selectedDieIndex = index
		applySelectionAppearance(animated: true)
	}

	private func configureScene() {
		backgroundColor = .clear
		isUserInteractionEnabled = true

		scnView.translatesAutoresizingMaskIntoConstraints = false
		scnView.backgroundColor = .clear
		scnView.isUserInteractionEnabled = true
		scnView.antialiasingMode = .multisampling4X
		scnView.autoenablesDefaultLighting = true
		scnView.scene = scene
		addSubview(scnView)

		NSLayoutConstraint.activate([
			scnView.leadingAnchor.constraint(equalTo: leadingAnchor),
			scnView.trailingAnchor.constraint(equalTo: trailingAnchor),
			scnView.topAnchor.constraint(equalTo: topAnchor),
			scnView.bottomAnchor.constraint(equalTo: bottomAnchor),
		])
		let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
		scnView.addGestureRecognizer(tapRecognizer)

		cameraNode.camera = SCNCamera()
		cameraNode.camera?.usesOrthographicProjection = true
		cameraNode.camera?.zNear = 1
		cameraNode.camera?.zFar = 10_000
		cameraNode.camera?.motionBlurIntensity = activeMotionBlurEnabled ? 0.45 : 0.0
		cameraNode.position = SCNVector3(0, 0, 800)
		cameraNode.eulerAngles = SCNVector3(0, 0, 0)
		scene.rootNode.addChildNode(cameraNode)
		configureTableSurface()

		let keyLight = SCNNode()
		keyLight.light = SCNLight()
		keyLight.light?.type = .omni
		keyLight.light?.intensity = 900
		keyLight.position = SCNVector3(160, 220, 280)
		scene.rootNode.addChildNode(keyLight)

		let fillLight = SCNNode()
		fillLight.light = SCNLight()
		fillLight.light?.type = .ambient
		fillLight.light?.intensity = 350
		scene.rootNode.addChildNode(fillLight)
	}

	private func configureLifecycleObservers() {
		let center = NotificationCenter.default
		let resignObserver = center.addObserver(
			forName: UIApplication.willResignActiveNotification,
			object: nil,
			queue: .main
		) { [weak self] _ in
			self?.scnView.isPlaying = false
		}
		let becomeObserver = center.addObserver(
			forName: UIApplication.didBecomeActiveNotification,
			object: nil,
			queue: .main
		) { [weak self] _ in
			self?.scnView.isPlaying = true
		}
		let reduceMotionObserver = center.addObserver(
			forName: UIAccessibility.reduceMotionStatusDidChangeNotification,
			object: nil,
			queue: .main
		) { [weak self] _ in
			guard let self else { return }
			self.reduceMotionEnabled = UIAccessibility.isReduceMotionEnabled
		}
		lifecycleObservers = [resignObserver, becomeObserver, reduceMotionObserver]
	}

	private func updateCamera(animated: Bool) {
		cameraNode.camera?.orthographicScale = Double(bounds.height / 2)
		updateTableSurfaceSize()
		let target = (position: SCNVector3(0, 0, 800), euler: SCNVector3(0, 0, 0))
		guard animated else {
			cameraNode.position = target.position
			cameraNode.eulerAngles = target.euler
			return
		}
		SCNTransaction.begin()
		SCNTransaction.animationDuration = 0.28
		cameraNode.position = target.position
		cameraNode.eulerAngles = target.euler
		SCNTransaction.commit()
	}

	private func configureTableSurface() {
		let plane = SCNPlane(width: 10, height: 10)
		tableMaterial.lightingModel = .constant
		tableMaterial.isDoubleSided = false
		tableMaterial.diffuse.wrapS = .repeat
		tableMaterial.diffuse.wrapT = .repeat
		tableMaterial.writesToDepthBuffer = false
		tableMaterial.readsFromDepthBuffer = false
		if let tableShader = DiceShaderModifierSourceLoader.tableSurfaceShaderModifier() {
			tableMaterial.shaderModifiers = [.surface: tableShader]
		}
		plane.materials = [tableMaterial]
		tableNode.geometry = plane
		tableNode.position = SCNVector3(0, 0, -150)
		tableNode.renderingOrder = -100
		scene.rootNode.addChildNode(tableNode)
		applyTableTexture()
		applyTableTextureScale()
	}

	private func applyTableTexture() {
		tableMaterial.setValue(tableTextureModeValue(for: activeTableTexture), forKey: "tableTextureMode")
		if activeTableTexture == .neutral, let neutralTexture = Self.neutralTableTextureImage {
			tableMaterial.diffuse.contents = neutralTexture
			tableMaterial.diffuse.minificationFilter = .nearest
			tableMaterial.diffuse.magnificationFilter = .nearest
			tableMaterial.diffuse.mipFilter = .none
		} else {
			tableMaterial.diffuse.contents = UIColor(red: 0.88, green: 0.88, blue: 0.88, alpha: 1.0)
			tableMaterial.diffuse.minificationFilter = .linear
			tableMaterial.diffuse.magnificationFilter = .linear
			tableMaterial.diffuse.mipFilter = .none
		}
		applyTableTextureScale()
	}

	private func applyTableTextureScale() {
		let scale = max(1, min(bounds.width, bounds.height))
		let pointScale = tableTexturePointScale()
		tableMaterial.setValue(scale as NSNumber, forKey: "tableTextureScale")
		tableMaterial.setValue(pointScale.width as NSNumber, forKey: "tableTextureScaleX")
		tableMaterial.setValue(pointScale.height as NSNumber, forKey: "tableTextureScaleY")
		if activeTableTexture == .neutral,
			Self.neutralTableTexturePixelSize.width > 0,
			Self.neutralTableTexturePixelSize.height > 0 {
			let repeatX = Float(pointScale.width / Self.neutralTableTexturePixelSize.width)
			let repeatY = Float(pointScale.height / Self.neutralTableTexturePixelSize.height)
			tableMaterial.diffuse.contentsTransform = SCNMatrix4MakeScale(repeatX, repeatY, 1)
		} else {
			tableMaterial.diffuse.contentsTransform = SCNMatrix4Identity
		}
	}

	private func tableTexturePointScale() -> CGSize {
		// Point mapping should track visible view points, not oversized background geometry.
		return CGSize(width: max(1, bounds.width), height: max(1, bounds.height))
	}

	private func tableTextureModeValue(for texture: DiceTableTexture) -> NSNumber {
		switch texture {
		case .felt:
			return 0
		case .wood:
			return 1
		case .neutral:
			return 2
		}
	}

	private func updateTableSurfaceSize() {
		guard let plane = tableNode.geometry as? SCNPlane else { return }
		// Use a diagonal-sized surface to avoid exposed edges during layout/camera transitions.
		let diagonal = hypot(bounds.width, bounds.height)
		let span = max(10, diagonal * 1.12)
		plane.width = span
		plane.height = span
		applyTableTextureScale()
	}

	private func usesCoinGeometry(for sideCount: Int) -> Bool {
		sideCount == 2
	}

	private func usesTokenGeometry(for sideCount: Int) -> Bool {
		!usesCoinGeometry(for: sideCount) && !supportedPolyhedralSideCounts.contains(sideCount)
	}

	private func usesPinnedRollPosition(for sideCount: Int) -> Bool {
		usesCoinGeometry(for: sideCount) || usesTokenGeometry(for: sideCount)
	}

	private func ensureNodeCount(_ count: Int) {
		if dieNodes.count > count {
			for node in dieNodes[count...] {
				if let label = node.childNode(withName: "label", recursively: false) {
					labelValueCache.removeValue(forKey: ObjectIdentifier(label))
				}
				node.removeFromParentNode()
			}
			dieNodes = Array(dieNodes.prefix(count))
			dieSideCounts = Array(dieSideCounts.prefix(count))
			appliedColorOverrides = Array(appliedColorOverrides.prefix(count))
			appliedFontOverrides = Array(appliedFontOverrides.prefix(count))
			appliedAppearanceGeneration = Array(appliedAppearanceGeneration.prefix(count))
		}

		while dieNodes.count < count {
			let container = SCNNode()
			container.name = "die"

			let body = SCNNode()
			body.name = "body"
			body.geometry = builtMesh(sideLength: max(currentSideLength, 60), sideCount: 6).geometry
			container.addChildNode(body)

			let outline = SCNNode()
			outline.name = "outline"
			outline.geometry = makeOutlineGeometry(from: body.geometry!)
			outline.isHidden = !activeEdgeOutlinesEnabled
			container.addChildNode(outline)

			let label = SCNNode()
			label.name = "label"
			label.geometry = makeLabelGeometry(sideLength: max(currentSideLength, 60))
			label.position = SCNVector3(0, 0, Float(max(currentSideLength, 60) * 0.65))
			let bb = SCNBillboardConstraint()
			bb.freeAxes = .all
			label.constraints = [bb]
			container.addChildNode(label)
			labelValueCache[ObjectIdentifier(label)] = nil

			scene.rootNode.addChildNode(container)
			dieNodes.append(container)
			dieSideCounts.append(6)
			appliedColorOverrides.append(nil)
			appliedFontOverrides.append(nil)
			appliedAppearanceGeneration.append(-1)
		}
		if let selectedDieIndex, selectedDieIndex >= dieNodes.count {
			self.selectedDieIndex = nil
		}
	}

	private func applySelectionAppearance(animated: Bool) {
		let hasSelection = selectedDieIndex != nil
		let applyBlock = {
			for (index, node) in self.dieNodes.enumerated() {
				let isSelected = self.selectedDieIndex == index
				let scale: Float = isSelected ? 1.08 : 1.0
				let alpha: CGFloat = hasSelection && !isSelected ? 0.92 : 1.0
				node.scale = SCNVector3(scale, scale, scale)
				node.opacity = alpha
			}
		}
		guard animated else {
			applyBlock()
			return
		}
		SCNTransaction.begin()
		SCNTransaction.animationDuration = 0.16
		applyBlock()
		SCNTransaction.commit()
	}

	@objc private func handleTap(_ recognizer: UITapGestureRecognizer) {
		let point = recognizer.location(in: scnView)
		guard let index = dieIndex(at: point) else { return }
		onDieTapped?(index, recognizer.location(in: self))
	}

	private func dieIndex(at point: CGPoint) -> Int? {
		let hits = scnView.hitTest(point, options: [SCNHitTestOption.ignoreHiddenNodes: true])
		for hit in hits {
			var current: SCNNode? = hit.node
			while let node = current {
				if let dieIndex = Self.dieIndex(fromAccessibilityIdentifier: node.name) {
					return dieIndex
				}
				current = node.parent
			}
		}
		// Fallback to a generous screen-space die radius so taps work across the full die footprint.
		let radius = max(36, currentSideLength * 0.62)
		var nearest: (index: Int, distanceSquared: CGFloat)?
		for (index, node) in dieNodes.enumerated() {
			let projected = scnView.projectPoint(node.presentation.position)
			guard projected.z >= 0, projected.z <= 1 else { continue }
			let dx = CGFloat(projected.x) - point.x
			let dy = CGFloat(projected.y) - point.y
			let distanceSquared = dx * dx + dy * dy
			if distanceSquared <= radius * radius {
				if let currentNearest = nearest {
					if distanceSquared < currentNearest.distanceSquared {
						nearest = (index, distanceSquared)
					}
				} else {
					nearest = (index, distanceSquared)
				}
			}
		}
		if let nearest {
			return nearest.index
		}
		return nil
	}

	func accessibilityElementForDie(at index: Int) -> UIAccessibilityElement? {
		dieAccessibilityElements.first {
			Self.dieIndex(fromAccessibilityIdentifier: $0.accessibilityIdentifier) == index
		}
	}

	private func updateAccessibilityElements(
		values: [Int],
		sideCounts: [Int],
		centers: [CGPoint],
		sideLength: CGFloat,
		lockedIndices: Set<Int>
	) {
		guard values.count == sideCounts.count, values.count == centers.count else { return }
		isAccessibilityElement = false
		let touchSide = max(sideLength, 44)
		let elements = values.indices.map { index in
			let element = UIAccessibilityElement(accessibilityContainer: self)
			element.accessibilityIdentifier = Self.dieAccessibilityIdentifier(for: index)
			element.accessibilityTraits = .button
			element.accessibilityLabel = String(
				format: NSLocalizedString("a11y.die.label", comment: "Die button accessibility label format"),
				index + 1,
				sideCounts[index]
			)
			element.accessibilityValue = String(values[index])
			element.accessibilityHint = lockedIndices.contains(index)
				? NSLocalizedString("a11y.die.lockedHint", comment: "Locked die accessibility hint")
				: NSLocalizedString("a11y.die.hint", comment: "Die button accessibility hint")
			let center = centers[index]
			element.accessibilityFrameInContainerSpace = CGRect(
				x: center.x - touchSide / 2,
				y: center.y - touchSide / 2,
				width: touchSide,
				height: touchSide
			)
			return element
		}
		dieAccessibilityElements = elements
		accessibilityElements = elements
	}

	private func meshData(for sideCount: Int) -> MeshData {
		switch sideCount {
		case 4:
			return MeshData(vertices: tetrahedronVertices(), faces: tetrahedronFaces())
		case 6:
			return MeshData(vertices: cubeVertices(), faces: cubeFaces())
		case 8:
			return MeshData(vertices: octahedronVertices(), faces: octahedronFaces())
		case 10:
			let d10 = pentagonalTrapezohedron()
			return MeshData(vertices: d10.vertices, faces: d10.faces)
		case 12:
			let d12 = dodecahedronFromIcosahedronDual()
			return MeshData(vertices: d12.vertices, faces: d12.faces)
		case 20:
			let d20 = icosahedron()
			return MeshData(vertices: d20.vertices, faces: d20.faces)
		default:
			return MeshData(vertices: cubeVertices(), faces: cubeFaces())
		}
	}

#if DEBUG
	static func debugResolvedColorPreset(
		sideCount: Int,
		colorPresetOverride: DiceDieColorPreset?,
		dieColorPreferences: DiceDieColorPreferences
	) -> DiceDieColorPreset {
		let view = DiceCubeView(frame: .zero)
		view.activeDieColorPreferences = dieColorPreferences
		return view.resolvedColorPreset(sideCount: sideCount, colorPresetOverride: colorPresetOverride)
	}

	static func debugSymbolInkColor(fillColor: UIColor) -> UIColor {
		let view = DiceCubeView(frame: .zero)
		return view.symbolInkColor(for: fillColor)
	}

	static func debugMeshData(sideCount: Int) -> (vertices: [SIMD3<Float>], faces: [[Int]]) {
		let view = DiceCubeView(frame: .zero)
		let mesh = view.meshData(for: sideCount)
		return (mesh.vertices, mesh.faces)
	}

	static func debugD4FaceVertexLabels() -> [[Int]] {
		let view = DiceCubeView(frame: .zero)
		return view.tetrahedronFaces().map { view.d4VertexLabels(forFace: $0) }
	}

	static func debugD4OrderedFaceVertexLabels() -> [[Int]] {
		let view = DiceCubeView(frame: .zero)
		let faces = view.builtMesh(sideLength: 120, sideCount: 4).materialFaces
		return faces.map { view.d4VertexLabels(forFace: $0) }
	}

	static func debugD4MaterialFaceVertexLabels() -> [[Int]] {
		let view = DiceCubeView(frame: .zero)
		let faces = view.builtMesh(sideLength: 120, sideCount: 4).materialFaces
		return faces.map { view.d4VertexLabels(forFace: $0) }
	}

	static func debugD4GeometryFaceVertexLabels() -> [[Int]] {
		let view = DiceCubeView(frame: .zero)
		let mesh = view.builtMesh(sideLength: 120, sideCount: 4)
		return mesh.materialFaces.map { view.d4VertexLabels(forFace: $0) }
	}

	static func debugD4TopVertex(for value: Int) -> Int {
		let view = DiceCubeView(frame: .zero)
		let orientation = view.orientation(for: value, sideCount: 4)
		let node = SCNNode()
		node.eulerAngles = orientation
		let vertices = view.tetrahedronVertices()
		var bestIndex = 0
		var bestZ = -Float.greatestFiniteMagnitude
		for (index, vertex) in vertices.enumerated() {
			let transformed = node.simdConvertPosition(vertex, to: nil)
			if transformed.z > bestZ {
				bestZ = transformed.z
				bestIndex = index
			}
		}
		guard view.d4VertexValueByIndex.indices.contains(bestIndex) else { return 1 }
		return view.d4VertexValueByIndex[bestIndex]
	}

	static func debugD4LabelLayout(size: CGSize) -> (triangle: [CGPoint], placements: [(position: CGPoint, angle: CGFloat)]) {
		let view = DiceCubeView(frame: .zero)
		let triangle = view.d4TrianglePoints(size: size)
		let placements = view.d4LabelPlacements(triangle: triangle)
		return (triangle: triangle, placements: placements)
	}

	static func debugUsesUniqueGeometryPerDie(sideCount: Int) -> Bool {
		let view = DiceCubeView(frame: CGRect(x: 0, y: 0, width: 320, height: 240))
		view.setDice(
			values: [1, 2],
			centers: [CGPoint(x: 90, y: 120), CGPoint(x: 230, y: 120)],
			sideLength: 96,
			sideCounts: [sideCount, sideCount],
			dieColorPresets: [.crimson, .sapphire],
			faceNumeralFonts: [.classic, .classic],
			lockedIndices: [],
			animated: false
		)
		guard view.dieNodes.count >= 2 else { return false }
		let g0 = view.dieNodes[0].childNode(withName: "body", recursively: false)?.geometry
		let g1 = view.dieNodes[1].childNode(withName: "body", recursively: false)?.geometry
		guard let g0, let g1 else { return false }
		return g0 !== g1
	}

	static func debugGeometrySummary(sideCount: Int) -> (typeName: String, materialCount: Int) {
		let view = DiceCubeView(frame: CGRect(x: 0, y: 0, width: 320, height: 240))
		let mesh = view.builtMesh(sideLength: 96, sideCount: sideCount)
		return (typeName: String(describing: type(of: mesh.geometry)), materialCount: mesh.geometry.materials.count)
	}

	static func debugFallbackCylinderProfile(sideCount: Int, sideLength: CGFloat = 96) -> (typeName: String, radius: CGFloat, height: CGFloat, materialCount: Int) {
		let view = DiceCubeView(frame: CGRect(x: 0, y: 0, width: 320, height: 240))
		let mesh = view.builtMesh(sideLength: sideLength, sideCount: sideCount)
		guard let cylinder = mesh.geometry as? SCNCylinder else {
			return (typeName: String(describing: type(of: mesh.geometry)), radius: 0, height: 0, materialCount: mesh.geometry.materials.count)
		}
		return (
			typeName: "SCNCylinder",
			radius: cylinder.radius,
			height: cylinder.height,
			materialCount: cylinder.materials.count
		)
	}

	static func debugMaterialRefreshCountsForConsecutiveSetDice(
		valuesFirst: [Int],
		valuesSecond: [Int],
		sideCounts: [Int],
		colorOverrides: [DiceDieColorPreset?],
		fontOverrides: [DiceFaceNumeralFont?]
	) -> (firstPass: Int, secondPass: Int) {
		let count = min(valuesFirst.count, valuesSecond.count, sideCounts.count)
		guard count > 0 else { return (firstPass: 0, secondPass: 0) }
		let view = DiceCubeView(frame: CGRect(x: 0, y: 0, width: 360, height: 240))
		let centers: [CGPoint] = (0..<count).map { index in
			CGPoint(x: 54 + (CGFloat(index) * 96), y: 120)
		}

		let firstValues = Array(valuesFirst.prefix(count))
		let secondValues = Array(valuesSecond.prefix(count))
		let trimmedSideCounts = Array(sideCounts.prefix(count))
		let trimmedColors = Array(colorOverrides.prefix(count))
		let trimmedFonts = Array(fontOverrides.prefix(count))

		view.debugMaterialRefreshCount = 0
		view.setDice(
			values: firstValues,
			centers: centers,
			sideLength: 92,
			sideCounts: trimmedSideCounts,
			dieColorPresets: trimmedColors,
			faceNumeralFonts: trimmedFonts,
			lockedIndices: [],
			animated: false
		)
		let firstPass = view.debugMaterialRefreshCount
		view.setDice(
			values: secondValues,
			centers: centers,
			sideLength: 92,
			sideCounts: trimmedSideCounts,
			dieColorPresets: trimmedColors,
			faceNumeralFonts: trimmedFonts,
			lockedIndices: [],
			animated: false
		)
		return (firstPass: firstPass, secondPass: view.debugMaterialRefreshCount - firstPass)
	}

	static func debugMaterialRefreshCountsForSideLengthChange(
		values: [Int],
		sideCounts: [Int],
		colorOverrides: [DiceDieColorPreset?],
		fontOverrides: [DiceFaceNumeralFont?],
		sideLengthFirst: CGFloat,
		sideLengthSecond: CGFloat
	) -> (firstPass: Int, secondPass: Int) {
		let count = min(values.count, sideCounts.count)
		guard count > 0 else { return (firstPass: 0, secondPass: 0) }
		let view = DiceCubeView(frame: CGRect(x: 0, y: 0, width: 360, height: 240))
		let centers: [CGPoint] = (0..<count).map { index in
			CGPoint(x: 54 + (CGFloat(index) * 96), y: 120)
		}
		let trimmedValues = Array(values.prefix(count))
		let trimmedSideCounts = Array(sideCounts.prefix(count))
		let trimmedColors = Array(colorOverrides.prefix(count))
		let trimmedFonts = Array(fontOverrides.prefix(count))

		view.debugMaterialRefreshCount = 0
		view.setDice(
			values: trimmedValues,
			centers: centers,
			sideLength: sideLengthFirst,
			sideCounts: trimmedSideCounts,
			dieColorPresets: trimmedColors,
			faceNumeralFonts: trimmedFonts,
			lockedIndices: [],
			animated: false
		)
		let firstPass = view.debugMaterialRefreshCount
		view.setDice(
			values: trimmedValues,
			centers: centers,
			sideLength: sideLengthSecond,
			sideCounts: trimmedSideCounts,
			dieColorPresets: trimmedColors,
			faceNumeralFonts: trimmedFonts,
			lockedIndices: [],
			animated: false
		)
		return (firstPass: firstPass, secondPass: view.debugMaterialRefreshCount - firstPass)
	}

	static func debugTableTextureMode(for texture: DiceTableTexture) -> Int {
		let view = DiceCubeView(frame: CGRect(x: 0, y: 0, width: 320, height: 240))
		view.setTableTexture(texture)
		return (view.tableMaterial.value(forKey: "tableTextureMode") as? NSNumber)?.intValue ?? -1
	}

	static func debugMeshBuildCountsForGlobalFontChange(
		values: [Int],
		sideCounts: [Int],
		colorOverrides: [DiceDieColorPreset?],
		fontInitial: DiceFaceNumeralFont,
		fontChanged: DiceFaceNumeralFont
	) -> (firstPass: Int, secondPass: Int) {
		let count = min(values.count, sideCounts.count)
		guard count > 0 else { return (firstPass: 0, secondPass: 0) }
		let view = DiceCubeView(frame: CGRect(x: 0, y: 0, width: 360, height: 240))
		let centers: [CGPoint] = (0..<count).map { index in
			CGPoint(x: 54 + (CGFloat(index) * 96), y: 120)
		}
		let trimmedValues = Array(values.prefix(count))
		let trimmedSideCounts = Array(sideCounts.prefix(count))
		let trimmedColors = Array(colorOverrides.prefix(count))
		let emptyFonts = Array(repeating: Optional<DiceFaceNumeralFont>.none, count: count)

		view.setFaceNumeralFont(fontInitial)
		view.debugMeshBuildCount = 0
		view.setDice(
			values: trimmedValues,
			centers: centers,
			sideLength: 92,
			sideCounts: trimmedSideCounts,
			dieColorPresets: trimmedColors,
			faceNumeralFonts: emptyFonts,
			lockedIndices: [],
			animated: false
		)
		let firstPass = view.debugMeshBuildCount

		view.setFaceNumeralFont(fontChanged)
		view.debugMeshBuildCount = 0
		view.setDice(
			values: trimmedValues,
			centers: centers,
			sideLength: 92,
			sideCounts: trimmedSideCounts,
			dieColorPresets: trimmedColors,
			faceNumeralFonts: emptyFonts,
			lockedIndices: [],
			animated: false
		)
		return (firstPass: firstPass, secondPass: view.debugMeshBuildCount)
	}

	static func debugTableTextureScale(for size: CGSize) -> CGFloat {
		let view = DiceCubeView(frame: CGRect(origin: .zero, size: size))
		view.layoutIfNeeded()
		return CGFloat((view.tableMaterial.value(forKey: "tableTextureScale") as? NSNumber)?.doubleValue ?? 0)
	}

	static func debugTableTexturePointScale(for size: CGSize) -> CGSize {
		let view = DiceCubeView(frame: CGRect(origin: .zero, size: size))
		view.layoutIfNeeded()
		let x = CGFloat((view.tableMaterial.value(forKey: "tableTextureScaleX") as? NSNumber)?.doubleValue ?? 0)
		let y = CGFloat((view.tableMaterial.value(forKey: "tableTextureScaleY") as? NSNumber)?.doubleValue ?? 0)
		return CGSize(width: x, height: y)
	}

	static func debugTablePlaneSize(for size: CGSize) -> CGSize {
		let view = DiceCubeView(frame: CGRect(origin: .zero, size: size))
		view.layoutIfNeeded()
		guard let plane = view.tableNode.geometry as? SCNPlane else { return .zero }
		return CGSize(width: plane.width, height: plane.height)
	}

	static func debugNeutralTableTexturePixelSize() -> CGSize {
		neutralTableTexturePixelSize
	}

	static func debugNeutralTableTextureRepeat(for size: CGSize) -> CGSize {
		let view = DiceCubeView(frame: CGRect(origin: .zero, size: size))
		view.setTableTexture(.neutral)
		view.layoutIfNeeded()
		let transform = view.tableMaterial.diffuse.contentsTransform
		return CGSize(width: CGFloat(transform.m11), height: CGFloat(transform.m22))
	}

	static func debugOrientation(value: Int, sideCount: Int) -> SCNVector3 {
		let view = DiceCubeView(frame: CGRect(x: 0, y: 0, width: 320, height: 240))
		return view.orientation(for: value, sideCount: sideCount)
	}

	static func debugCylindricalAnimationEulerAngles(
		sideCount: Int,
		targetValue: Int,
		progress: Float,
		motionScale: Float,
		spinDirection: Int
	) -> SCNVector3 {
		let view = DiceCubeView(frame: CGRect(x: 0, y: 0, width: 320, height: 240))
		let direction: Float = spinDirection >= 0 ? 1 : -1
		return view.cylindricalAnimationEulerAngles(
			sideCount: sideCount,
			targetValue: targetValue,
			progress: progress,
			motionScale: motionScale,
			spinDirection: direction
		)
	}

	static func debugCoinCapTextureSummary(fillColor: UIColor) -> (
		sideUsesImageTexture: Bool,
		topUsesImageTexture: Bool,
		bottomUsesImageTexture: Bool,
		topAndBottomShareSameReference: Bool
	) {
		let view = DiceCubeView(frame: .zero)
		let materials = view.coinMaterials(fillColor: fillColor, numeralFont: .classic, dieIndex: 0)
		guard materials.count == 3 else {
			return (false, false, false, false)
		}
		let side = materials[0].diffuse.contents
		let top = materials[1].diffuse.contents
		let bottom = materials[2].diffuse.contents
		let topObject = top as AnyObject?
		let bottomObject = bottom as AnyObject?
		return (
			sideUsesImageTexture: side is UIImage,
			topUsesImageTexture: top is UIImage,
			bottomUsesImageTexture: bottom is UIImage,
			topAndBottomShareSameReference: topObject === bottomObject
		)
	}

	static func debugUsesPinnedRollPosition(sideCount: Int) -> Bool {
		let view = DiceCubeView(frame: .zero)
		return view.usesPinnedRollPosition(for: sideCount)
	}
#endif

	private func buildGeometry(sideLength: CGFloat, sideCount: Int) -> BuiltMesh {
#if DEBUG
		debugMeshBuildCount += 1
#endif
		if sideCount == 2 {
			let coin = SCNCylinder(radius: sideLength * 0.48, height: max(6, sideLength * 0.14))
			coin.radialSegmentCount = 72
			coin.materials = [SCNMaterial(), SCNMaterial(), SCNMaterial()]
			return BuiltMesh(
				geometry: coin,
				faceNormals: [SIMD3<Float>(0, 0, 1)],
				faceUps: [SIMD3<Float>(0, 1, 0)],
				materialFaces: [[0]]
			)
		}

		if !supportedPolyhedralSideCounts.contains(sideCount) {
			let token = SCNCylinder(radius: sideLength * 0.48, height: max(10, sideLength * 0.30))
			token.radialSegmentCount = 60
			token.materials = [SCNMaterial(), SCNMaterial(), SCNMaterial()]
			return BuiltMesh(
				geometry: token,
				faceNormals: [SIMD3<Float>(0, 0, 1)],
				faceUps: [SIMD3<Float>(0, 1, 0)],
				materialFaces: [[0]]
			)
		}

		let mesh = meshData(for: sideCount)
		let maxNorm = mesh.vertices.map { simd_length($0) }.max() ?? 1
		let scale = Float(sideLength * 0.5) / maxNorm
		let scaledVerts = mesh.vertices.map { $0 * scale }

		var finalVertices: [SCNVector3] = []
		var finalUVs: [CGPoint] = []
		var elements: [SCNGeometryElement] = []
		var materials: [SCNMaterial] = []
		var faceNormals: [SIMD3<Float>] = []
		var faceUps: [SIMD3<Float>] = []
		var materialFaces: [[Int]] = []

		for (faceIndex, face) in mesh.faces.enumerated() {
			guard face.count >= 3 else { continue }

			var workingFace = face
			var points = workingFace.map { scaledVerts[$0] }
			let center = points.reduce(SIMD3<Float>(repeating: 0), +) / Float(points.count)
			var n = simd_normalize(simd_cross(points[1] - points[0], points[2] - points[0]))
			// Force outward normals so face orientation and texturing remain consistent.
			if simd_dot(n, center) < 0 {
				workingFace = Array(workingFace.reversed())
				points = workingFace.map { scaledVerts[$0] }
				n = simd_normalize(simd_cross(points[1] - points[0], points[2] - points[0]))
			}
			if sideCount == 4 {
				workingFace = d4OrderedFaceVertices(for: workingFace, vertices: scaledVerts)
				points = workingFace.map { scaledVerts[$0] }
				n = simd_normalize(simd_cross(points[1] - points[0], points[2] - points[0]))
				// Keep tetrahedron winding outward after custom top/left/right ordering.
				// Without this, some faces can mirror labels due to flipped vertex order.
				if simd_dot(n, center) < 0 {
					workingFace.swapAt(1, 2)
					points = workingFace.map { scaledVerts[$0] }
					n = simd_normalize(simd_cross(points[1] - points[0], points[2] - points[0]))
				}
			}
			let up = simd_normalize(points[1] - points[0])
			faceNormals.append(n)
			faceUps.append(up)

			let u = up
			let v = simd_normalize(simd_cross(n, u))
			var maxProj: Float = 0.001
			for p in points {
				let d = p - center
				maxProj = max(maxProj, abs(simd_dot(d, u)), abs(simd_dot(d, v)))
			}

			var faceTriIndices: [Int32] = []
			for i in 1..<(face.count - 1) {
				let tri = [points[0], points[i], points[i + 1]]
				let base = Int32(finalVertices.count)
				for (vertexIndex, p) in tri.enumerated() {
					// D4 labels represent vertex values; map texture coordinates directly to
					// triangle corners so each face corner can carry one vertex number.
					if sideCount == 4 {
						let d4UVs = [
							CGPoint(x: 0.5, y: 0.10),
							CGPoint(x: 0.14, y: 0.86),
							CGPoint(x: 0.86, y: 0.86),
						]
						finalVertices.append(SCNVector3(p.x, p.y, p.z))
						finalUVs.append(d4UVs[vertexIndex])
						continue
					}

					let d = p - center
					let px = simd_dot(d, u) / maxProj
					let py = simd_dot(d, v) / maxProj
					// Project each face to a local 2D plane for stable UV placement.
					finalVertices.append(SCNVector3(p.x, p.y, p.z))
					finalUVs.append(CGPoint(
						x: 0.5 - CGFloat(py) * 0.45,
						y: 0.5 - CGFloat(px) * 0.45
					))
				}
				faceTriIndices += [base, base + 1, base + 2]
			}

			elements.append(SCNGeometryElement(indices: faceTriIndices, primitiveType: .triangles))
			materials.append(faceMaterial(faceIndex: faceIndex, face: workingFace, sideCount: sideCount))
			materialFaces.append(workingFace)
		}

		let vSource = SCNGeometrySource(vertices: finalVertices)
		let uvSource = SCNGeometrySource(textureCoordinates: finalUVs)
		let geometry: SCNGeometry
		if sideCount == 6 {
			// D6 uses a beveled cube body while preserving the same face ordering.
			let box = D6SceneKitRenderConfig.beveledCube(sideLength: sideLength)
			box.materials = materials
			geometry = box
		} else {
			geometry = SCNGeometry(sources: [vSource, uvSource], elements: elements)
			geometry.materials = materials
		}
		return BuiltMesh(geometry: geometry, faceNormals: faceNormals, faceUps: faceUps, materialFaces: materialFaces)
	}

	private func builtMesh(sideLength: CGFloat, sideCount: Int) -> BuiltMesh {
		let roundedSideLength = Int(sideLength.rounded())
		let key = MeshCacheKey(sideCount: sideCount, roundedSideLength: roundedSideLength, dieFinish: activeDieFinish)
		if let cached = meshCache[key] {
			return cached
		}
		let mesh = buildGeometry(sideLength: CGFloat(roundedSideLength), sideCount: sideCount)
		meshCache[key] = mesh
		return mesh
	}

	private func faceMaterial(
		faceIndex: Int,
		face: [Int],
		sideCount: Int,
		fillColor: UIColor? = nil,
		numeralFont: DiceFaceNumeralFont? = nil,
		dieIndex: Int = 0
	) -> SCNMaterial {
		let material = SCNMaterial()
		let value = faceIndex + 1
		let resolvedFillColor = fillColor ?? activeDieColorPreferences.fillColor(for: sideCount)
		let resolvedFont = numeralFont ?? activeFaceNumeralFont
		let textureSet: FaceTextureSet
		if sideCount == 6 {
			let d6TextureSet = D6SceneKitRenderConfig.faceTextureSet(value: value, fillColor: resolvedFillColor, pipStyle: activeD6PipStyle)
			textureSet = FaceTextureSet(
				diffuse: d6TextureSet.diffuse,
				normal: d6TextureSet.normal,
				metalness: d6TextureSet.metalness,
				roughness: d6TextureSet.roughness
			)
		} else if sideCount == 4 {
			let vertexLabels = d4VertexLabels(forFace: face)
			textureSet = cachedFaceTextureSet(
				sideCount: sideCount,
				value: value,
				d4VertexLabels: vertexLabels,
				fillColor: resolvedFillColor,
				numeralFont: resolvedFont
			) {
				d4FaceTextureSet(vertexLabels: vertexLabels, fillColor: resolvedFillColor, numeralFont: resolvedFont)
			}
		} else {
			textureSet = cachedFaceTextureSet(
				sideCount: sideCount,
				value: value,
				d4VertexLabels: [],
				fillColor: resolvedFillColor,
				numeralFont: resolvedFont
			) {
				faceValueTextureSet(value: value, sideCount: sideCount, fillColor: resolvedFillColor, numeralFont: resolvedFont)
			}
		}
		material.diffuse.contents = textureSet.diffuse
		material.normal.contents = textureSet.normal
		material.normal.intensity = 0.95
		material.specular.contents = textureSet.metalness
		material.metalness.contents = textureSet.metalness
		material.roughness.contents = textureSet.roughness
		material.diffuse.wrapS = .clamp
		material.diffuse.wrapT = .clamp
		material.normal.wrapS = .clamp
		material.normal.wrapT = .clamp
		material.specular.wrapS = .clamp
		material.specular.wrapT = .clamp
		material.metalness.wrapS = .clamp
		material.metalness.wrapT = .clamp
		material.roughness.wrapS = .clamp
		material.roughness.wrapT = .clamp
		// Keep symbol masks crisp; filtered+mipped mask sampling causes edge bleed on beveled D6 geometry.
		material.metalness.minificationFilter = .nearest
		material.metalness.magnificationFilter = .nearest
		material.metalness.mipFilter = .none
		material.roughness.minificationFilter = .nearest
		material.roughness.magnificationFilter = .nearest
		material.roughness.mipFilter = .none
		material.locksAmbientWithDiffuse = true
		material.isDoubleSided = false
		if activeDieFinish == .stone {
			material.emission.contents = symbolInkColor(for: resolvedFillColor)
			material.emission.intensity = 1.0
		} else {
			material.emission.contents = UIColor.black
			material.emission.intensity = 0.0
		}
		activeDieFinish.apply(to: material, baseColor: resolvedFillColor, dieIndex: dieIndex)
		material.specular.contents = textureSet.metalness
		if activeDieFinish != .stone {
			material.shininess = max(material.shininess, 0.42)
		}
		return material
	}

	private func cachedFaceTextureSet(
		sideCount: Int,
		value: Int,
		d4VertexLabels: [Int],
		fillColor: UIColor,
		numeralFont: DiceFaceNumeralFont,
		build: () -> FaceTextureSet
	) -> FaceTextureSet {
		let rgba = rgbaComponents(fillColor)
		let key = FaceTextureCacheKey(
			sideCount: sideCount,
			value: value,
			d4VertexLabels: d4VertexLabels,
			fillRed: rgba.r,
			fillGreen: rgba.g,
			fillBlue: rgba.b,
			fillAlpha: rgba.a,
			fontRawValue: numeralFont.rawValue,
			largeLabels: activeLargeFaceLabelsEnabled
		)
		Self.sharedFaceTextureSetCacheLock.lock()
		if let cached = Self.sharedFaceTextureSetCache[key] {
			Self.sharedFaceTextureSetCacheLock.unlock()
			return cached
		}
		Self.sharedFaceTextureSetCacheLock.unlock()
		let generated = build()
		Self.sharedFaceTextureSetCacheLock.lock()
		Self.sharedFaceTextureSetCache[key] = generated
		Self.sharedFaceTextureSetCacheLock.unlock()
		return generated
	}

	private func rgbaComponents(_ color: UIColor) -> (r: UInt8, g: UInt8, b: UInt8, a: UInt8) {
		var r: CGFloat = 0
		var g: CGFloat = 0
		var b: CGFloat = 0
		var a: CGFloat = 0
		if color.getRed(&r, green: &g, blue: &b, alpha: &a) {
			return (
				r: UInt8((r * 255).rounded()),
				g: UInt8((g * 255).rounded()),
				b: UInt8((b * 255).rounded()),
				a: UInt8((a * 255).rounded())
			)
		}
		var white: CGFloat = 0
		if color.getWhite(&white, alpha: &a) {
			let channel = UInt8((white * 255).rounded())
			return (r: channel, g: channel, b: channel, a: UInt8((a * 255).rounded()))
		}
		return (r: 245, g: 245, b: 245, a: 255)
	}

	private func applyFaceMaterials(
		to geometry: SCNGeometry?,
		sideCount: Int,
		sideLength: CGFloat,
		colorPresetOverride: DiceDieColorPreset?,
		faceNumeralFontOverride: DiceFaceNumeralFont?,
		dieIndex: Int
	) {
		guard let geometry else { return }
#if DEBUG
		debugMaterialRefreshCount += 1
#endif
		let fillColor = resolvedColorPreset(sideCount: sideCount, colorPresetOverride: colorPresetOverride).fillColor
		let font = faceNumeralFontOverride ?? activeFaceNumeralFont
		if sideCount == 2 {
			geometry.materials = coinMaterials(fillColor: fillColor, numeralFont: font, dieIndex: dieIndex)
			return
		}
		if usesTokenGeometry(for: sideCount) {
			geometry.materials = tokenMaterials(fillColor: fillColor, dieIndex: dieIndex)
			return
		}
		let faces = builtMesh(sideLength: sideLength, sideCount: sideCount).materialFaces
		geometry.materials = faces.enumerated().map { faceIndex, face in
			faceMaterial(
				faceIndex: faceIndex,
				face: face,
				sideCount: sideCount,
				fillColor: fillColor,
				numeralFont: font,
				dieIndex: dieIndex
			)
		}
	}

	private func resolvedColorPreset(sideCount: Int, colorPresetOverride: DiceDieColorPreset?) -> DiceDieColorPreset {
		_ = sideCount
		return colorPresetOverride ?? .ivory
	}

	private func symbolInkColor(for fillColor: UIColor) -> UIColor {
		let style = DiceFaceContrast.style(for: fillColor)
		return style.primaryInkColor
	}

	private func tokenMaterials(fillColor: UIColor, dieIndex: Int) -> [SCNMaterial] {
		let sideColor = multipliedColor(fillColor, factor: 0.78)
		let capColor = multipliedColor(fillColor, factor: 1.04)
		return [
			solidDieMaterial(baseColor: sideColor, fillColor: fillColor, dieIndex: dieIndex),
			solidDieMaterial(baseColor: capColor, fillColor: fillColor, dieIndex: dieIndex),
			solidDieMaterial(baseColor: capColor, fillColor: fillColor, dieIndex: dieIndex)
		]
	}

	private func coinMaterials(fillColor: UIColor, numeralFont: DiceFaceNumeralFont, dieIndex: Int) -> [SCNMaterial] {
		let sideColor = multipliedColor(fillColor, factor: 0.62)
		let sideMaterial = solidDieMaterial(baseColor: sideColor, fillColor: fillColor, dieIndex: dieIndex)
		let valueOneCap = faceMaterial(
			faceIndex: 0,
			face: [0, 1, 2],
			sideCount: 2,
			fillColor: fillColor,
			numeralFont: numeralFont,
			dieIndex: dieIndex
		)
		let valueTwoCap = faceMaterial(
			faceIndex: 1,
			face: [0, 1, 2],
			sideCount: 2,
			fillColor: fillColor,
			numeralFont: numeralFont,
			dieIndex: dieIndex
		)
		return [
			sideMaterial,
			valueOneCap,
			valueTwoCap
		]
	}

	private func solidDieMaterial(baseColor: UIColor, fillColor: UIColor, dieIndex: Int) -> SCNMaterial {
		let material = SCNMaterial()
		material.diffuse.contents = baseColor
		material.normal.contents = D6SceneKitRenderConfig.flatNormalMapImage()
		material.normal.intensity = 0.35
		material.specular.contents = UIColor.black
		material.metalness.contents = UIColor.black
		material.roughness.contents = UIColor.black
		material.locksAmbientWithDiffuse = true
		material.isDoubleSided = false
		material.emission.contents = UIColor.black
		material.emission.intensity = 0.0
		activeDieFinish.apply(to: material, baseColor: fillColor, dieIndex: dieIndex)
		return material
	}

	private func multipliedColor(_ color: UIColor, factor: CGFloat) -> UIColor {
		var red: CGFloat = 0
		var green: CGFloat = 0
		var blue: CGFloat = 0
		var alpha: CGFloat = 0
		if color.getRed(&red, green: &green, blue: &blue, alpha: &alpha) {
			return UIColor(
				red: max(0, min(1, red * factor)),
				green: max(0, min(1, green * factor)),
				blue: max(0, min(1, blue * factor)),
				alpha: alpha
			)
		}
		var white: CGFloat = 0
		if color.getWhite(&white, alpha: &alpha) {
			let adjusted = max(0, min(1, white * factor))
			return UIColor(white: adjusted, alpha: alpha)
		}
		return color
	}


	private func makeOutlineGeometry(from source: SCNGeometry) -> SCNGeometry {
		let outline = source.copy() as! SCNGeometry
		let outlineMaterialCount = max(1, outline.materials.count)
		outline.materials = (0..<outlineMaterialCount).map { _ in
			let material = SCNMaterial()
			material.lightingModel = .constant
			material.diffuse.contents = UIColor.clear
			material.emission.contents = UIColor(white: 0.05, alpha: 1.0)
			material.fillMode = .lines
			material.isDoubleSided = true
			return material
		}
		return outline
	}

	private func d4VertexLabels(forFace face: [Int]) -> [Int] {
		face.map { vertexIndex in
			guard d4VertexValueByIndex.indices.contains(vertexIndex) else { return 1 }
			return d4VertexValueByIndex[vertexIndex]
		}
	}

	private func d4OrderedFaceVertices(for face: [Int], vertices: [SIMD3<Float>]) -> [Int] {
		guard face.count == 3 else { return face }
		let points = face.map { vertices[$0] }
		let center = points.reduce(SIMD3<Float>(repeating: 0), +) / Float(points.count)
		let normal = simd_normalize(simd_cross(points[1] - points[0], points[2] - points[0]))

		var worldUp = SIMD3<Float>(0, 1, 0)
		if abs(simd_dot(normal, worldUp)) > 0.95 {
			worldUp = SIMD3<Float>(1, 0, 0)
		}
		let xAxis = simd_normalize(simd_cross(worldUp, normal))
		let yAxis = simd_normalize(simd_cross(normal, xAxis))

		let projected: [(vertex: Int, x: Float, y: Float)] = face.map { vertexIndex in
			let point = vertices[vertexIndex]
			let delta = point - center
			return (
				vertex: vertexIndex,
				x: simd_dot(delta, xAxis),
				y: simd_dot(delta, yAxis)
			)
		}

		guard let top = projected.max(by: { lhs, rhs in
			if lhs.y == rhs.y { return lhs.vertex > rhs.vertex }
			return lhs.y < rhs.y
		}) else {
			return face
		}
		let remaining = projected.filter { $0.vertex != top.vertex }
		guard remaining.count == 2 else { return face }
		let left: (vertex: Int, x: Float, y: Float)
		let right: (vertex: Int, x: Float, y: Float)
		if remaining[0].x <= remaining[1].x {
			left = remaining[0]
			right = remaining[1]
		} else {
			left = remaining[1]
			right = remaining[0]
		}
		return [top.vertex, left.vertex, right.vertex]
	}

	private func d4FaceTextureSet(vertexLabels: [Int], fillColor: UIColor, numeralFont: DiceFaceNumeralFont) -> FaceTextureSet {
		let size = CGSize(width: Self.faceTextureEdgeLength, height: Self.faceTextureEdgeLength)
		let rect = CGRect(origin: .zero, size: size)
		let style = DiceFaceContrast.style(for: fillColor)
		let outlineInkColor = oppositeInkColor(for: style.primaryInkColor)
		let trianglePoints = d4TrianglePoints(size: size)
		let placements = d4LabelPlacements(triangle: trianglePoints)
		let numeralSize = DiceFaceLabelSizing.textureNumeralPointSize(sideCount: 4, large: activeLargeFaceLabelsEnabled)
		let numeralOutlineWidth = max(1.6, numeralSize * 0.075)

		let drawLabels: (_ context: CGContext, _ attributes: [NSAttributedString.Key: Any]) -> Void = { context, attributes in
			for (index, placement) in placements.enumerated() where index < vertexLabels.count {
				let text = "\(vertexLabels[index])" as NSString
				let textSize = text.size(withAttributes: attributes)
				let textRect = CGRect(
					x: -textSize.width / 2,
					y: -textSize.height / 2,
					width: textSize.width,
					height: textSize.height
				)
				context.saveGState()
				context.translateBy(x: placement.position.x, y: placement.position.y)
				context.rotate(by: placement.angle)
				text.draw(in: textRect, withAttributes: attributes)
				context.restoreGState()
			}
		}

		let symbolFillMask = UIGraphicsImageRenderer(size: size).image { context in
			UIColor.black.setFill()
			context.cgContext.fill(rect)
			let attrs: [NSAttributedString.Key: Any] = [
				.font: numeralFont.numeralFont(ofSize: numeralSize),
				.foregroundColor: UIColor.white
			]
			drawLabels(context.cgContext, attrs)
		}
		let symbolOutlineMask = UIGraphicsImageRenderer(size: size).image { context in
			UIColor.black.setFill()
			context.cgContext.fill(rect)
			let attrs: [NSAttributedString.Key: Any] = [
				.font: numeralFont.numeralFont(ofSize: numeralSize),
				.foregroundColor: UIColor.clear,
				.strokeColor: UIColor.white,
				.strokeWidth: numeralOutlineWidth
			]
			drawLabels(context.cgContext, attrs)
		}

		let diffuse = UIGraphicsImageRenderer(size: size).image { context in
			context.cgContext.setFillColor(style.fillColor.cgColor)
			context.cgContext.fill(rect)

			let triangle = UIBezierPath()
			triangle.move(to: trianglePoints[0])
			triangle.addLine(to: trianglePoints[1])
			triangle.addLine(to: trianglePoints[2])
			triangle.close()
			style.fillColor.setFill()
			triangle.fill()
			style.borderColor.setStroke()
			triangle.lineWidth = 6
			triangle.stroke()

			let attrs: [NSAttributedString.Key: Any] = [
				.font: numeralFont.numeralFont(ofSize: numeralSize),
				.foregroundColor: style.primaryInkColor,
				.strokeColor: outlineInkColor,
				.strokeWidth: -numeralOutlineWidth
			]
			drawLabels(context.cgContext, attrs)
		}

		let normal = D6SceneKitRenderConfig.flatNormalMapImage()
		// Roughness/metalness textures carry masks; final PBR treatment is shader-based.
		let metalness = symbolOutlineMask
		let roughness = symbolFillMask
		return FaceTextureSet(diffuse: diffuse, normal: normal, metalness: metalness, roughness: roughness)
	}

	private func d4TrianglePoints(size: CGSize) -> [CGPoint] {
		[
			CGPoint(x: size.width * 0.50, y: size.height * 0.10),
			CGPoint(x: size.width * 0.14, y: size.height * 0.86),
			CGPoint(x: size.width * 0.86, y: size.height * 0.86),
		]
	}

	private func d4LabelPlacements(triangle: [CGPoint]) -> [(position: CGPoint, angle: CGFloat)] {
		guard triangle.count == 3 else { return [] }
		let inset: CGFloat = 0.34
		return (0..<3).map { index in
			let vertex = triangle[index]
			let otherA = triangle[(index + 1) % 3]
			let otherB = triangle[(index + 2) % 3]
			let oppositeMid = CGPoint(x: (otherA.x + otherB.x) * 0.5, y: (otherA.y + otherB.y) * 0.5)
			let towardOpposite = CGPoint(x: oppositeMid.x - vertex.x, y: oppositeMid.y - vertex.y)
			let position = CGPoint(
				x: vertex.x + towardOpposite.x * inset,
				y: vertex.y + towardOpposite.y * inset
			)
			let angle = atan2(towardOpposite.y, towardOpposite.x) - (.pi / 2)
			return (position: position, angle: angle)
		}
	}

	private func faceValueTextureSet(value: Int, sideCount: Int, fillColor: UIColor, numeralFont: DiceFaceNumeralFont) -> FaceTextureSet {
		let size = CGSize(width: Self.faceTextureEdgeLength, height: Self.faceTextureEdgeLength)
		let rect = CGRect(origin: .zero, size: size)
		let style = DiceFaceContrast.style(for: fillColor)
		let numeralOutlineColor = oppositeInkColor(for: style.primaryInkColor)
		let captionOutlineColor = oppositeInkColor(for: style.secondaryInkColor)
		let numeralSize = DiceFaceLabelSizing.textureNumeralPointSize(sideCount: sideCount, large: activeLargeFaceLabelsEnabled)
		let captionSize = DiceFaceLabelSizing.textureCaptionPointSize(large: activeLargeFaceLabelsEnabled)
		let numeralOutlineWidth = max(1.4, numeralSize * 0.075)
		let captionOutlineWidth = max(1.0, captionSize * 0.08)
		let text = "\(value)" as NSString
		let subtitle = "d\(sideCount)" as NSString

		func drawText(attributes: [NSAttributedString.Key: Any], subtitleAttributes: [NSAttributedString.Key: Any]) {
			let tSize = text.size(withAttributes: attributes)
			let tRect = CGRect(x: (size.width - tSize.width) / 2, y: (size.height - tSize.height) / 2 - 4, width: tSize.width, height: tSize.height)
			text.draw(in: tRect, withAttributes: attributes)

			let sSize = subtitle.size(withAttributes: subtitleAttributes)
			let sRect = CGRect(x: (size.width - sSize.width) / 2, y: size.height * 0.78, width: sSize.width, height: sSize.height)
			subtitle.draw(in: sRect, withAttributes: subtitleAttributes)
		}

		let symbolFillMask = UIGraphicsImageRenderer(size: size).image { context in
			UIColor.black.setFill()
			context.cgContext.fill(rect)
			drawText(
				attributes: [
					.font: numeralFont.numeralFont(ofSize: numeralSize),
					.foregroundColor: UIColor.white
				],
				subtitleAttributes: [
					.font: numeralFont.captionFont(ofSize: captionSize),
					.foregroundColor: UIColor.white
				]
			)
		}
		let symbolOutlineMask = UIGraphicsImageRenderer(size: size).image { context in
			UIColor.black.setFill()
			context.cgContext.fill(rect)
			drawText(
				attributes: [
					.font: numeralFont.numeralFont(ofSize: numeralSize),
					.foregroundColor: UIColor.clear,
					.strokeColor: UIColor.white,
					.strokeWidth: numeralOutlineWidth
				],
				subtitleAttributes: [
					.font: numeralFont.captionFont(ofSize: captionSize),
					.foregroundColor: UIColor.clear,
					.strokeColor: UIColor.white,
					.strokeWidth: captionOutlineWidth
				]
			)
		}

		let diffuse = UIGraphicsImageRenderer(size: size).image { context in
			context.cgContext.setFillColor(style.fillColor.cgColor)
			context.cgContext.fill(rect)
			context.cgContext.setStrokeColor(style.borderColor.cgColor)
			context.cgContext.setLineWidth(8)
			context.cgContext.stroke(rect.insetBy(dx: 6, dy: 6))

			drawText(
				attributes: [
					.font: numeralFont.numeralFont(ofSize: numeralSize),
					.foregroundColor: style.primaryInkColor,
					.strokeColor: numeralOutlineColor,
					.strokeWidth: -numeralOutlineWidth
				],
				subtitleAttributes: [
					.font: numeralFont.captionFont(ofSize: captionSize),
					.foregroundColor: style.secondaryInkColor,
					.strokeColor: captionOutlineColor,
					.strokeWidth: -captionOutlineWidth
				]
			)
		}

		let normal = D6SceneKitRenderConfig.flatNormalMapImage()
		// Roughness/metalness textures carry masks; final PBR treatment is shader-based.
		let metalness = symbolOutlineMask
		let roughness = symbolFillMask
		return FaceTextureSet(diffuse: diffuse, normal: normal, metalness: metalness, roughness: roughness)
	}

	private func makeLabelGeometry(sideLength: CGFloat) -> SCNGeometry {
		let plane = SCNPlane(width: sideLength * 0.45, height: sideLength * 0.45)
		let material = SCNMaterial()
		material.isDoubleSided = true
		material.diffuse.contents = UIColor.clear
		material.transparent.contents = UIColor.clear
		plane.materials = [material]
		return plane
	}

	private func valueBadgeImage(_ value: Int, sideLength: CGFloat, sideCount: Int, font: DiceFaceNumeralFont) -> UIImage {
		let badgeSize = Int((sideLength * 0.45).rounded())
		let showsSideCount = usesCoinGeometry(for: sideCount) || usesTokenGeometry(for: sideCount)
		let key = BadgeCacheKey(
			value: value,
			roundedBadgeSize: badgeSize,
			font: font,
			sideCount: sideCount,
			showsSideCount: showsSideCount
		)
		Self.sharedBadgeImageCacheLock.lock()
		if let cached = Self.sharedBadgeImageCache[key] {
			Self.sharedBadgeImageCacheLock.unlock()
			return cached
		}
		Self.sharedBadgeImageCacheLock.unlock()

		let size = CGSize(width: badgeSize, height: badgeSize)
		let renderer = UIGraphicsImageRenderer(size: size)
		let image = renderer.image { ctx in
			let rect = CGRect(origin: .zero, size: size)
			ctx.cgContext.setFillColor(UIColor(white: 1.0, alpha: 0.92).cgColor)
			ctx.cgContext.fillEllipse(in: rect)

			let text = "\(value)" as NSString
			let numeratorScale = showsSideCount ? 0.44 : DiceFaceLabelSizing.badgeNumeralScale(large: activeLargeFaceLabelsEnabled)
			let attrs: [NSAttributedString.Key: Any] = [
				.font: font.numeralFont(
					ofSize: size.height * numeratorScale
				),
				.foregroundColor: UIColor.black
			]
			let textSize = text.size(withAttributes: attrs)
			let numberYOffset = showsSideCount ? size.height * -0.08 : 0
			let textRect = CGRect(
				x: (size.width - textSize.width) / 2,
				y: (size.height - textSize.height) / 2 + numberYOffset,
				width: textSize.width,
				height: textSize.height
			)
			text.draw(in: textRect, withAttributes: attrs)
			if showsSideCount {
				let subtitle = "d\(sideCount)" as NSString
				let subtitleAttrs: [NSAttributedString.Key: Any] = [
					.font: font.captionFont(ofSize: size.height * 0.17),
					.foregroundColor: UIColor(white: 0.12, alpha: 1.0)
				]
				let subtitleSize = subtitle.size(withAttributes: subtitleAttrs)
				let subtitleRect = CGRect(
					x: (size.width - subtitleSize.width) / 2,
					y: size.height * 0.66,
					width: subtitleSize.width,
					height: subtitleSize.height
				)
				subtitle.draw(in: subtitleRect, withAttributes: subtitleAttrs)
			}
		}
		Self.sharedBadgeImageCacheLock.lock()
		Self.sharedBadgeImageCache[key] = image
		Self.sharedBadgeImageCacheLock.unlock()
		return image
	}

	private func oppositeInkColor(for inkColor: UIColor) -> UIColor {
		let luminance = inkColor.diceRelativeLuminance
		return luminance >= 0.5 ? .black : .white
	}

	private func scenePosition(for center: CGPoint) -> SCNVector3 {
		SCNVector3(center.x - bounds.midX, bounds.midY - center.y, 0)
	}

	private func animateRoll(node: SCNNode, from start: SCNVector3, to target: SCNVector3, faceValue: Int, sideLength: CGFloat, sideCount: Int, motionProfile: DiceMotionBehaviorProfile, completion: @escaping () -> Void) {
		node.removeAllActions()
		if activeAnimationIntensity == .off {
			node.position = target
			node.eulerAngles = orientation(for: faceValue, sideCount: sideCount)
			completion()
			return
		}
		if usesPinnedRollPosition(for: sideCount) {
			let spinDirection: Float = Bool.random() ? 1 : -1
			node.position = target
			node.eulerAngles = cylindricalAnimationEulerAngles(
				sideCount: sideCount,
				targetValue: faceValue,
				progress: 0,
				motionScale: motionProfile.motionScale,
				spinDirection: spinDirection
			)
			let rotateAction = makeRotateAction(
				node: node,
				targetFace: faceValue,
				sideCount: sideCount,
				duration: motionProfile.duration,
				motionScale: motionProfile.motionScale,
				cylindricalSpinDirection: spinDirection
			)
			node.runAction(rotateAction, completionHandler: completion)
			return
		}
		let moveAction = makeBounceMoveAction(
			start: start,
			target: target,
			sideLength: sideLength,
			duration: motionProfile.duration,
			motionScale: motionProfile.motionScale,
			liftMultiplier: motionProfile.liftMultiplier,
			oscillationAmplitudeMultiplier: motionProfile.oscillationAmplitude
		)
		let rotateAction = makeRotateAction(
			node: node,
			targetFace: faceValue,
			sideCount: sideCount,
			duration: motionProfile.duration,
			motionScale: motionProfile.motionScale
		)
		node.runAction(.group([moveAction, rotateAction]), completionHandler: completion)
	}

	private func handleRollAnimationCompletion(for token: Int) {
		guard token == activeRollAnimationToken else { return }
		guard pendingRollAnimationCompletions > 0 else { return }
		pendingRollAnimationCompletions -= 1
		if pendingRollAnimationCompletions == 0 {
			onRollSettled?()
		}
	}

	private func makeRotateAction(
		node: SCNNode,
		targetFace: Int,
		sideCount: Int,
		duration: TimeInterval,
		motionScale: Float,
		cylindricalSpinDirection: Float? = nil
	) -> SCNAction {
		let target = orientation(for: targetFace, sideCount: sideCount)
		if usesCoinGeometry(for: sideCount) || usesTokenGeometry(for: sideCount) {
			let spinDirection: Float = cylindricalSpinDirection ?? (Bool.random() ? 1 : -1)
			return SCNAction.customAction(duration: duration) { n, elapsed in
				let progress = Float(max(0, min(1, elapsed / CGFloat(duration))))
				n.eulerAngles = self.cylindricalAnimationEulerAngles(
					sideCount: sideCount,
					targetValue: targetFace,
					progress: progress,
					motionScale: motionScale,
					spinDirection: spinDirection
				)
			}
		}
		let current = node.presentation.eulerAngles
		let peakTime = duration * 0.16
		let decayWindow = max(0.001, duration - peakTime)
		let rampSharpness = 5.0
		let decaySharpness = 6.0

		func randomTurns(min: Int, max: Int) -> Float {
			let turns = Float(Int.random(in: min...max))
			let sign: Float = Bool.random() ? 1 : -1
			return turns * sign
		}

		let spinTarget = SCNVector3(
			target.x + randomTurns(min: 2, max: 4) * Float.pi * 2 * motionScale,
			target.y + randomTurns(min: 2, max: 4) * Float.pi * 2 * motionScale,
			target.z + randomTurns(min: 1, max: 3) * Float.pi * 2 * motionScale
		)

		let eRamp = exp(-rampSharpness)
		let rampIntegralAtPeak = peakTime * (1.0 / (1.0 - eRamp) - 1.0 / rampSharpness)
		let decayIntegralFull = decayWindow * (1.0 - exp(-decaySharpness)) / decaySharpness
		let omegaMax = 1.0 / max(0.0001, rampIntegralAtPeak + decayIntegralFull)

		return SCNAction.customAction(duration: duration) { n, elapsed in
			let t = TimeInterval(elapsed)
			let progress: Double
			if t <= peakTime {
				let scaled = t / peakTime
				let expTerm = exp(-rampSharpness * scaled)
				let rampIntegral = (t / (1.0 - eRamp)) + (peakTime / rampSharpness) * (expTerm - 1.0) / (1.0 - eRamp)
				progress = max(0, min(1, omegaMax * rampIntegral))
			} else {
				let x = t - peakTime
				let decayIntegral = decayWindow * (1.0 - exp(-decaySharpness * (x / decayWindow))) / decaySharpness
				progress = max(0, min(1, omegaMax * (rampIntegralAtPeak + decayIntegral)))
			}

			let p = Float(progress)
			let x = current.x + (spinTarget.x - current.x) * p
			let y = current.y + (spinTarget.y - current.y) * p
			let z = current.z + (spinTarget.z - current.z) * p
			n.eulerAngles = SCNVector3(x, y, z)
		}
	}

	private func cylindricalAnimationEulerAngles(
		sideCount: Int,
		targetValue: Int,
		progress: Float,
		motionScale: Float,
		spinDirection: Float
	) -> SCNVector3 {
		let clamped = max(0, min(1, progress))
		let target = orientation(for: targetValue, sideCount: sideCount)
		let turns = max(2, Int(round(3.0 * Double(max(0.5, motionScale)))))
		let spinMagnitude = Float(turns) * spinDirection * Float.pi * 2.0
		let tiltProgress = 1 - pow(1 - clamped, 3)
		let residualSpin = pow(1 - clamped, 3)
		return SCNVector3(
			target.x * tiltProgress,
			target.y * tiltProgress,
			target.z + (spinMagnitude * residualSpin)
		)
	}

	private func makeBounceMoveAction(
		start: SCNVector3,
		target: SCNVector3,
		sideLength: CGFloat,
		duration: TimeInterval,
		motionScale: Float,
		liftMultiplier: Float,
		oscillationAmplitudeMultiplier: Float
	) -> SCNAction {
		let halfW = Float(bounds.width / 2)
		let halfH = Float(bounds.height / 2)
		let margin = Float(sideLength / 2 + 6)
		let minX = -halfW + margin
		let maxX = halfW - margin
		let minY = -halfH + margin
		let maxY = halfH - margin

		var lastTime: TimeInterval = 0
		var pos = start
		var vel = SCNVector3(Float.random(in: -420...420) * motionScale, Float.random(in: -330...330) * motionScale, 0)
		let liftAmplitude = Float(sideLength) * liftMultiplier * motionScale
		let oscillationAmplitude = Float(sideLength) * oscillationAmplitudeMultiplier * motionScale
		let oscillationFrequency: Float = 9.0 * max(0.7, motionScale)

		return SCNAction.customAction(duration: duration) { node, elapsed in
			let t = TimeInterval(elapsed)
			let dt = max(0.0, t - lastTime)
			lastTime = t
			if dt <= 0 { return }

			pos.x += vel.x * Float(dt)
			pos.y += vel.y * Float(dt)

			if pos.x < minX { pos.x = minX; vel.x = -vel.x * 0.84 }
			else if pos.x > maxX { pos.x = maxX; vel.x = -vel.x * 0.84 }

			if pos.y < minY { pos.y = minY; vel.y = -vel.y * 0.84 }
			else if pos.y > maxY { pos.y = maxY; vel.y = -vel.y * 0.84 }

			let damping = powf(0.988, Float(dt * 60))
			vel.x *= damping
			vel.y *= damping

			let progress = min(1, Float(t / duration))
			let settle = expf(-4.0 * progress)
			let lift = liftAmplitude * expf(-3.0 * progress)
			let oscillation = oscillationAmplitude * expf(-6.0 * progress) * abs(sinf(oscillationFrequency * progress))
			let x = target.x + (pos.x - target.x) * settle
			let y = target.y + (pos.y - target.y) * settle + lift + oscillation
			node.position = SCNVector3(x, y, 0)
		}
	}

	private func orientation(for value: Int, sideCount: Int) -> SCNVector3 {
		if usesCoinGeometry(for: sideCount) {
			return coinTargetOrientation(for: value)
		}
		if usesTokenGeometry(for: sideCount) {
			// SCNCylinder primary axis is Y; rotate so coin/token faces point toward camera (Z).
			return SCNVector3(Float.pi * 0.5, 0, 0)
		}
		if sideCount == 6 {
			let angles = D6FaceOrientation.eulerAngles(for: value)
			return SCNVector3(angles.x, angles.y, angles.z)
		}
		if sideCount == 4 {
			return d4Orientation(for: value)
		}
		if let cached = orientationCache[sideCount]?[value] { return cached }

		let mesh = builtMesh(sideLength: 120, sideCount: sideCount)
		var map: [Int: SCNVector3] = [:]
		let targetNormal = SIMD3<Float>(0, 0, 1)
		let worldUp = SIMD3<Float>(0, 1, 0)

		for i in 0..<mesh.faceNormals.count {
			let faceValue = i + 1
			let n = simd_normalize(mesh.faceNormals[i])
			let up = simd_normalize(mesh.faceUps[i])

			// First rotate the selected face toward camera.
			let q1 = simd_quatf(from: n, to: targetNormal)
			let up1 = simd_act(q1, up)
			let upProjected = simd_normalize(SIMD3<Float>(up1.x, up1.y, 0))
			let dotVal = simd_dot(upProjected, worldUp)
			let clampedDot = max(-1 as Float, min(1 as Float, dotVal))
			let crossZ = upProjected.x * worldUp.y - upProjected.y * worldUp.x
			let angle = atan2(crossZ, clampedDot)
			// Then spin around camera axis so face numbering remains upright.
			let q2 = simd_quatf(angle: angle, axis: targetNormal)
			let q = simd_normalize(q2 * q1)

			let tmp = SCNNode()
			tmp.simdOrientation = q
			map[faceValue] = tmp.eulerAngles
		}

		orientationCache[sideCount] = map
		return map[value] ?? SCNVector3(0, 0, 0)
	}

	private func coinTargetOrientation(for value: Int) -> SCNVector3 {
		let sign: Float = value.isMultiple(of: 2) ? -1 : 1
		return SCNVector3(sign * Float.pi * 0.5, 0, 0)
	}

	private func d4Orientation(for value: Int) -> SCNVector3 {
		if let cached = orientationCache[4]?[value] {
			return cached
		}

		let vertices = tetrahedronVertices()
		let targetTop = SIMD3<Float>(0, 0, 1)
		var map: [Int: SCNVector3] = [:]

		for topValue in 1...4 {
			guard let topIndex = d4VertexValueByIndex.firstIndex(of: topValue) else { continue }
			let topVertex = simd_normalize(vertices[topIndex])
			let q1 = simd_quatf(from: topVertex, to: targetTop)

			let neighborIndex = (topIndex + 1) % 4
			let neighborDir = simd_normalize(vertices[neighborIndex] - vertices[topIndex])
			let rotatedNeighbor = simd_act(q1, neighborDir)
			let projectedNeighbor = simd_normalize(rotatedNeighbor - simd_dot(rotatedNeighbor, targetTop) * targetTop)

			let worldUp = SIMD3<Float>(0, 1, 0)
			let projectedUp = simd_normalize(worldUp - simd_dot(worldUp, targetTop) * targetTop)
			let crossVec = simd_cross(projectedNeighbor, projectedUp)
			let signed = simd_dot(crossVec, targetTop)
			let angle = atan2(signed, simd_dot(projectedNeighbor, projectedUp))
			let q2 = simd_quatf(angle: angle, axis: targetTop)

			let q = simd_normalize(q2 * q1)
			let node = SCNNode()
			node.simdOrientation = q
			map[topValue] = node.eulerAngles
		}

		orientationCache[4] = map
		return map[value] ?? SCNVector3Zero
	}

	// MARK: - Polyhedra
	private func cubeVertices() -> [SIMD3<Float>] {
		[
			SIMD3(-1, -1, -1), SIMD3(1, -1, -1), SIMD3(1, 1, -1), SIMD3(-1, 1, -1),
			SIMD3(-1, -1, 1), SIMD3(1, -1, 1), SIMD3(1, 1, 1), SIMD3(-1, 1, 1)
		]
	}

	private func cubeFaces() -> [[Int]] {
		// front, right, back, left, top, bottom
		[[4, 5, 6, 7], [5, 1, 2, 6], [1, 0, 3, 2], [0, 4, 7, 3], [7, 6, 2, 3], [0, 1, 5, 4]]
	}

	private func tetrahedronVertices() -> [SIMD3<Float>] {
		[SIMD3(1, 1, 1), SIMD3(-1, -1, 1), SIMD3(-1, 1, -1), SIMD3(1, -1, -1)]
	}

	private func tetrahedronFaces() -> [[Int]] {
		[[0, 1, 2], [0, 3, 1], [0, 2, 3], [1, 3, 2]]
	}

	private func octahedronVertices() -> [SIMD3<Float>] {
		[
			SIMD3(1, 0, 0), SIMD3(-1, 0, 0),
			SIMD3(0, 1, 0), SIMD3(0, -1, 0),
			SIMD3(0, 0, 1), SIMD3(0, 0, -1)
		]
	}

	private func octahedronFaces() -> [[Int]] {
		[[0, 2, 4], [4, 2, 1], [1, 2, 5], [5, 2, 0], [4, 3, 0], [1, 3, 4], [5, 3, 1], [0, 3, 5]]
	}

	private func icosahedron() -> (vertices: [SIMD3<Float>], faces: [[Int]]) {
		let t = Float((1.0 + sqrt(5.0)) / 2.0)
		let verts: [SIMD3<Float>] = [
			SIMD3(-1, t, 0), SIMD3(1, t, 0), SIMD3(-1, -t, 0), SIMD3(1, -t, 0),
			SIMD3(0, -1, t), SIMD3(0, 1, t), SIMD3(0, -1, -t), SIMD3(0, 1, -t),
			SIMD3(t, 0, -1), SIMD3(t, 0, 1), SIMD3(-t, 0, -1), SIMD3(-t, 0, 1)
		]
		let faces = [
			[0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11],
			[1, 5, 9], [5, 11, 4], [11, 10, 2], [10, 7, 6], [7, 1, 8],
			[3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9],
			[4, 9, 5], [2, 4, 11], [6, 2, 10], [8, 6, 7], [9, 8, 1]
		]
		return (verts, faces)
	}

	private func dodecahedronFromIcosahedronDual() -> (vertices: [SIMD3<Float>], faces: [[Int]]) {
		let ico = icosahedron()
		let iv = ico.vertices
		let ifaces = ico.faces

		var centroids: [SIMD3<Float>] = []
		for f in ifaces {
			let c = (iv[f[0]] + iv[f[1]] + iv[f[2]]) / 3
			centroids.append(simd_normalize(c))
		}

		var faces: [[Int]] = []
		for vi in iv.indices {
			let v = simd_normalize(iv[vi])
			let axis = abs(v.y) < 0.9 ? SIMD3<Float>(0, 1, 0) : SIMD3<Float>(1, 0, 0)
			let u = simd_normalize(simd_cross(v, axis))
			let w = simd_normalize(simd_cross(v, u))

			var around: [(Int, Float)] = []
			for fi in ifaces.indices where ifaces[fi].contains(vi) {
				let c = simd_normalize(centroids[fi])
				around.append((fi, atan2(simd_dot(c, w), simd_dot(c, u))))
			}
			around.sort { $0.1 < $1.1 }
			faces.append(around.map { $0.0 })
		}

		return (centroids, faces)
	}

	private func pentagonalTrapezohedron() -> (vertices: [SIMD3<Float>], faces: [[Int]]) {
		let r: Float = 1.0
		let k: Float = 0.11
		let s36 = sin(Float.pi / 5)
		let s72 = sin(2 * Float.pi / 5)
		// Enforce coplanar kite faces for [top, u(i), l(i), u(i+1)] and [bottom, l(i), u(i+1), l(i+1)].
		let h: Float = k * (s72 + 2 * s36) / (2 * s36 - s72)

		var vertices: [SIMD3<Float>] = [SIMD3(0, h, 0), SIMD3(0, -h, 0)]
		for i in 0..<5 {
			let a = Float(i) * 2 * .pi / 5
			vertices.append(SIMD3(r * cos(a), k, r * sin(a)))
		}
		for i in 0..<5 {
			let a = (Float(i) + 0.5) * 2 * .pi / 5
			vertices.append(SIMD3(r * cos(a), -k, r * sin(a)))
		}

		var faces: [[Int]] = []
		for i in 0..<5 {
			let u0 = 2 + i
			let u1 = 2 + ((i + 1) % 5)
			let l0 = 7 + i
			let l1 = 7 + ((i + 1) % 5)
			// Connect each kite through adjacent upper/lower vertices to avoid twisted quads.
			faces.append([0, u0, l0, u1])
			faces.append([1, l0, u1, l1])
		}
		return (vertices, faces)
	}
}

private extension UIColor {
	var diceRelativeLuminance: CGFloat {
		var red: CGFloat = 0
		var green: CGFloat = 0
		var blue: CGFloat = 0
		var alpha: CGFloat = 0
		if getRed(&red, green: &green, blue: &blue, alpha: &alpha) {
			return (0.2126 * red) + (0.7152 * green) + (0.0722 * blue)
		}
		var white: CGFloat = 0
		if getWhite(&white, alpha: &alpha) {
			return white
		}
		return 0.0
	}
}
