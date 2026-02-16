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
	private struct MeshCacheKey: Hashable {
		let sideCount: Int
		let roundedSideLength: Int
	}

	private struct BadgeCacheKey: Hashable {
		let value: Int
		let roundedBadgeSize: Int
	}

	private struct MeshData {
		let vertices: [SIMD3<Float>]
		let faces: [[Int]]
	}

	private struct BuiltMesh {
		let geometry: SCNGeometry
		let faceNormals: [SIMD3<Float>]
		let faceUps: [SIMD3<Float>]
	}

	private let scnView = SCNView()
	private let scene = SCNScene()
	private let cameraNode = SCNNode()
	private var dieNodes: [SCNNode] = []
	private var currentSideLength: CGFloat = 0
	private var dieSideCounts: [Int] = []
	private var orientationCache: [Int: [Int: SCNVector3]] = [:]
	private var meshCache: [MeshCacheKey: BuiltMesh] = [:]
	private var badgeImageCache: [BadgeCacheKey: UIImage] = [:]
	private var labelValueCache: [ObjectIdentifier: Int] = [:]
	private var lifecycleObservers: [NSObjectProtocol] = []

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
		updateCamera()
	}

	func setDice(values: [Int], centers: [CGPoint], sideLength: CGFloat, sideCounts: [Int], animated: Bool) {
		guard values.count == centers.count, values.count == sideCounts.count else { return }
		ensureNodeCount(values.count)

		let sizeChanged = abs(currentSideLength - sideLength) > 0.5
		if sizeChanged {
			currentSideLength = sideLength
			for node in dieNodes {
				let label = node.childNode(withName: "label", recursively: false)
				label?.geometry = makeLabelGeometry(sideLength: sideLength)
				label?.position = SCNVector3(0, 0, Float(sideLength * 0.65))
			}
		}

		for index in values.indices {
			let container = dieNodes[index]
			let sideCount = sideCounts[index]
			let didSideChange = dieSideCounts[index] != sideCount
			if didSideChange || sizeChanged {
				let body = container.childNode(withName: "body", recursively: false)
				body?.geometry = builtMesh(sideLength: sideLength, sideCount: sideCount).geometry
				dieSideCounts[index] = sideCount
			}

			let showLabel = sideCount != 6
			let labelNode = container.childNode(withName: "label", recursively: false)
			labelNode?.isHidden = !showLabel
			if showLabel, let labelNode {
				let cacheKey = ObjectIdentifier(labelNode)
				let previousValue = labelValueCache[cacheKey]
				if sizeChanged || didSideChange || previousValue != values[index] {
					(labelNode.geometry as? SCNPlane)?.firstMaterial?.diffuse.contents = valueBadgeImage(values[index], sideLength: sideLength)
					labelValueCache[cacheKey] = values[index]
				}
			}

			let targetPosition = scenePosition(for: centers[index])
			let targetFace = values[index]
			let startPosition = SCNVector3(container.presentation.position.x, container.presentation.position.y, 0)

			if animated {
				animateRoll(node: container, from: startPosition, to: targetPosition, faceValue: targetFace, sideLength: sideLength, sideCount: sideCount)
			} else {
				container.removeAllActions()
				container.position = targetPosition
				container.eulerAngles = orientation(for: targetFace, sideCount: sideCount)
			}
		}
	}

	private func configureScene() {
		backgroundColor = .clear
		isUserInteractionEnabled = false

		scnView.translatesAutoresizingMaskIntoConstraints = false
		scnView.backgroundColor = .clear
		scnView.isUserInteractionEnabled = false
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

		cameraNode.camera = SCNCamera()
		cameraNode.camera?.usesOrthographicProjection = true
		cameraNode.camera?.zNear = 1
		cameraNode.camera?.zFar = 10_000
		cameraNode.position = SCNVector3(0, 0, 800)
		scene.rootNode.addChildNode(cameraNode)

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
		lifecycleObservers = [resignObserver, becomeObserver]
	}

	private func updateCamera() {
		cameraNode.camera?.orthographicScale = Double(bounds.height / 2)
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
		}

		while dieNodes.count < count {
			let container = SCNNode()
			container.name = "die"

			let body = SCNNode()
			body.name = "body"
			body.geometry = builtMesh(sideLength: max(currentSideLength, 60), sideCount: 6).geometry
			container.addChildNode(body)

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
		}
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
	static func debugMeshData(sideCount: Int) -> (vertices: [SIMD3<Float>], faces: [[Int]]) {
		let view = DiceCubeView(frame: .zero)
		let mesh = view.meshData(for: sideCount)
		return (mesh.vertices, mesh.faces)
	}

	static func debugD4FaceVertexLabels() -> [[Int]] {
		let view = DiceCubeView(frame: .zero)
		return view.tetrahedronFaces().map { view.d4VertexLabels(forFace: $0) }
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
		return bestIndex + 1
	}

	static func debugD4LabelLayout(size: CGSize) -> (triangle: [CGPoint], placements: [(position: CGPoint, angle: CGFloat)]) {
		let view = DiceCubeView(frame: .zero)
		let triangle = view.d4TrianglePoints(size: size)
		let placements = view.d4LabelPlacements(triangle: triangle)
		return (triangle: triangle, placements: placements)
	}
