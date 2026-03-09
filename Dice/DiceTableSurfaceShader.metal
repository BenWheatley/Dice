#pragma arguments
float tableTextureMode;
float tableTextureScale;
float tableTextureScaleX;
float tableTextureScaleY;

#pragma declaration
float tableHash21(float2 p) {
	p = fract(p * float2(123.34, 456.21));
	p += dot(p, p + 78.233);
	return fract(p.x * p.y);
}

float tableNoise2(float2 p) {
	float2 i = floor(p);
	float2 f = fract(p);
	float a = tableHash21(i);
	float b = tableHash21(i + float2(1.0, 0.0));
	float c = tableHash21(i + float2(0.0, 1.0));
	float d = tableHash21(i + float2(1.0, 1.0));
	float2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float tableFbm2(float2 p) {
	float value = 0.0;
	float amplitude = 0.5;
	float frequency = 1.0;
	float amplitudeSum = 0.0;
	for (int octave = 0; octave < 5; ++octave) {
		value += tableNoise2(p * frequency) * amplitude;
		amplitudeSum += amplitude;
		frequency *= 2.03;
		amplitude *= 0.5;
	}
	return amplitudeSum > 0.0 ? (value / amplitudeSum) : 0.0;
}

#pragma body
float3 color;
if (tableTextureMode < 0.5) {
	// Felt uses screen-space coordinates for isotropic pixel-scale grain.
	// In this scene's orthographic camera, view-space XY maps 1:1 to screen points.
	float2 feltBase = _surface.position.xy * 0.24;
	float2 warp = float2(
		tableFbm2(feltBase * 0.63 + float2(31.2, 11.7)) - 0.5,
		tableFbm2(feltBase * 0.67 + float2(7.4, 47.3)) - 0.5
	);
	float2 feltWarped = feltBase + warp * 0.85;

	// Blend broad mottling, nap, and high-frequency fibers.
	float macro = tableFbm2(feltWarped * 0.17 + float2(3.0, 9.0));
	float meso = tableFbm2(feltWarped * 0.58 + float2(17.0, 5.0));
	float fiberA = tableNoise2(feltWarped * 1.95 + float2(13.0, 21.0));
	float fiberB = tableNoise2(feltWarped.yx * 2.10 + float2(4.0, 9.0));
	float fibers = (fiberA + fiberB) * 0.5;
	float lint = smoothstep(0.83, 0.98, tableNoise2(feltWarped * 3.4 + float2(29.0, 2.0)));

	float tonal = (macro - 0.5) * 0.15 + (meso - 0.5) * 0.13 + (fibers - 0.5) * 0.12;
	float3 base = float3(0.13, 0.43, 0.31);
	color = base
		+ float3(0.40, 0.64, 0.49) * tonal
		+ float3(0.05, 0.09, 0.07) * lint;
	_surface.roughness = 0.98;
} else if (tableTextureMode < 1.5) {
	// Wood uses view-space position as stable coordinates so rotation does not remap UVs.
	// Pattern model: rings + ring/axial noise + explicit knots (same controls used in DCC tools).
	float2 woodPos = _surface.position.xy * 0.11;
	float2 lowWarp = float2(
		tableFbm2(woodPos * 0.19 + float2(17.3, 8.4)) - 0.5,
		tableFbm2(woodPos * 0.23 + float2(3.1, 29.7)) - 0.5
	);
	float2 woodWarped = woodPos + lowWarp * float2(2.0, 0.7);

	float axial = woodWarped.y;
	float across = woodWarped.x;
	float ringNoise = (tableFbm2(float2(axial * 0.42, across * 0.11) + float2(11.0, 5.0)) - 0.5) * 2.1;
	float axialNoise = (tableFbm2(float2(axial * 0.18, across * 0.35) + float2(29.0, 17.0)) - 0.5) * 1.7;

	float knotField = 0.0;
	float knotWarp = 0.0;
	float knotSpacing = 26.0;
	float2 knotCell = floor(woodWarped / knotSpacing);
	for (int oy = -1; oy <= 1; ++oy) {
		for (int ox = -1; ox <= 1; ++ox) {
			float2 cell = knotCell + float2(float(ox), float(oy));
			float2 jitter = float2(
				tableHash21(cell + float2(19.1, 7.7)),
				tableHash21(cell + float2(3.5, 41.3))
			) - 0.5;
			float2 center = (cell + 0.5 + jitter * 0.75) * knotSpacing;
			float2 d = woodWarped - center;
			d.x *= 0.55;
			float dist2 = dot(d, d);
			float knot = exp(-dist2 * 0.085);
			knotField = max(knotField, knot);
			float angle = atan2(d.y, d.x);
			knotWarp += knot * angle * 1.1;
		}
	}

	float ringPhase = axial * 2.3 + ringNoise + axialNoise + knotWarp * 1.4;
	float ringSignal = sin(ringPhase);
	float ringBands = 0.5 + 0.5 * ringSignal;
	ringBands = clamp(
		ringBands + (tableFbm2(float2(across * 0.55, axial * 0.09) + float2(7.0, 3.0)) - 0.5) * 0.28,
		0.0,
		1.0
	);

	float latewood = smoothstep(0.60, 0.98, ringBands);
	float colorBleed = smoothstep(0.18, 0.82, ringBands);
	float grainFine = tableNoise2(float2(across * 4.2, axial * 0.33) + float2(37.0, 15.0));
	float grainCoarse = tableFbm2(float2(across * 0.95, axial * 0.22) + float2(2.0, 9.0));
	float pores = smoothstep(0.80, 0.99, tableNoise2(float2(across * 2.7, axial * 2.9) + float2(23.0, 31.0)));

	float knotCore = smoothstep(0.52, 0.90, knotField);
	float knotBorder = smoothstep(0.22, 0.62, knotField) - knotCore;

	float3 sapwood = float3(0.72, 0.56, 0.38);
	float3 heartwood = float3(0.46, 0.30, 0.18);
	float3 woodColor = mix(sapwood, heartwood, colorBleed);
	woodColor -= latewood * float3(0.12, 0.09, 0.06);
	woodColor += (grainFine - 0.5) * float3(0.08, 0.06, 0.04);
	woodColor += (grainCoarse - 0.5) * float3(0.05, 0.03, 0.02);
	woodColor -= pores * float3(0.06, 0.04, 0.03);
	woodColor = mix(woodColor, woodColor * float3(0.56, 0.44, 0.33), knotCore);
	woodColor -= knotBorder * float3(0.10, 0.07, 0.05);

	color = woodColor;
	_surface.roughness = 0.94;
} else {
	// Neutral: texture-backed stripes. Host code configures diffuse.contentsTransform so
	// one source texture pixel maps to one screen point in neutral mode.
	color = _surface.diffuse.rgb;
	_surface.roughness = 0.95;
}

_surface.diffuse.rgb = clamp(color, 0.0, 1.0);
_surface.metalness = 0.0;
_surface.specular.rgb = float3(0.0);
