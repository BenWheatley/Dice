import Foundation
import SceneKit
import simd

struct DiceSingleDieGeometryDescriptor {
	let geometry: SCNGeometry
	let faceValueCount: Int
	let isCoin: Bool
	let isToken: Bool
}

enum DiceSingleDieSceneGeometryFactory {
	static let minimumSideCount = 2
	static let maximumSideCount = 100
	static let supportedPolyhedralSideCounts: Set<Int> = [4, 6, 8, 10, 12, 20]

	private static let d4VertexValueByIndex: [Int] = [4, 3, 2, 1]
	private static var orientationCache: [Int: [Int: SCNVector3]] = [:]
	private static let orientationCacheLock = NSLock()

	static func clampedSideCount(_ sideCount: Int) -> Int {
		min(max(sideCount, minimumSideCount), maximumSideCount)
	}

	static func makeDescriptor(sideCount rawSideCount: Int, sideLength: CGFloat) -> DiceSingleDieGeometryDescriptor {
		let sideCount = clampedSideCount(rawSideCount)
		if usesCoinGeometry(for: sideCount) {
			let coin = SCNCylinder(radius: sideLength * 0.48, height: max(6, sideLength * 0.14))
			coin.radialSegmentCount = 72
			coin.materials = [SCNMaterial(), SCNMaterial(), SCNMaterial()]
			return DiceSingleDieGeometryDescriptor(geometry: coin, faceValueCount: 2, isCoin: true, isToken: false)
		}
		if usesTokenGeometry(for: sideCount) {
			let token = SCNCylinder(radius: sideLength * 0.48, height: max(10, sideLength * 0.30))
			token.radialSegmentCount = 60
			token.materials = [SCNMaterial(), SCNMaterial(), SCNMaterial()]
			return DiceSingleDieGeometryDescriptor(
				geometry: token,
				faceValueCount: sideCount,
				isCoin: false,
				isToken: true
			)
		}

		let mesh = meshData(for: sideCount)
		let maxNorm = mesh.vertices.map { simd_length($0) }.max() ?? 1
		let scale = Float(sideLength * 0.5) / maxNorm
		let scaledVertices = mesh.vertices.map { $0 * scale }

		if sideCount == 6 {
			let box = D6BeveledCubeGeometry.make(sideLength: sideLength)
			box.materials = (0..<mesh.faces.count).map { _ in SCNMaterial() }
			return DiceSingleDieGeometryDescriptor(
				geometry: box,
				faceValueCount: mesh.faces.count,
				isCoin: false,
				isToken: false
			)
		}

		let polyhedron = makePolyhedronGeometry(sideCount: sideCount, vertices: scaledVertices, faces: mesh.faces)
		return DiceSingleDieGeometryDescriptor(
			geometry: polyhedron,
			faceValueCount: mesh.faces.count,
			isCoin: false,
			isToken: false
		)
	}

	static func orientation(for value: Int, sideCount rawSideCount: Int) -> SCNVector3 {
		let sideCount = clampedSideCount(rawSideCount)
		if usesCoinGeometry(for: sideCount) {
			return coinTargetOrientation(for: value)
		}
		if usesTokenGeometry(for: sideCount) {
			return SCNVector3(Float.pi * 0.5, 0, 0)
		}
		if sideCount == 6 {
			let angles = D6FaceOrientation.eulerAngles(for: value)
			return SCNVector3(angles.x, angles.y, angles.z)
		}
		if sideCount == 4 {
			return d4Orientation(for: value)
		}

		if let cached = cachedOrientation(for: sideCount, value: value) {
			return cached
		}

		let mesh = meshData(for: sideCount)
		let orderedFaces = orientedFaces(sideCount: sideCount, vertices: mesh.vertices, faces: mesh.faces)
		let map = orientationMapForFaces(vertices: mesh.vertices, faces: orderedFaces)
		storeOrientationMap(map, for: sideCount)
		return map[value] ?? SCNVector3Zero
	}

	static func usesCoinGeometry(for sideCount: Int) -> Bool {
		sideCount == 2
	}

	static func usesTokenGeometry(for sideCount: Int) -> Bool {
		!usesCoinGeometry(for: sideCount) && !supportedPolyhedralSideCounts.contains(sideCount)
	}

