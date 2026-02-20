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
float hash31(float3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}

float valueNoise3(float3 p) {
	float3 i = floor(p);
	float3 f = fract(p);
	float3 u = f * f * (3.0 - 2.0 * f);

	float n000 = hash31(i + float3(0.0, 0.0, 0.0));
	float n100 = hash31(i + float3(1.0, 0.0, 0.0));
	float n010 = hash31(i + float3(0.0, 1.0, 0.0));
	float n110 = hash31(i + float3(1.0, 1.0, 0.0));
	float n001 = hash31(i + float3(0.0, 0.0, 1.0));
	float n101 = hash31(i + float3(1.0, 0.0, 1.0));
	float n011 = hash31(i + float3(0.0, 1.0, 1.0));
	float n111 = hash31(i + float3(1.0, 1.0, 1.0));

	float nx00 = mix(n000, n100, u.x);
	float nx10 = mix(n010, n110, u.x);
	float nx01 = mix(n001, n101, u.x);
	float nx11 = mix(n011, n111, u.x);
	float nxy0 = mix(nx00, nx10, u.y);
	float nxy1 = mix(nx01, nx11, u.y);
	return mix(nxy0, nxy1, u.z);
}

float fbm3(float3 p) {
	float total = 0.0;
	float amplitude = 0.5;
	float frequency = 1.0;
	for (int octave = 0; octave < 5; octave++) {
		total += amplitude * valueNoise3(p * frequency);
		frequency *= 2.03;
		amplitude *= 0.5;
	}
	return total;
}

float3 modelPos = _surface.position.xyz;
float3 p = modelPos * 6.4;
float swirl = fbm3(p + float3(0.0, 3.2, 0.0)) * 4.8;
float veins = sin((p.x + p.y + p.z) + swirl);
float veinMask = smoothstep(0.28, 0.94, 0.5 + 0.5 * veins);
float grain = fbm3(p * 2.0 + 17.0);
float fleck = smoothstep(0.86, 0.98, valueNoise3(p * 3.7 + 11.0));

float3 base = _surface.diffuse.rgb;
float luminance = dot(base, float3(0.2126, 0.7152, 0.0722));
float3 neutral = float3(luminance, luminance, luminance);
float3 marbleBase = mix(neutral * 0.74, neutral * 1.14, grain);
float3 veinColor = mix(float3(0.24, 0.24, 0.26), float3(0.42, 0.42, 0.44), grain);
float3 marble = mix(marbleBase, veinColor, veinMask * 0.62);
marble += fleck * 0.05;

_surface.diffuse.rgb = clamp(marble, 0.0, 1.0);
_surface.specular.rgb *= 0.72;
_surface.shininess = max(_surface.shininess, 0.18);
"""
}
