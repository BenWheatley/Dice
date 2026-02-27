float3 mod289(float3 x) {
	return x - floor(x * (1.0 / 289.0)) * 289.0;
}

float4 mod289(float4 x) {
	return x - floor(x * (1.0 / 289.0)) * 289.0;
}

float4 permute(float4 x) {
	return mod289(((x * 34.0) + 1.0) * x);
}

float4 taylorInvSqrt(float4 r) {
	return 1.79284291400159 - 0.85373472095314 * r;
}

// 3D simplex noise (Gustavson-style).
// Keep this as-is unless you are replacing the noise algorithm entirely.
// Practical tuning happens lower down where this noise is sampled/mixed.
float simplexNoise3D(float3 v) {
	const float2 C = float2(1.0 / 6.0, 1.0 / 3.0);
	const float4 D = float4(0.0, 0.5, 1.0, 2.0);

	float3 i = floor(v + dot(v, C.yyy));
	float3 x0 = v - i + dot(i, C.xxx);

	float3 g = step(x0.yzx, x0.xyz);
	float3 l = 1.0 - g;
	float3 i1 = min(g.xyz, l.zxy);
	float3 i2 = max(g.xyz, l.zxy);

	float3 x1 = x0 - i1 + C.xxx;
	float3 x2 = x0 - i2 + C.yyy;
	float3 x3 = x0 - D.yyy;

	i = mod289(i);
	float4 p = permute(
		permute(
			permute(i.z + float4(0.0, i1.z, i2.z, 1.0))
			+ i.y + float4(0.0, i1.y, i2.y, 1.0)
		)
		+ i.x + float4(0.0, i1.x, i2.x, 1.0)
	);

	float4 j = p - 49.0 * floor(p * (1.0 / 49.0));
	float4 x_ = floor(j * (1.0 / 7.0));
	float4 y_ = floor(j - 7.0 * x_);

	float4 x = (x_ * 2.0 + 0.5) / 7.0 - 1.0;
	float4 y = (y_ * 2.0 + 0.5) / 7.0 - 1.0;
	float4 h = 1.0 - abs(x) - abs(y);

	float4 b0 = float4(x.xy, y.xy);
	float4 b1 = float4(x.zw, y.zw);

	float4 s0 = floor(b0) * 2.0 + 1.0;
	float4 s1 = floor(b1) * 2.0 + 1.0;
	float4 sh = -step(h, float4(0.0));

	float4 a0 = b0.xzyw + s0.xzyw * sh.xxyy;
	float4 a1 = b1.xzyw + s1.xzyw * sh.zzww;

	float3 g0 = float3(a0.xy, h.x);
	float3 g1 = float3(a0.zw, h.y);
	float3 g2 = float3(a1.xy, h.z);
	float3 g3 = float3(a1.zw, h.w);

	float4 norm = taylorInvSqrt(float4(dot(g0, g0), dot(g1, g1), dot(g2, g2), dot(g3, g3)));
	g0 *= norm.x;
	g1 *= norm.y;
	g2 *= norm.z;
	g3 *= norm.w;

	float4 m = max(0.6 - float4(dot(x0, x0), dot(x1, x1), dot(x2, x2), dot(x3, x3)), 0.0);
	m = m * m;
	return 42.0 * dot(m * m, float4(dot(g0, x0), dot(g1, x1), dot(g2, x2), dot(g3, x3)));
}

float fbm3(float3 p) {
	// Fractal Brownian Motion stack.
	// More octaves => finer detail + cost.
	// Fewer octaves => smoother, cheaper pattern.
	float value = 0.0;
	float amplitude = 0.5;
	float frequency = 1.0;
	for (int octave = 0; octave < 5; octave++) {
		value += amplitude * simplexNoise3D(p * frequency);
		frequency *= 2.03;
		amplitude *= 0.5;
	}
	return value;
}

#pragma body
float fillMask = _surface.roughness;
float outlineMask = _surface.metalness;
float symbolMaskFromRoughness = smoothstep(0.18, 0.92, fillMask);
float symbolMaskFromMetalness = smoothstep(0.10, 0.82, outlineMask);
float symbolMask = clamp(max(symbolMaskFromRoughness, symbolMaskFromMetalness), 0.0, 1.0);

float dx = dfdx(fillMask);
float dy = dfdy(fillMask);
_surface.normal = normalize(_surface.normal + float3(-dx * 0.95, -dy * 0.95, 0.0));

float baseRoughness = mix(0.86, 0.46, symbolMaskFromRoughness);
_surface.roughness = mix(baseRoughness, 0.14, symbolMaskFromMetalness);
_surface.metalness = symbolMaskFromMetalness;

// Convert current fragment from view-space into die-local model-space.
float4 worldPos = scn_frame.inverseViewTransform * float4(_surface.position.xyz, 1.0);
float3 modelPos = (scn_node.inverseModelTransform * worldPos).xyz;

