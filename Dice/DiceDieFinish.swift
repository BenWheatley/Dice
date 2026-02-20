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
#pragma body
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

float3 modelPos = _surface.position.xyz;
float3 p = modelPos * 5.8;
float n1 = simplexNoise3D(p * 1.0 + float3(1.7, 2.3, 3.1));
float n2 = simplexNoise3D(p * 2.1 + float3(7.3, 5.9, 11.2));
float n3 = simplexNoise3D(p * 3.7 + float3(13.4, 9.1, 4.6));
float swirl = (n1 * 0.65) + (n2 * 0.28) + (n3 * 0.07);
float veins = sin((p.x + p.y + p.z) * 1.4 + swirl * 6.2);
float veinMask = smoothstep(0.36, 0.95, 0.5 + 0.5 * veins);
float grain = (n1 * 0.52) + (n2 * 0.33) + (n3 * 0.15);
float fleck = smoothstep(0.88, 0.985, simplexNoise3D(p * 4.6 + 19.0));

float3 base = _surface.diffuse.rgb;
float luminance = dot(base, float3(0.2126, 0.7152, 0.0722));
float3 neutral = float3(luminance, luminance, luminance) * 0.97;
float3 marbleBase = mix(neutral * 0.70, neutral * 1.10, grain);
float3 veinColor = mix(float3(0.22, 0.22, 0.23), float3(0.39, 0.39, 0.41), grain);
float3 marble = mix(marbleBase, veinColor, veinMask * 0.58);
marble += fleck * 0.04;

_surface.diffuse.rgb = clamp(marble, 0.0, 1.0);
_surface.specular.rgb *= 0.72;
_surface.shininess = max(_surface.shininess, 0.18);
"""
}