#endif

	private func buildGeometry(sideLength: CGFloat, sideCount: Int) -> BuiltMesh {
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
		}

		let vSource = SCNGeometrySource(vertices: finalVertices)
		let uvSource = SCNGeometrySource(textureCoordinates: finalUVs)
		let geometry = SCNGeometry(sources: [vSource, uvSource], elements: elements)
		geometry.materials = materials
		return BuiltMesh(geometry: geometry, faceNormals: faceNormals, faceUps: faceUps)
	}

	private func builtMesh(sideLength: CGFloat, sideCount: Int) -> BuiltMesh {
		let roundedSideLength = Int(sideLength.rounded())
		let key = MeshCacheKey(sideCount: sideCount, roundedSideLength: roundedSideLength)
		if let cached = meshCache[key] {
			return cached
		}
		let mesh = buildGeometry(sideLength: CGFloat(roundedSideLength), sideCount: sideCount)
		meshCache[key] = mesh
		return mesh
	}

	private func faceMaterial(faceIndex: Int, face: [Int], sideCount: Int) -> SCNMaterial {
		let material = SCNMaterial()
		let value = faceIndex + 1
		if sideCount == 6 {
			material.diffuse.contents = zoomedTexture(named: "\(value)", factor: 1.25)
		} else if sideCount == 4 {
			material.diffuse.contents = d4FaceTexture(vertexLabels: d4VertexLabels(forFace: face))
		} else {
			material.diffuse.contents = faceValueTexture(value: value, sideCount: sideCount)
		}
		material.locksAmbientWithDiffuse = true
		material.isDoubleSided = false
		return material
	}

	private func d4VertexLabels(forFace face: [Int]) -> [Int] {
		face.map { $0 + 1 }
	}

	private func d4FaceTexture(vertexLabels: [Int]) -> UIImage {
		let size = CGSize(width: 256, height: 256)
		let renderer = UIGraphicsImageRenderer(size: size)
		return renderer.image { ctx in
			let rect = CGRect(origin: .zero, size: size)
			ctx.cgContext.setFillColor(UIColor(white: 0.96, alpha: 1.0).cgColor)
			ctx.cgContext.fill(rect)

			let trianglePoints = d4TrianglePoints(size: size)
			let triangle = UIBezierPath()
			triangle.move(to: trianglePoints[0])
			triangle.addLine(to: trianglePoints[1])
			triangle.addLine(to: trianglePoints[2])
			triangle.close()
			UIColor(white: 0.88, alpha: 1.0).setFill()
			triangle.fill()
			UIColor(white: 0.70, alpha: 1.0).setStroke()
			triangle.lineWidth = 6
			triangle.stroke()

			let placements = d4LabelPlacements(triangle: trianglePoints)
			let attrs: [NSAttributedString.Key: Any] = [
				.font: UIFont.boldSystemFont(ofSize: 54),
				.foregroundColor: UIColor.black
			]
			for (index, placement) in placements.enumerated() where index < vertexLabels.count {
				let text = "\(vertexLabels[index])" as NSString
				let textSize = text.size(withAttributes: attrs)
				let textRect = CGRect(
					x: -textSize.width / 2,
					y: -textSize.height / 2,
					width: textSize.width,
					height: textSize.height
				)
				ctx.cgContext.saveGState()
				ctx.cgContext.translateBy(x: placement.position.x, y: placement.position.y)
				ctx.cgContext.rotate(by: placement.angle)
				text.draw(in: textRect, withAttributes: attrs)
				ctx.cgContext.restoreGState()
			}
		}
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

	private func faceValueTexture(value: Int, sideCount: Int) -> UIImage {
		let size = CGSize(width: 256, height: 256)
		let renderer = UIGraphicsImageRenderer(size: size)
		return renderer.image { ctx in
			let rect = CGRect(origin: .zero, size: size)
			ctx.cgContext.setFillColor(UIColor(white: 0.96, alpha: 1).cgColor)
			ctx.cgContext.fill(rect)
			ctx.cgContext.setStrokeColor(UIColor(white: 0.70, alpha: 1).cgColor)
			ctx.cgContext.setLineWidth(8)
			ctx.cgContext.stroke(rect.insetBy(dx: 6, dy: 6))

			let text = "\(value)" as NSString
			let attrs: [NSAttributedString.Key: Any] = [
				.font: UIFont.boldSystemFont(ofSize: 73),
				.foregroundColor: UIColor.black
			]
			let tSize = text.size(withAttributes: attrs)
			let tRect = CGRect(x: (size.width - tSize.width) / 2, y: (size.height - tSize.height) / 2 - 4, width: tSize.width, height: tSize.height)
			text.draw(in: tRect, withAttributes: attrs)

			let subtitle = "d\(sideCount)" as NSString
			let subAttrs: [NSAttributedString.Key: Any] = [
				.font: UIFont.systemFont(ofSize: 15, weight: .medium),
				.foregroundColor: UIColor.darkGray
			]
			let sSize = subtitle.size(withAttributes: subAttrs)
			let sRect = CGRect(x: (size.width - sSize.width) / 2, y: size.height * 0.78, width: sSize.width, height: sSize.height)
			subtitle.draw(in: sRect, withAttributes: subAttrs)
		}
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

	private func valueBadgeImage(_ value: Int, sideLength: CGFloat) -> UIImage {
		let badgeSize = Int((sideLength * 0.45).rounded())
		let key = BadgeCacheKey(value: value, roundedBadgeSize: badgeSize)
		if let cached = badgeImageCache[key] {
			return cached
		}

		let size = CGSize(width: badgeSize, height: badgeSize)
		let renderer = UIGraphicsImageRenderer(size: size)
		let image = renderer.image { ctx in
			let rect = CGRect(origin: .zero, size: size)
			ctx.cgContext.setFillColor(UIColor(white: 1.0, alpha: 0.92).cgColor)
			ctx.cgContext.fillEllipse(in: rect)

			let text = "\(value)" as NSString
			let attrs: [NSAttributedString.Key: Any] = [
				.font: UIFont.boldSystemFont(ofSize: size.height * 0.56),
				.foregroundColor: UIColor.black
			]
			let textSize = text.size(withAttributes: attrs)
			let textRect = CGRect(x: (size.width - textSize.width) / 2, y: (size.height - textSize.height) / 2, width: textSize.width, height: textSize.height)
			text.draw(in: textRect, withAttributes: attrs)
		}
		badgeImageCache[key] = image
		return image
	}

	private func scenePosition(for center: CGPoint) -> SCNVector3 {
		SCNVector3(center.x - bounds.midX, bounds.midY - center.y, 0)
	}

	private func animateRoll(node: SCNNode, from start: SCNVector3, to target: SCNVector3, faceValue: Int, sideLength: CGFloat, sideCount: Int) {
		node.removeAllActions()
		let duration: TimeInterval = 1.6
		let moveAction = makeBounceMoveAction(start: start, target: target, sideLength: sideLength, duration: duration)
		let rotateAction = makeRotateAction(node: node, targetFace: faceValue, sideCount: sideCount, duration: duration)
		node.runAction(.group([moveAction, rotateAction]))
	}

	private func makeRotateAction(node: SCNNode, targetFace: Int, sideCount: Int, duration: TimeInterval) -> SCNAction {
		let target = orientation(for: targetFace, sideCount: sideCount)
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
			target.x + randomTurns(min: 2, max: 4) * Float.pi * 2,
			target.y + randomTurns(min: 2, max: 4) * Float.pi * 2,
			target.z + randomTurns(min: 1, max: 3) * Float.pi * 2
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

	private func zoomedTexture(named name: String, factor: CGFloat) -> UIImage? {
		guard let source = UIImage(named: name) else { return nil }
		let size = source.size
		let renderer = UIGraphicsImageRenderer(size: size)
		return renderer.image { _ in
			let w = size.width * factor
			let h = size.height * factor
			let rect = CGRect(x: (size.width - w) / 2, y: (size.height - h) / 2, width: w, height: h)
			source.draw(in: rect)
		}
	}

	private func makeBounceMoveAction(start: SCNVector3, target: SCNVector3, sideLength: CGFloat, duration: TimeInterval) -> SCNAction {
		let halfW = Float(bounds.width / 2)
		let halfH = Float(bounds.height / 2)
		let margin = Float(sideLength / 2 + 6)
		let minX = -halfW + margin
		let maxX = halfW - margin
		let minY = -halfH + margin
		let maxY = halfH - margin

		var lastTime: TimeInterval = 0
		var pos = start
		var vel = SCNVector3(Float.random(in: -420...420), Float.random(in: -330...330), 0)
		let liftAmplitude = Float(sideLength * 1.35)
		let oscillationAmplitude = Float(sideLength * 0.28)
		let oscillationFrequency: Float = 9.0

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

	private func d4Orientation(for value: Int) -> SCNVector3 {
		if let cached = orientationCache[4]?[value] {
			return cached
		}

		let vertices = tetrahedronVertices()
		let targetTop = SIMD3<Float>(0, 0, 1)
		var map: [Int: SCNVector3] = [:]

		for topValue in 1...4 {
			let topIndex = topValue - 1
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