// Rotate sampling basis 15 degrees to avoid alignment to any primary face plane.
// If veins appear too "face-aligned", increase angle slightly (e.g. 20-30 deg).
// If orientation feels arbitrary/noisy, lower angle.
const float angle = 0.2617994; // 15 deg
const float c = 0.9659258;
const float s = 0.2588190;
float3x3 basis = float3x3(
	float3(c, -s, 0.0),
	float3(s,  c, 0.0),
	float3(0.0, 0.0, 1.0)
);

float dieSeed = ((_surface.shininess - 0.20) * 10000.0) * 4096.0;
float3 seedOffset = float3(dieSeed, dieSeed * 0.41, dieSeed * 0.73);
// Sample in die-local space at a die-relative frequency so the pattern reads per die,
// not as a flat world-space gradient.
// MASTER SCALE CONTROL:
// - Increase 2.8 => smaller/finer veins.
// - Decrease 2.8 => larger/broader veins.
float3 p = (basis * modelPos) * 2.8 + seedOffset;

// Domain warp stage A:
// Lower multipliers here for smoother/larger marble flow.
// Raise for more turbulent swirls.
float3 warpA = float3(
	fbm3(p * 0.36 + float3(11.0, 5.0, 3.0)),
	fbm3(p * 0.36 + float3(7.0, 19.0, 13.0)),
	fbm3(p * 0.36 + float3(17.0, 2.0, 23.0))
);
float3 q = p + warpA * 1.75;
// Domain warp stage B:
// Acts like a second distortion pass.
// Reducing 1.10/0.72 gives calmer marble; increasing adds complexity.
float3 warpB = float3(
	fbm3(q * 0.72 + float3(2.0, 13.0, 5.0)),
	fbm3(q * 0.72 + float3(29.0, 3.0, 11.0)),
	fbm3(q * 0.72 + float3(5.0, 7.0, 31.0))
);
float3 r = q + warpB * 1.10;

float swirl = fbm3(r * 1.22);
float swirlSecondary = fbm3(r * 2.05 + float3(5.0, 13.0, 2.0));
float veins = clamp((swirl * 0.64) + (swirlSecondary * 0.36), -1.0, 1.0);
float veins01 = 0.5 + 0.5 * veins;
float ridge = 1.0 - abs(2.0 * veins01 - 1.0);
// Swirl mask: broad "cloud" style marble.
// Raise 1.22 exponent => narrower structures; lower => softer transitions.
float swirlMask = smoothstep(0.30, 0.88, pow(ridge, 1.22));
// Band mask: directional veining layered over swirl.
// Increase 3.6 for denser bands, decrease for wider bands.
// If banding dominates too much, reduce its final weight in marblePattern.
float bandField = sin((r.x * 1.4 + r.y * 0.9 + r.z * 1.1) * 3.6 + swirl * 2.7);
float bandMask = smoothstep(0.38, 0.82, 0.5 + 0.5 * bandField);
// Fleck mask: high-frequency inclusions.
// Reduce 4.1 or lower contribution to make a cleaner polished stone.
float fleck = smoothstep(0.74, 0.95, fbm3(r * 4.1 + 17.0) * 0.5 + 0.5);

float3 originalDiffuse = _surface.diffuse.rgb;
float3 base = originalDiffuse;
float luminance = dot(base, float3(0.2126, 0.7152, 0.0722));

// Keep mainColor close to base so selected die color remains visible.
// First scalar controls average dark/light shift around base hue.
float3 mainColor = clamp(base * (0.96 + 0.16 * (veins01 - 0.5)), 0.0, 1.0);
// Contrast color selection:
// Light dice get darker veins; dark dice get lighter veins.
// Change 0.64 / 0.30 to control contrast strength.
float3 lightContrast = mix(base, float3(1.0, 1.0, 1.0), 0.64);
float3 darkContrast = base * 0.30;
float3 contrastColor = luminance > 0.52 ? darkContrast : lightContrast;

// Final pattern mixer:
// - swirlMask weight controls cloudy marble body.
// - bandMask weight controls obvious veins.
// - fleck weight controls speckle noise.
// Ensure weights sum to ~1 for predictable behavior.
float marblePattern = clamp(swirlMask * 0.58 + bandMask * 0.30 + fleck * 0.12, 0.0, 1.0);
float3 marble = mix(mainColor, contrastColor, marblePattern);

// Preserve symbols (numerals/pips/outlines): symbolMask==1 means keep original face artwork.
_surface.diffuse.rgb = mix(clamp(marble, 0.0, 1.0), originalDiffuse, symbolMask);
_surface.specular.rgb *= 0.72;
_surface.shininess = max(_surface.shininess, 0.18);
