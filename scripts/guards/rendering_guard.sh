#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
cd "$repo_root"

fail=0

# 1) Shader source must not be embedded in Swift files.
# Guard on common SceneKit shader markers to catch multiline inline shader bodies.
swift_shader_hits=$(grep -R -n -E '#pragma body|scn_sample\(|simplexNoise3D\(' Dice --include='*.swift' || true)
if [ -n "$swift_shader_hits" ]; then
  echo "ERROR: Embedded shader source detected in Swift files. Move shader code to .metal files."
  echo "$swift_shader_hits"
  fail=1
fi

# 2) Per-pixel CPU loops are disallowed in production rendering modules.
render_files="Dice/DiceCubeView.swift Dice/D6SceneKitRenderConfig.swift Dice/DiceTextureProvider.swift Dice/DiceShaderBackgroundView.swift"
for file in $render_files; do
  [ -f "$file" ] || continue
  pixel_loop_hits=$(grep -n -E 'for y in 0\.\.<|for x in 0\.\.<|CGContext\(data:' "$file" || true)
  if [ -n "$pixel_loop_hits" ]; then
    echo "ERROR: CPU per-pixel rendering loop detected in $file"
    echo "$pixel_loop_hits"
    fail=1
  fi
done

if [ "$fail" -ne 0 ]; then
  exit 1
fi

echo "rendering_guard: PASS"