	private static func cachedOrientation(for sideCount: Int, value: Int) -> SCNVector3? {
		orientationCacheLock.lock()
		let cached = orientationCache[sideCount]?[value]
		orientationCacheLock.unlock()
		return cached
	}

	private static func storeOrientationMap(_ map: [Int: SCNVector3], for sideCount: Int) {
		orientationCacheLock.lock()
		orientationCache[sideCount] = map
		orientationCacheLock.unlock()
	}

	private static func orientationMapForFaces(
		vertices: [SIMD3<Float>],
		faces: [[Int]]
	) -> [Int: SCNVector3] {
		var map: [Int: SCNVector3] = [:]
		let targetNormal = SIMD3<Float>(0, 0, 1)
		let worldUp = SIMD3<Float>(0, 1, 0)

		for (index, face) in faces.enumerated() {
			guard face.count >= 3 else { continue }
			let points = face.map { vertices[$0] }
			let normal = simd_normalize(simd_cross(points[1] - points[0], points[2] - points[0]))
			let up = simd_normalize(points[1] - points[0])

			let q1 = simd_quatf(from: normal, to: targetNormal)
			let up1 = simd_act(q1, up)
			let projected = simd_normalize(SIMD3<Float>(up1.x, up1.y, 0))
			let clampedDot = max(-1 as Float, min(1 as Float, simd_dot(projected, worldUp)))
			let crossZ = projected.x * worldUp.y - projected.y * worldUp.x
			let angle = atan2(crossZ, clampedDot)
			let q2 = simd_quatf(angle: angle, axis: targetNormal)
			let q = simd_normalize(q2 * q1)

			let node = SCNNode()
			node.simdOrientation = q
			map[index + 1] = node.eulerAngles
		}

		return map
	}

	private static func orientedFaces(sideCount: Int, vertices: [SIMD3<Float>], faces: [[Int]]) -> [[Int]] {
		faces.compactMap { face in
			guard face.count >= 3 else { return nil }
			var workingFace = face
			var points = workingFace.map { vertices[$0] }
			let center = points.reduce(SIMD3<Float>(repeating: 0), +) / Float(points.count)
			var normal = simd_normalize(simd_cross(points[1] - points[0], points[2] - points[0]))
			if simd_dot(normal, center) < 0 {
				workingFace = Array(workingFace.reversed())
				points = workingFace.map { vertices[$0] }
				normal = simd_normalize(simd_cross(points[1] - points[0], points[2] - points[0]))
			}
			if sideCount == 4 {
				workingFace = d4OrderedFaceVertices(for: workingFace, vertices: vertices)
				points = workingFace.map { vertices[$0] }
				normal = simd_normalize(simd_cross(points[1] - points[0], points[2] - points[0]))
				if simd_dot(normal, center) < 0 {
					workingFace.swapAt(1, 2)
				}
			}
			return workingFace
		}
	}

	private static func makePolyhedronGeometry(
		sideCount: Int,
		vertices: [SIMD3<Float>],
		faces: [[Int]]
	) -> SCNGeometry {
		let orderedFaces = orientedFaces(sideCount: sideCount, vertices: vertices, faces: faces)
		var finalVertices: [SCNVector3] = []
		var finalUVs: [CGPoint] = []
		var elements: [SCNGeometryElement] = []

		for face in orderedFaces {
			let points = face.map { vertices[$0] }
			let center = points.reduce(SIMD3<Float>(repeating: 0), +) / Float(points.count)
			let normal = simd_normalize(simd_cross(points[1] - points[0], points[2] - points[0]))
			let up = simd_normalize(points[1] - points[0])
			let v = simd_normalize(simd_cross(normal, up))

			var maxProj: Float = 0.001
			for point in points {
				let delta = point - center
				maxProj = max(maxProj, abs(simd_dot(delta, up)), abs(simd_dot(delta, v)))
			}

			var faceIndices: [Int32] = []
			for i in 1..<(points.count - 1) {
				let triangle = [points[0], points[i], points[i + 1]]
				let base = Int32(finalVertices.count)
				for point in triangle {
					let delta = point - center
					let px = simd_dot(delta, up) / maxProj
					let py = simd_dot(delta, v) / maxProj
					finalVertices.append(SCNVector3(point.x, point.y, point.z))
					finalUVs.append(CGPoint(
						x: 0.5 - CGFloat(py) * 0.45,
						y: 0.5 - CGFloat(px) * 0.45
					))
				}
				faceIndices += [base, base + 1, base + 2]
			}
			elements.append(SCNGeometryElement(indices: faceIndices, primitiveType: .triangles))
		}

		let vertexSource = SCNGeometrySource(vertices: finalVertices)
		let uvSource = SCNGeometrySource(textureCoordinates: finalUVs)
		let geometry = SCNGeometry(sources: [vertexSource, uvSource], elements: elements)
		geometry.materials = (0..<orderedFaces.count).map { _ in SCNMaterial() }
		return geometry
	}

