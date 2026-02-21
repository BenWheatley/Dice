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
float4x4 inverse4x4(float4x4 m) {
	float a00 = m[0][0], a01 = m[0][1], a02 = m[0][2], a03 = m[0][3];
	float a10 = m[1][0], a11 = m[1][1], a12 = m[1][2], a13 = m[1][3];
	float a20 = m[2][0], a21 = m[2][1], a22 = m[2][2], a23 = m[2][3];
	float a30 = m[3][0], a31 = m[3][1], a32 = m[3][2], a33 = m[3][3];

	float b00 = a00 * a11 - a01 * a10;
	float b01 = a00 * a12 - a02 * a10;
	float b02 = a00 * a13 - a03 * a10;
	float b03 = a01 * a12 - a02 * a11;
	float b04 = a01 * a13 - a03 * a11;
	float b05 = a02 * a13 - a03 * a12;
	float b06 = a20 * a31 - a21 * a30;
	float b07 = a20 * a32 - a22 * a30;
	float b08 = a20 * a33 - a23 * a30;
	float b09 = a21 * a32 - a22 * a31;
	float b10 = a21 * a33 - a23 * a31;
	float b11 = a22 * a33 - a23 * a32;

	float det = b00 * b11 - b01 * b10 + b02 * b09 + b03 * b08 - b04 * b07 + b05 * b06;
	float invDet = 1.0 / det;

	float4x4 inv;
	inv[0][0] = ( a11 * b11 - a12 * b10 + a13 * b09) * invDet;
	inv[0][1] = (-a01 * b11 + a02 * b10 - a03 * b09) * invDet;
	inv[0][2] = ( a31 * b05 - a32 * b04 + a33 * b03) * invDet;
	inv[0][3] = (-a21 * b05 + a22 * b04 - a23 * b03) * invDet;
	inv[1][0] = (-a10 * b11 + a12 * b08 - a13 * b07) * invDet;
	inv[1][1] = ( a00 * b11 - a02 * b08 + a03 * b07) * invDet;
	inv[1][2] = (-a30 * b05 + a32 * b02 - a33 * b01) * invDet;
	inv[1][3] = ( a20 * b05 - a22 * b02 + a23 * b01) * invDet;
	inv[2][0] = ( a10 * b10 - a11 * b08 + a13 * b06) * invDet;
	inv[2][1] = (-a00 * b10 + a01 * b08 - a03 * b06) * invDet;
	inv[2][2] = ( a30 * b04 - a31 * b02 + a33 * b00) * invDet;
	inv[2][3] = (-a20 * b04 + a21 * b02 - a23 * b00) * invDet;
	inv[3][0] = (-a10 * b09 + a11 * b07 - a12 * b06) * invDet;
	inv[3][1] = ( a00 * b09 - a01 * b07 + a02 * b06) * invDet;
	inv[3][2] = (-a30 * b03 + a31 * b01 - a32 * b00) * invDet;
	inv[3][3] = ( a20 * b03 - a21 * b01 + a22 * b00) * invDet;
	return inv;
}

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
float4x4 invModelTransform = inverse4x4(scn_node.modelTransform);
float3 modelPos = (invModelTransform * float4(_surface.position.xyz, 1.0)).xyz;
float3 p = modelPos * 0.34;
float n1 = simplexNoise3D(p * 0.28 + float3(1.7, 2.3, 3.1));
float n2 = simplexNoise3D(p * 0.58 + float3(7.3, 5.9, 11.2));
float n3 = simplexNoise3D(p * 0.96 + float3(13.4, 9.1, 4.6));
float swirl = (n1 * 0.62) + (n2 * 0.28) + (n3 * 0.10);
float veins = sin((p.x + p.y + p.z) * 0.24 + swirl * 3.1);
float veinMask = smoothstep(0.50, 0.965, 0.5 + 0.5 * veins);
float grain = (n1 * 0.56) + (n2 * 0.31) + (n3 * 0.13);
float fleck = smoothstep(0.95, 0.994, simplexNoise3D(p * 1.45 + 19.0));

float3 base = _surface.diffuse.rgb;
float luminance = dot(base, float3(0.2126, 0.7152, 0.0722));
float3 neutral = float3(luminance, luminance, luminance) * 0.97;
float3 marbleBase = mix(neutral * 0.70, neutral * 1.10, grain);
float3 veinColor = mix(float3(0.20, 0.20, 0.21), float3(0.36, 0.36, 0.38), grain);
float3 marble = mix(marbleBase, veinColor, veinMask * 0.68);
marble += fleck * 0.015;

_surface.diffuse.rgb = clamp(marble, 0.0, 1.0);
_surface.specular.rgb *= 0.72;
_surface.shininess = max(_surface.shininess, 0.18);
"""
}
