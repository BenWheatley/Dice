import SceneKit
import UIKit

enum DiceDieFinish: String, CaseIterable {
	case matte
	case gloss
	case stone

	var menuTitleKey: String {
		switch self {
		case .matte:
			return "finish.matte"
		case .gloss:
			return "finish.gloss"
		case .stone:
			return "finish.stone"
		}
	}

	func apply(to material: SCNMaterial) {
		material.shaderModifiers = nil
		switch self {
		case .matte:
			material.lightingModel = .lambert
			material.specular.contents = UIColor(white: 0.15, alpha: 1.0)
			material.shininess = 0.08
		case .gloss:
			material.lightingModel = .blinn
			material.specular.contents = UIColor(white: 0.95, alpha: 1.0)
			material.shininess = 0.90
		case .stone:
			material.lightingModel = .lambert
			material.specular.contents = UIColor(white: 0.25, alpha: 1.0)
			material.shininess = 0.20
			material.shaderModifiers = [.surface: DiceStoneSurfaceShader.surfaceModifier]
		}
	}
}

private enum DiceStoneSurfaceShader {
	// 3D procedural marble veins in model space to avoid per-face seams.
	static let surfaceModifier = """
float hash13(float3 p) {
	return fract(sin(dot(p, float3(127.1, 311.7, 74.7))) * 43758.5453123);
}

float simplexNoise3D(float3 p) {
	float3 i = floor(p);
	float3 f = fract(p);
	float3 u = f * f * (3.0 - 2.0 * f);

	float n000 = hash13(i + float3(0.0, 0.0, 0.0));
	float n100 = hash13(i + float3(1.0, 0.0, 0.0));
	float n010 = hash13(i + float3(0.0, 1.0, 0.0));
	float n110 = hash13(i + float3(1.0, 1.0, 0.0));
	float n001 = hash13(i + float3(0.0, 0.0, 1.0));
	float n101 = hash13(i + float3(1.0, 0.0, 1.0));
	float n011 = hash13(i + float3(0.0, 1.0, 1.0));
	float n111 = hash13(i + float3(1.0, 1.0, 1.0));

	float nx00 = mix(n000, n100, u.x);
	float nx10 = mix(n010, n110, u.x);
	float nx01 = mix(n001, n101, u.x);
	float nx11 = mix(n011, n111, u.x);
	float nxy0 = mix(nx00, nx10, u.y);
float nxy1 = mix(nx01, nx11, u.y);
return mix(nxy0, nxy1, u.z);
}

#pragma body
// Convert surface position (view space) back into this die's local model space.
float4 worldPos = scn_frame.inverseViewTransform * float4(_surface.position.xyz, 1.0);
float3 modelPos = (scn_node.inverseModelTransform * worldPos).xyz;
// Rotate marble sampling basis by 15 degrees to avoid alignment with die planes.
const float c = 0.9659258; // cos(15 deg)
const float s = 0.2588190; // sin(15 deg)
float3x3 veinBasis = float3x3(
	float3(c, -s, 0.0),
	float3(s,  c, 0.0),
	float3(0.0, 0.0, 1.0)
);
float3 nodeWorld = float3(
	scn_node.modelTransform[3][0],
	scn_node.modelTransform[3][1],
	scn_node.modelTransform[3][2]
);
float dieSeed = dot(nodeWorld, float3(0.73, 1.21, 1.93)) * 19.0;
float3 seedOffset = float3(dieSeed, dieSeed * 0.41, dieSeed * 0.73);
float3 p = (veinBasis * modelPos) * 0.34;
float n1 = simplexNoise3D(p * 0.28 + float3(1.7, 2.3, 3.1) + seedOffset);
float n2 = simplexNoise3D(p * 0.58 + float3(7.3, 5.9, 11.2) + seedOffset * 0.67);
float n3 = simplexNoise3D(p * 0.96 + float3(13.4, 9.1, 4.6) + seedOffset * 1.29);
float swirl = (n1 * 0.62) + (n2 * 0.28) + (n3 * 0.10);
float veins = sin((p.x + p.y + p.z) * 0.24 + swirl * 3.1);
float veinMask = smoothstep(0.50, 0.965, 0.5 + 0.5 * veins);
float grain = (n1 * 0.56) + (n2 * 0.31) + (n3 * 0.13);
float fleck = smoothstep(0.95, 0.994, simplexNoise3D(p * 1.45 + 19.0));

float3 base = _surface.diffuse.rgb;
float luminance = dot(base, float3(0.2126, 0.7152, 0.0722));
float mainShade = mix(0.74, 1.13, grain);
float3 mainColor = clamp(base * mainShade, 0.0, 1.0);
float3 lightContrast = mix(base, float3(1.0, 1.0, 1.0), 0.72);
float3 darkContrast = base * 0.34;
float3 contrastColor = luminance > 0.52 ? darkContrast : lightContrast;
float marblePattern = clamp(veinMask * 0.78 + fleck * 0.22, 0.0, 1.0);
float3 marble = mix(mainColor, contrastColor, marblePattern);

_surface.diffuse.rgb = clamp(marble, 0.0, 1.0);
_surface.specular.rgb *= 0.72;
_surface.shininess = max(_surface.shininess, 0.18);
"""
}