	private static func coinTargetOrientation(for value: Int) -> SCNVector3 {
		let sign: Float = value.isMultiple(of: 2) ? -1 : 1
		return SCNVector3(sign * Float.pi * 0.5, 0, 0)
	}

	private static func d4Orientation(for value: Int) -> SCNVector3 {
		if let cached = cachedOrientation(for: 4, value: value) {
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
			let neighborDirection = simd_normalize(vertices[neighborIndex] - vertices[topIndex])
			let rotatedNeighbor = simd_act(q1, neighborDirection)
			let projectedNeighbor = simd_normalize(rotatedNeighbor - simd_dot(rotatedNeighbor, targetTop) * targetTop)

			let worldUp = SIMD3<Float>(0, 1, 0)
			let projectedUp = simd_normalize(worldUp - simd_dot(worldUp, targetTop) * targetTop)
			let crossVector = simd_cross(projectedNeighbor, projectedUp)
			let signed = simd_dot(crossVector, targetTop)
			let angle = atan2(signed, simd_dot(projectedNeighbor, projectedUp))
			let q2 = simd_quatf(angle: angle, axis: targetTop)

			let node = SCNNode()
			node.simdOrientation = simd_normalize(q2 * q1)
			map[topValue] = node.eulerAngles
		}

		storeOrientationMap(map, for: 4)
		return map[value] ?? SCNVector3Zero
	}

	private static func d4OrderedFaceVertices(for face: [Int], vertices: [SIMD3<Float>]) -> [Int] {
		guard face.count == 3 else { return face }
		let sortedByZ = face.sorted { vertices[$0].z > vertices[$1].z }
		guard let top = sortedByZ.first else { return face }
		let remaining = sortedByZ.dropFirst()
		guard remaining.count == 2 else { return face }
		let left: Int
		let right: Int
		if vertices[remaining[0]].x <= vertices[remaining[1]].x {
			left = remaining[0]
			right = remaining[1]
		} else {
			left = remaining[1]
			right = remaining[0]
		}
		return [top, left, right]
	}

	private static func meshData(for sideCount: Int) -> (vertices: [SIMD3<Float>], faces: [[Int]]) {
		switch sideCount {
		case 4:
			return (tetrahedronVertices(), tetrahedronFaces())
		case 6:
			return (cubeVertices(), cubeFaces())
		case 8:
			return (octahedronVertices(), octahedronFaces())
		case 10:
			return pentagonalTrapezohedron()
		case 12:
			return dodecahedronFromIcosahedronDual()
		case 20:
			return icosahedron()
		default:
			return (cubeVertices(), cubeFaces())
		}
	}

	private static func cubeVertices() -> [SIMD3<Float>] {
		[
			SIMD3(-1, -1, -1), SIMD3(1, -1, -1), SIMD3(1, 1, -1), SIMD3(-1, 1, -1),
			SIMD3(-1, -1, 1), SIMD3(1, -1, 1), SIMD3(1, 1, 1), SIMD3(-1, 1, 1)
		]
	}

	private static func cubeFaces() -> [[Int]] {
		[[4, 5, 6, 7], [5, 1, 2, 6], [1, 0, 3, 2], [0, 4, 7, 3], [7, 6, 2, 3], [0, 1, 5, 4]]
	}

	private static func tetrahedronVertices() -> [SIMD3<Float>] {
		[SIMD3(1, 1, 1), SIMD3(-1, -1, 1), SIMD3(-1, 1, -1), SIMD3(1, -1, -1)]
	}

