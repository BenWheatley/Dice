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