	private static func tetrahedronFaces() -> [[Int]] {
		[[0, 1, 2], [0, 3, 1], [0, 2, 3], [1, 3, 2]]
	}

	private static func octahedronVertices() -> [SIMD3<Float>] {
		[
			SIMD3(1, 0, 0), SIMD3(-1, 0, 0),
			SIMD3(0, 1, 0), SIMD3(0, -1, 0),
			SIMD3(0, 0, 1), SIMD3(0, 0, -1)
		]
	}

	private static func octahedronFaces() -> [[Int]] {
		[[0, 2, 4], [4, 2, 1], [1, 2, 5], [5, 2, 0], [4, 3, 0], [1, 3, 4], [5, 3, 1], [0, 3, 5]]
	}

	private static func icosahedron() -> (vertices: [SIMD3<Float>], faces: [[Int]]) {
		let t = Float((1.0 + sqrt(5.0)) / 2.0)
		let vertices: [SIMD3<Float>] = [
			SIMD3(-1, t, 0), SIMD3(1, t, 0), SIMD3(-1, -t, 0), SIMD3(1, -t, 0),
			SIMD3(0, -1, t), SIMD3(0, 1, t), SIMD3(0, -1, -t), SIMD3(0, 1, -t),
			SIMD3(t, 0, -1), SIMD3(t, 0, 1), SIMD3(-t, 0, -1), SIMD3(-t, 0, 1),
		]
		let faces = [
			[0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11],
			[1, 5, 9], [5, 11, 4], [11, 10, 2], [10, 7, 6], [7, 1, 8],
			[3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9],
			[4, 9, 5], [2, 4, 11], [6, 2, 10], [8, 6, 7], [9, 8, 1],
		]
		return (vertices, faces)
	}

	private static func dodecahedronFromIcosahedronDual() -> (vertices: [SIMD3<Float>], faces: [[Int]]) {
		let ico = icosahedron()
		let icoVertices = ico.vertices
		let icoFaces = ico.faces

		var centroids: [SIMD3<Float>] = []
		for face in icoFaces {
			let centroid = (icoVertices[face[0]] + icoVertices[face[1]] + icoVertices[face[2]]) / 3
			centroids.append(simd_normalize(centroid))
		}

		var faces: [[Int]] = []
		for vertexIndex in icoVertices.indices {
			let vertex = simd_normalize(icoVertices[vertexIndex])
			let axis = abs(vertex.y) < 0.9 ? SIMD3<Float>(0, 1, 0) : SIMD3<Float>(1, 0, 0)
			let u = simd_normalize(simd_cross(vertex, axis))
			let w = simd_normalize(simd_cross(vertex, u))

			var around: [(Int, Float)] = []
			for faceIndex in icoFaces.indices where icoFaces[faceIndex].contains(vertexIndex) {
				let centroid = simd_normalize(centroids[faceIndex])
				around.append((faceIndex, atan2(simd_dot(centroid, w), simd_dot(centroid, u))))
			}
			around.sort { $0.1 < $1.1 }
			faces.append(around.map { $0.0 })
		}

		return (centroids, faces)
	}

	private static func pentagonalTrapezohedron() -> (vertices: [SIMD3<Float>], faces: [[Int]]) {
		let radius: Float = 1.0
		let k: Float = 0.11
		let s36 = sin(Float.pi / 5)
		let s72 = sin(2 * Float.pi / 5)
		let h: Float = k * (s72 + 2 * s36) / (2 * s36 - s72)

		var vertices: [SIMD3<Float>] = [SIMD3(0, h, 0), SIMD3(0, -h, 0)]
		for index in 0..<5 {
			let angle = Float(index) * 2 * .pi / 5
			vertices.append(SIMD3(radius * cos(angle), k, radius * sin(angle)))
		}
		for index in 0..<5 {
			let angle = (Float(index) + 0.5) * 2 * .pi / 5
			vertices.append(SIMD3(radius * cos(angle), -k, radius * sin(angle)))
		}

		var faces: [[Int]] = []
		for index in 0..<5 {
			let u0 = 2 + index
			let u1 = 2 + ((index + 1) % 5)
			let l0 = 7 + index
			let l1 = 7 + ((index + 1) % 5)
			faces.append([0, u0, l0, u1])
			faces.append([1, l0, u1, l1])
		}

		return (vertices, faces)
	}
}
